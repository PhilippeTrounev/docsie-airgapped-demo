#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command docker
require_command unzip

if [[ ! -s "${PACKAGE_FILE}" ]]; then
  echo "Missing ${PACKAGE_FILE}. Run ./scripts/download-build.sh first." >&2
  exit 1
fi

rm -rf "${SITE_DIR}"
mkdir -p "${SITE_DIR}"
unzip -q "${PACKAGE_FILE}" -d "${SITE_DIR}"
"${SCRIPT_DIR}/prepare-package.sh" "${SITE_DIR}"

for required in Dockerfile index.html manifest.json server.conf; do
  if [[ ! -f "${SITE_DIR}/${required}" ]]; then
    echo "Package is missing required file: ${required}" >&2
    exit 1
  fi
done

container_name="${AIRGAP_CONTAINER_NAME:-docsie-help-offline}"
gateway_name="${AIRGAP_GATEWAY_CONTAINER_NAME:-docsie-help-offline-gateway}"
image_name="${AIRGAP_IMAGE_NAME:-docsie-help-offline:demo}"
network_name="${AIRGAP_NETWORK_NAME:-docsie-airgap-internal}"
port="${AIRGAP_PORT:-8088}"

if docker container inspect "${gateway_name}" >/dev/null 2>&1; then
  docker rm -f "${gateway_name}" >/dev/null
fi

if docker container inspect "${container_name}" >/dev/null 2>&1; then
  docker rm -f "${container_name}" >/dev/null
fi

if ! docker network inspect "${network_name}" >/dev/null 2>&1; then
  docker network create --internal "${network_name}" >/dev/null
fi

docker build --tag "${image_name}" "${SITE_DIR}"
docker run --detach \
  --name "${container_name}" \
  --network "${network_name}" \
  --network-alias docsie-airgap-workload \
  --read-only \
  --tmpfs /var/cache/nginx \
  --tmpfs /var/run \
  "${image_name}" >/dev/null

docker create \
  --name "${gateway_name}" \
  --network "${network_name}" \
  --publish "127.0.0.1:${port}:80" \
  --read-only \
  --tmpfs /var/cache/nginx \
  --tmpfs /var/run \
  --mount "type=bind,source=${REPO_ROOT}/gateway.conf,target=/etc/nginx/conf.d/default.conf,readonly" \
  nginx:alpine >/dev/null
docker network connect bridge "${gateway_name}"
docker start "${gateway_name}" >/dev/null

echo "Started internal workload ${container_name} behind ${gateway_name} at http://127.0.0.1:${port}/."
