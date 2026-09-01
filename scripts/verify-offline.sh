#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command curl
require_command jq

port="${AIRGAP_PORT:-8091}"
base="http://127.0.0.1:${port}"

if [[ ! -f "${SITE_DIR}/verify.sh" ]]; then
  echo "Missing ${SITE_DIR}/verify.sh. Run ./scripts/deploy-offline.sh first." >&2
  exit 1
fi

DOCSIE_OFFLINE_PORT="${port}" bash "${SITE_DIR}/verify.sh"

for _ in {1..30}; do
  if curl --fail --silent --output /dev/null "${base}/"; then
    break
  fi
  sleep 1
done

curl --fail --silent "${base}/" | grep -q 'window.__DOCSIE_OFFLINE__ = true'
manifest="$(curl --fail --silent "${base}/manifest.json")"
deployment="$(curl --fail --silent "${base}/api_v2/006/deployment/${DOCSIE_DEPLOYMENT_ID}/")"
search="$(curl --fail --silent "${base}/search/index.json")"

jq -e --arg id "${DOCSIE_DEPLOYMENT_ID}" '.deployment_id == $id and .deployment_type == "portal"' <<<"${manifest}" >/dev/null
jq -e 'type == "object"' <<<"${deployment}" >/dev/null
jq -e '.documents | type == "array"' <<<"${search}" >/dev/null

echo "Offline verification passed."
jq '{deployment_id, deployment_type, api_version, counts}' <<<"${manifest}"
jq '{search_documents: (.documents | length), languages: .meta.languages, versions: .meta.versions}' <<<"${search}"
echo "The packaged server is loopback-bound and serves only files from the extracted ZIP."
