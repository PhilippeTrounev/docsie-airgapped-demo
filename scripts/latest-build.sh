#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command curl
require_command jq
require_value DOCSIE_BASE_URL
require_value DOCSIE_DEPLOYMENT_ID

response="$(docsie_api "${DOCSIE_BASE_URL%/}/api_v2/003/airgapped_builds/?limit=100&offset=0")"
printf '%s\n' "${response}" | jq . > "${ARTIFACT_DIR}/builds.json"

latest="$(jq -cr --arg deployment_id "${DOCSIE_DEPLOYMENT_ID}" '
  (.results // [])
  | map(select(.deployment_id == $deployment_id and .status == "complete"))
  | first
' <<<"${response}")"

if [[ "${latest}" == "null" ]]; then
  echo "No completed build found for ${DOCSIE_DEPLOYMENT_ID}." >&2
  exit 1
fi

build_id="$(jq -er '.id' <<<"${latest}")"
printf '%s\n' "${build_id}" > "${BUILD_ID_FILE}"
printf '%s\n' "${latest}" | jq . > "${ARTIFACT_DIR}/status.json"

echo "Selected latest completed build ${build_id} for ${DOCSIE_DEPLOYMENT_ID}."
jq '{id, status, created, modified, deployment_id, deployment_type, manifest}' <<<"${latest}"
