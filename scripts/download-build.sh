#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command curl
require_command jq

build_id="$(read_build_id)"
response="$(docsie_api "${DOCSIE_BASE_URL%/}/api_v2/003/airgapped_builds/${build_id}/download/")"
printf '%s\n' "${response}" | jq . > "${ARTIFACT_DIR}/download.json"
download_url="$(jq -er '.download_url' <<<"${response}")"

curl --fail --location --silent --show-error \
  --output "${PACKAGE_FILE}" \
  "${download_url}"

echo "Downloaded $(du -h "${PACKAGE_FILE}" | awk '{print $1}') package to ${PACKAGE_FILE}."
