#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${DOCSIE_DEMO_ENV_FILE:-${REPO_ROOT}/.env}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}. Copy .env.example to .env and set DOCSIE_API_KEY." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

require_value() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required setting: ${name}" >&2
    exit 1
  fi
}

require_command() {
  local name="$1"
  if ! command -v "${name}" >/dev/null 2>&1; then
    echo "Missing required command: ${name}" >&2
    exit 1
  fi
}

require_value DOCSIE_BASE_URL
require_value DOCSIE_DEPLOYMENT_ID
require_value DOCSIE_DEPLOYMENT_TYPE
require_value DOCSIE_API_KEY

ARTIFACT_DIR="${DOCSIE_ARTIFACT_DIR:-${REPO_ROOT}/.artifacts}"
BUILD_ID_FILE="${ARTIFACT_DIR}/build-id"
PACKAGE_FILE="${AIRGAP_PACKAGE_FILE:-${ARTIFACT_DIR}/airgapped-build.zip}"
SITE_DIR="${ARTIFACT_DIR}/site"

mkdir -p "${ARTIFACT_DIR}"

docsie_api() {
  curl --fail-with-body --silent --show-error \
    -H "Authorization: Api-Key ${DOCSIE_API_KEY}" \
    -H "Content-Type: application/json" \
    "$@"
}

read_build_id() {
  if [[ ! -s "${BUILD_ID_FILE}" ]]; then
    echo "No build ID found. Run ./scripts/trigger-build.sh first." >&2
    exit 1
  fi
  tr -d '[:space:]' < "${BUILD_ID_FILE}"
}
