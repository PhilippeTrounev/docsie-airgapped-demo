#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

container_name="${AIRGAP_CONTAINER_NAME:-docsie-help-offline}"
gateway_name="${AIRGAP_GATEWAY_CONTAINER_NAME:-docsie-help-offline-gateway}"
image_name="${AIRGAP_IMAGE_NAME:-docsie-help-offline:demo}"
network_name="${AIRGAP_NETWORK_NAME:-docsie-airgap-internal}"

docker rm -f "${gateway_name}" >/dev/null 2>&1 || true
docker rm -f "${container_name}" >/dev/null 2>&1 || true
docker image rm "${image_name}" >/dev/null 2>&1 || true
docker network rm "${network_name}" >/dev/null 2>&1 || true
rm -rf "${ARTIFACT_DIR}"

echo "Removed local Docsie airgap demo runtime and artifacts."
