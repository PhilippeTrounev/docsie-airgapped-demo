#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command curl
require_command jq
require_command unzip
require_value DOCSIE_BASE_URL

build_id="$(read_build_id)"
response="$(docsie_api "${DOCSIE_BASE_URL%/}/api_v2/003/airgapped_builds/${build_id}/download/")"
download_url="$(jq -er '.download_url' <<<"${response}")"

curl --fail --location --silent --show-error \
  --output "${PACKAGE_FILE}" \
  "${download_url}"

unzip -tq "${PACKAGE_FILE}" >/dev/null
if command -v shasum >/dev/null 2>&1; then
  (
    cd "$(dirname "${PACKAGE_FILE}")"
    env -u LC_ALL -u LC_CTYPE LANG=C shasum -a 256 "$(basename "${PACKAGE_FILE}")" \
      > "$(basename "${PACKAGE_FILE}").sha256"
  )
elif command -v sha256sum >/dev/null 2>&1; then
  (
    cd "$(dirname "${PACKAGE_FILE}")"
    sha256sum "$(basename "${PACKAGE_FILE}")" > "$(basename "${PACKAGE_FILE}").sha256"
  )
else
  echo "Missing SHA-256 utility: install shasum or sha256sum." >&2
  exit 1
fi

echo "Downloaded $(du -h "${PACKAGE_FILE}" | awk '{print $1}') package to ${PACKAGE_FILE}."
echo "ZIP integrity test passed; SHA-256 written to ${PACKAGE_FILE}.sha256."
