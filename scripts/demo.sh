#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${SCRIPT_DIR}/trigger-build.sh"
"${SCRIPT_DIR}/poll-build.sh"
"${SCRIPT_DIR}/download-build.sh"
"${SCRIPT_DIR}/deploy-offline.sh"
"${SCRIPT_DIR}/verify-offline.sh"
