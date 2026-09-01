#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

if [[ -f "${SITE_DIR}/stop.sh" ]]; then
  DOCSIE_OFFLINE_PORT="${AIRGAP_PORT:-8091}" bash "${SITE_DIR}/stop.sh" || true
fi
rm -rf "${ARTIFACT_DIR}"

echo "Stopped the portable runtime and removed only ${ARTIFACT_DIR}."
