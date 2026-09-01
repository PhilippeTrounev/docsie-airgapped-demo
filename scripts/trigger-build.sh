#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command curl
require_command jq
require_value DOCSIE_BASE_URL
require_value DOCSIE_DEPLOYMENT_ID
require_value DOCSIE_DEPLOYMENT_TYPE

plugins_json="${DOCSIE_PLUGINS_JSON:-[]}"
if ! jq -e 'type == "array" and all(.[]; type == "string")' <<<"${plugins_json}" >/dev/null; then
  echo "DOCSIE_PLUGINS_JSON must be a JSON array of plugin names." >&2
  exit 1
fi

payload="$(jq -n \
  --arg deployment_id "${DOCSIE_DEPLOYMENT_ID}" \
  --arg deployment_type "${DOCSIE_DEPLOYMENT_TYPE}" \
  --argjson plugins "${plugins_json}" \
  '{
    deployment_id: $deployment_id,
    deployment_type: $deployment_type,
    include_docker: true,
    include_helm: true,
    plugins: $plugins
  }')"

response="$(docsie_api \
  -X POST \
  --data "${payload}" \
  "${DOCSIE_BASE_URL%/}/api_v2/003/airgapped_builds/")"

printf '%s\n' "${response}" | jq . > "${ARTIFACT_DIR}/build.json"
build_id="$(jq -er '.id' <<<"${response}")"
printf '%s\n' "${build_id}" > "${BUILD_ID_FILE}"

echo "Queued Docsie air-gapped build ${build_id} for ${DOCSIE_DEPLOYMENT_ID}."
