#!/usr/bin/env bash
set -euo pipefail

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
  exit 0
fi

if ! grep -q 'window.Docsie.config = {' "${index_path}"; then
  echo "Unrecognized reader bootstrap contract in ${index_path}." >&2
  exit 1
fi

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
