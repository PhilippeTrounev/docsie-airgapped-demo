#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command curl
require_command docker
require_command jq

container_name="${AIRGAP_CONTAINER_NAME:-docsie-help-offline}"
gateway_name="${AIRGAP_GATEWAY_CONTAINER_NAME:-docsie-help-offline-gateway}"
network_name="${AIRGAP_NETWORK_NAME:-docsie-airgap-internal}"
port="${AIRGAP_PORT:-8088}"
base="http://127.0.0.1:${port}"

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

if [[ "$(docker network inspect "${network_name}" --format '{{.Internal}}')" != "true" ]]; then
  echo "Offline verification failed: ${network_name} is not internal." >&2
  exit 1
fi

if ! docker inspect "${container_name}" --format '{{json .NetworkSettings.Networks}}' | grep -q "${network_name}"; then
  echo "Offline verification failed: workload is not attached to ${network_name}." >&2
  exit 1
fi

if docker exec "${container_name}" timeout 5 wget -q -O /tmp/docsie-egress-check https://app.docsie.io >/dev/null 2>&1; then
  echo "Offline verification failed: container reached app.docsie.io." >&2
  exit 1
fi

echo "Offline verification passed."
jq '{deployment_id, deployment_type, api_version, counts}' <<<"${manifest}"
jq '{search_documents: (.documents | length), languages: .meta.languages, versions: .meta.versions}' <<<"${search}"
echo "Container outbound request was blocked as expected."
echo "Local ingress is served by ${gateway_name}; the Docsie workload remains internal-only."
