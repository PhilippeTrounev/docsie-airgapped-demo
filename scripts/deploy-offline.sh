#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command unzip

if [[ ! -s "${PACKAGE_FILE}" ]]; then
  echo "Missing ${PACKAGE_FILE}. Run ./scripts/download-build.sh first." >&2
  exit 1
fi

rm -rf "${SITE_DIR}"
mkdir -p "${SITE_DIR}"
unzip -q "${PACKAGE_FILE}" -d "${SITE_DIR}"

for required in README.md AGENTS.md index.html manifest.json run.sh verify.sh stop.sh update.sh; do
  if [[ ! -f "${SITE_DIR}/${required}" ]]; then
    echo "Package is missing required file: ${required}" >&2
    exit 1
  fi
done

port="${AIRGAP_PORT:-8091}"

DOCSIE_OFFLINE_PORT="${port}" bash "${SITE_DIR}/run.sh"
echo "Started the Docsie-generated portable runtime at http://127.0.0.1:${port}/."
echo "The generated Dockerfile and helm/ chart remain available under ${SITE_DIR}."
