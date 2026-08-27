#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command curl
require_command jq

build_id="$(read_build_id)"
interval="${AIRGAP_POLL_INTERVAL_SECONDS:-5}"
timeout="${AIRGAP_POLL_TIMEOUT_SECONDS:-1800}"
deadline=$((SECONDS + timeout))
last_status=""

while (( SECONDS < deadline )); do
  response="$(docsie_api "${DOCSIE_BASE_URL%/}/api_v2/003/airgapped_builds/${build_id}/")"
  printf '%s\n' "${response}" | jq . > "${ARTIFACT_DIR}/status.json"
  status="$(jq -er '.status' <<<"${response}")"

  if [[ "${status}" != "${last_status}" ]]; then
    echo "Build ${build_id}: ${status}"
    last_status="${status}"
  fi

  case "${status}" in
    complete)
      jq '{id, status, manifest, created, modified}' "${ARTIFACT_DIR}/status.json"
      exit 0
      ;;
    failed)
      jq '{id, status, error_message}' "${ARTIFACT_DIR}/status.json" >&2
      exit 1
      ;;
  esac

  sleep "${interval}"
done

echo "Timed out after ${timeout}s waiting for build ${build_id}." >&2
exit 1
