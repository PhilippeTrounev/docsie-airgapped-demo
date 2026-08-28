# Docsie help portal: air-gapped deployment demo

This repository demonstrates the full supported flow for turning
[help.docsie.io](https://help.docsie.io/) into a self-contained Docsie deployment:

1. Authenticate to the Docsie External API with an organization-scoped API key.
2. Queue an asynchronous air-gapped build on Docsie staging.
3. Poll the Celery-backed job until it completes.
4. Download and inspect the private ZIP artifact.
5. Apply narrowly scoped compatibility fixes for older staging artifacts.
6. Build and start the included nginx container on an internal-only Docker network.
7. Verify the reader, local search UI/index, and blocked outbound access.

The public portal embeds deployment ID `deployment_EFk3AIigMh599HRk6`. The staging database
contains the same deployment ID in the `docsie` organization, so the demo exercises the
real portal export path without creating a production build.

## Quick start

Prerequisites: Bash, Python 3, `curl`, `jq`, `unzip`, and Docker.

```bash
cp .env.example .env
# Put the dedicated staging token in DOCSIE_API_KEY. Never commit .env.
./scripts/demo.sh
```

When the script finishes, open <http://127.0.0.1:8088/>. The Docsie container is attached only
to a Docker `--internal` network and has no route to the public internet. A separate fixed nginx
gateway joins that private network and publishes the localhost ingress port, mirroring an
on-prem ingress controller without granting egress to the documentation workload.

Generated state is written under `.artifacts/` and is intentionally git-ignored:

- `build.json`: initial API response
- `status.json`: latest polled build state and manifest
- `download.json`: short-lived presigned download response
- `airgapped-build.zip`: private exported package
- `site/`: extracted nginx/Docker/Helm package

## Individual steps

```bash
./scripts/trigger-build.sh
./scripts/poll-build.sh
./scripts/download-build.sh
./scripts/deploy-offline.sh
./scripts/verify-offline.sh
```

The API flow is:

```text
POST /api_v2/003/airgapped_builds/
GET  /api_v2/003/airgapped_builds/{build_id}/
GET  /api_v2/003/airgapped_builds/{build_id}/download/
```

Authentication uses `Authorization: Api-Key <token>`. Scripts never print the token.

The staging image used on August 27, 2026 writes the reader options to the legacy
`window.Docsie.config` property, which reader 3.0.0 does not consume during bootstrap.
`prepare-package.sh` detects only that legacy form and rewrites it to the supported
`window.Docsie.override.config` shape. Once the corresponding server packager fix is deployed,
the compatibility step becomes a no-op.

The same staging artifact contains a headless offline search engine but does not mount the
reader's search control. The demo vendors `assets/docsie-search.js`, a modular reader plugin
registered at `nav-plugin-bar`, when that UI marker is absent. It provides a visible search
launcher, an accessible results dialog, `Ctrl/Cmd+K`, and Docsie-native result navigation while
continuing to read only `/search/index.json`. If an encapsulated reader theme does not give the
sidebar launcher a visible box, the plugin still exposes the same control at the top-right of
the portal. The top-right control is always mounted so it remains discoverable across
encapsulated reader themes. This compatibility replacement also becomes a no-op after the
updated server plugin is deployed. The package nginx configuration revalidates this generated
plugin instead of treating it as a permanently immutable reader asset, so a later package
upgrade cannot leave visitors running a stale search bundle. The compatibility stage also
derives a cache token from the search bundle, applies it to the reader script URL, and replaces
the reader's internal plugin-loader token so an existing browser must load the upgraded code.

## Postman

Import both files from `postman/`:

- `Docsie Airgapped Demo.postman_collection.json`
- `Docsie Airgapped Staging.postman_environment.json`

Set the environment's secret `api_key` value locally. The create request captures `build_id`;
the status and download requests reuse it. Postman shows the API choreography, while the shell
scripts handle binary download, Docker startup, and offline verification.

## What “air-gapped” means in this demo

The Docsie build worker needs network access while preparing the artifact so it can snapshot
content, vendor reader assets, and upload the private ZIP. The resulting runtime does not.
For a physically disconnected customer environment, transfer the ZIP and an approved nginx
base image through the customer's secure media process, then build or import the image inside
that environment. The included Helm chart can deploy the resulting image to an on-prem cluster.

Online-only plugins such as feedback, recorder, AI agents, and secure-file URL signing are not
included. Search is implemented by the packaged client-side plugin and index.

## Cleanup

```bash
./scripts/cleanup.sh
```

This removes only the demo containers, image, internal Docker network, and `.artifacts/` contents.
It does not revoke the Docsie API key or delete the server-side build record.
