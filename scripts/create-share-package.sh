#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_command jq
require_command shasum
require_command unzip
require_command zip

customer_label="${1:-Eclypsium}"
safe_label="$(printf '%s' "${customer_label}" | tr -cs '[:alnum:]._-\n' '-' | sed 's/^-//; s/-$//')"
if [[ -z "${safe_label}" ]]; then
  echo "Customer label must contain at least one letter or number." >&2
  exit 1
fi

if [[ ! -s "${PACKAGE_FILE}" ]]; then
  echo "Missing ${PACKAGE_FILE}. Run the Postman download step or ./scripts/download-build.sh first." >&2
  exit 1
fi

share_dir="${ARTIFACT_DIR}/share"
output_zip="${share_dir}/${safe_label}-Docsie-Airgapped-Demo.zip"
output_checksum="${output_zip}.sha256"
staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/docsie-airgap-share.XXXXXX")"
trap 'rm -rf "${staging_dir}"' EXIT

unzip -q "${PACKAGE_FILE}" -d "${staging_dir}"
"${SCRIPT_DIR}/prepare-package.sh" "${staging_dir}"

cp "${REPO_ROOT}/POSTMAN_WALKTHROUGH.md" "${staging_dir}/POSTMAN_WALKTHROUGH.md"
cp "${REPO_ROOT}/RECORDING_WALKTHROUGH.md" "${staging_dir}/RECORDING_WALKTHROUGH.md"
mkdir -p "${staging_dir}/postman"
cp "${REPO_ROOT}/postman/Docsie Airgapped Demo.postman_collection.json" "${staging_dir}/postman/"
cp "${REPO_ROOT}/postman/Docsie Airgapped Staging.postman_environment.json" "${staging_dir}/postman/"

generated_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
jq -n \
  --arg customer "${customer_label}" \
  --arg generated_at "${generated_at}" \
  --arg deployment_id "${DOCSIE_DEPLOYMENT_ID}" \
  '{
    package: "Docsie air-gapped portal demo",
    customer_demo_label: $customer,
    generated_at: $generated_at,
    source_deployment_id: $deployment_id,
    content_boundary: "Synthetic customer demo containing the public Docsie help portal; no customer-private documentation",
    secret_boundary: "No API key or signed download URL is included",
    entrypoint: "index.html",
    deployment_options: ["Docker", "Helm"]
  }' > "${staging_dir}/CUSTOMER_DEMO_MANIFEST.json"

mkdir -p "${share_dir}"
rm -f "${output_zip}" "${output_checksum}"
(
  cd "${staging_dir}"
  zip -qr "${output_zip}" .
)
(
  cd "${share_dir}"
  LC_ALL=C LANG=C shasum -a 256 "$(basename "${output_zip}")" > "$(basename "${output_checksum}")"
)

echo "Created synthetic customer share package: ${output_zip}"
echo "Checksum: ${output_checksum}"
