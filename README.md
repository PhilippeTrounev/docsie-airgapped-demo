# Docsie Help: production air-gapped deployment demo

This public repository demonstrates the supported production flow for exporting
[help.docsie.io](https://help.docsie.io/) as a self-contained on-premises or
air-gapped deployment.

The production API creates a private ZIP containing the documentation snapshot,
reader assets, API-shaped JSON, local search index, integrity checksums,
`README.md`, `AGENTS.md`, a portable Python runtime, Docker configuration, a Helm
chart, and opt-in update/rollback scripts.

No API key, login, signed URL, or network connection is required after the ZIP
has been downloaded and moved across the customer's secure transfer boundary.

## What the demo proves

1. An administrator creates an asynchronous production export through the
   Docsie External API.
2. The client can poll the job or receive `airgappedbuild.updated` when the job
   reaches `complete` or `failed`.
3. The client requests a one-hour private download URL and downloads the ZIP.
4. The generated package verifies its own checksums, deployment snapshot, and
   local search index before reporting that it is ready.
5. The same generated package can run through its portable runtime, Docker, or
   Helm without reaching Docsie during normal serving.

The public portal deployment used by the demo is
`deployment_EFk3AIigMh599HRk6`.

## Quick start

Prerequisites for the API demo: Bash, Python 3.9+, `curl`, `jq`, `unzip`, and a
Docsie organization API key belonging to a workspace owner or administrator.

```bash
cp .env.example .env
# Set DOCSIE_API_KEY only in .env. The file is git-ignored.
./scripts/demo.sh
```

The complete script runs create → poll → download → extract → start → verify.
When it finishes, open <http://127.0.0.1:8091/> and search for `API key`.

Generated state is written under the git-ignored `.artifacts/` directory. The
API key and short-lived signed download URL are never printed or committed.

## Use the newest existing production build

For a shorter recording, reuse the newest completed build for the Docsie Help
deployment instead of creating another one:

```bash
./scripts/latest-build.sh
./scripts/download-build.sh
./scripts/deploy-offline.sh
./scripts/verify-offline.sh
```

`latest-build.sh` uses the API's newest-first build list, filters it to the
configured deployment and `complete` status, and stores that build ID for the
download step.

## Individual API steps

```bash
./scripts/trigger-build.sh
./scripts/poll-build.sh
./scripts/download-build.sh
```

The production API choreography is:

```text
GET  /api_v2/003/airgapped_builds/?limit=100&offset=0
POST /api_v2/003/airgapped_builds/
GET  /api_v2/003/airgapped_builds/{build_id}/
GET  /api_v2/003/airgapped_builds/{build_id}/download/
```

Authentication uses `Authorization: Api-Key <token>`. Build status progresses
through `pending`, `extracting`, and `packaging`, then terminates as `complete`
or `failed`.

## Postman

Import both files from `postman/`:

- `Docsie Airgapped Demo.postman_collection.json`
- `Docsie Airgapped Production.postman_environment.json`

Set only the local/current value of the secret `api_key` variable. The
collection includes:

- selecting the newest completed build;
- creating a new build;
- polling through every real build status;
- obtaining and downloading the private ZIP;
- verifying the running portal, manifest, and local search index;
- documented completion and failure webhook payload examples.

See [`POSTMAN_WALKTHROUGH.md`](POSTMAN_WALKTHROUGH.md) for the recording sequence.

## Webhook notification

Yes—an enabled workspace- or organization-scoped webhook subscribed to
`airgappedbuild.updated` is called when an air-gapped build reaches either
`complete` or `failed`. Inspect `target.status` to distinguish the outcome. A
completed callback includes `target.detail_url` and a one-hour
`target.download_url`.

Webhook configuration currently uses the authenticated Docsie enterprise
webhook settings, not the External API key used by the collection. Polling
remains the self-contained Postman fallback. See [`WEBHOOKS.md`](WEBHOOKS.md)
for the exact payload and current delivery-security boundary.

## Run the downloaded package

The repository wrapper extracts the ZIP and delegates to the scripts generated
by Docsie:

```bash
./scripts/deploy-offline.sh
./scripts/verify-offline.sh
```

The equivalent recipient commands inside the extracted ZIP are:

```bash
bash run.sh
bash verify.sh
bash stop.sh
```

The repository uses port 8091 to avoid stale browser assets from older demo
runs that used 8088. The portable server binds to loopback by default. The
generated Dockerfile and `helm/` chart are also available inside
`.artifacts/site/` for the customer's approved on-premises runtime.

## Updating an installed package

When the update machine is temporarily allowed to reach Docsie, the recipient
can run:

```bash
bash update.sh
```

The generated updater opens Docsie OAuth with PKCE, requests a complete fresh
export, validates it, starts it, and only then switches the active release.
Normal `run.sh`, `verify.sh`, and `stop.sh` operation stays offline. For a
controlled Docker or Helm promotion use `bash update.sh --download-only`; use
`bash update.sh --rollback` to return to the prior portable release.

## Repository and artifact boundary

Safe to commit:

- scripts, Postman collection/environment template, walkthroughs, and examples;
- public deployment ID and non-secret configuration.

Never commit:

- `.env` or an API/OAuth token;
- `.artifacts/`, exported customer documentation, or private ZIPs;
- `download_url` values, because they are temporary signed URLs.

## Cleanup

```bash
./scripts/cleanup.sh
```

This stops the extracted portable runtime and removes only this repository's
`.artifacts/` directory. It does not revoke the API key or delete server-side
build records.
