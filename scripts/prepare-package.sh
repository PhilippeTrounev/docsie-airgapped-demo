#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

site_dir="${1:-}"
if [[ -z "${site_dir}" || ! -d "${site_dir}" ]]; then
  echo "Usage: $0 <extracted-site-directory>" >&2
  exit 1
fi

index_path="${site_dir}/index.html"
if [[ ! -f "${index_path}" ]]; then
  echo "Package is missing ${index_path}." >&2
  exit 1
fi

if grep -q 'window.Docsie.override' "${index_path}"; then
  echo "Reader bootstrap already uses Docsie.override; no compatibility change needed."
elif ! grep -q 'window.Docsie.config = {' "${index_path}"; then
  echo "Unrecognized reader bootstrap contract in ${index_path}." >&2
  exit 1
else
  python3 - "${index_path}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
start_marker = "      window.Docsie.config = {\n"
end_marker = "\n      };"
start = text.index(start_marker)
body_start = start + len(start_marker)
end = text.index(end_marker, body_start)
body = text[body_start:end]
indented_body = "\n".join(f"  {line}" for line in body.splitlines())
replacement = (
    "      window.Docsie.override = {\n"
    "        config: {\n"
    f"{indented_body}\n"
    "        },\n"
    "      };"
)
path.write_text(text[:start] + replacement + text[end + len(end_marker):])
PY

  grep -q 'window.Docsie.override' "${index_path}"
  if grep -q 'window.Docsie.config = {' "${index_path}"; then
    echo "Legacy bootstrap remained after compatibility rewrite." >&2
    exit 1
  fi

  echo "Applied staging reader-bootstrap compatibility fix."
fi

plugin_path="${site_dir}/lib/plugins/search/dist/docsie-search.js"
bundled_plugin="${SCRIPT_DIR}/../assets/docsie-search.js"

if [[ ! -f "${plugin_path}" ]]; then
  echo "Package is missing the offline search plugin at ${plugin_path}." >&2
  exit 1
fi

if grep -q 'docsie-offline-search-plugin-container' "${plugin_path}"; then
  echo "Offline search plugin already includes the reader UI; no compatibility change needed."
elif [[ ! -f "${bundled_plugin}" ]]; then
  echo "Missing bundled offline search UI plugin at ${bundled_plugin}." >&2
  exit 1
else
  install -m 0644 "${bundled_plugin}" "${plugin_path}"
  grep -q 'docsie-offline-search-plugin-container' "${plugin_path}"
  echo "Installed the modular offline search UI plugin."
fi

python3 - "${index_path}" "${site_dir}/lib/service.js" "${plugin_path}" <<'PY'
from hashlib import sha256
from pathlib import Path
import re
import sys

index_path = Path(sys.argv[1])
service_path = Path(sys.argv[2])
plugin_path = Path(sys.argv[3])

if not service_path.is_file():
    raise SystemExit(f"Package is missing reader service bundle: {service_path}")

cache_token = sha256(
    plugin_path.read_bytes() + b"\0docsie-airgap-reader-cache-v2"
).hexdigest()[:40]

service_text = service_path.read_text()
service_text, service_base_count = re.subn(
    r'([A-Za-z_$][A-Za-z0-9_$]*)\.src\.replace\("/service\.js",""\)',
    r'\1.src.replace("/service.js","").split("?")[0]',
    service_text,
)
if service_base_count == 0:
    raise SystemExit("Could not make the reader asset base ignore the cache query.")
service_text, reader_token_count = re.subn(
    r'(?<=concat\(")[0-9a-f]{40}(?="\))',
    cache_token,
    service_text,
)
if reader_token_count == 0:
    raise SystemExit("Could not cache-bust the reader plugin loader token.")
service_path.write_text(service_text)

index_text = index_path.read_text()
index_text, service_src_count = re.subn(
    r'src="/lib/service\.js(?:\?q=[^"]*)?"',
    f'src="/lib/service.js?q={cache_token}"',
    index_text,
)
if service_src_count != 1:
    raise SystemExit("Could not cache-bust the reader service script URL.")
index_path.write_text(index_text)

print(f"Reader and search plugin cache token: {cache_token[:12]}")
PY

python3 - "${site_dir}/server.conf" "${site_dir}/nginx.conf" <<'PY'
from pathlib import Path
import sys

marker = "location = /lib/plugins/search/dist/docsie-search.js"
needle = "    location /lib/ {"
replacement = (
    "    # Revalidate the generated offline search bundle between package upgrades.\n"
    "    location = /lib/plugins/search/dist/docsie-search.js {\n"
    "        add_header Cache-Control \"no-cache\";\n"
    "    }\n\n"
    f"{needle}"
)

for raw_path in sys.argv[1:]:
    path = Path(raw_path)
    if not path.is_file():
        raise SystemExit(f"Package is missing nginx configuration: {path}")
    text = path.read_text()
    if marker in text:
        continue
    if needle not in text:
        raise SystemExit(f"Unrecognized nginx cache configuration in {path}")
    path.write_text(text.replace(needle, replacement, 1))
PY

echo "Offline search bundle is configured for browser cache revalidation."
