# Recording walkthrough: production Docsie air-gapped export

Target length: 6–8 minutes.

## Before recording

1. Import the Postman collection and production environment.
2. Set `api_key` as a local/current secret value, then close the editor.
3. Keep Postman, this README, a terminal, and the browser ready.
4. Keep `.env`, signed URLs, and `.artifacts/` out of the captured frame.
5. Decide whether to create a fresh build or reuse the latest completed one.

## Suggested video

### 0:00 — Show the finished offline portal

Open <http://127.0.0.1:8091/>, search for `API key`, and open an article.
Explain that the reader, navigation, images, API snapshots, and search index are
being served from the downloaded ZIP.

### 0:45 — Explain the transfer boundary

Show this repository's README. Docsie needs connectivity while generating and
downloading the snapshot. The ZIP crosses the customer's approved transfer
boundary. Its normal runtime needs no Docsie connection.

### 1:30 — Obtain the latest build in Postman

For the short path, run **0. Select latest completed build**, then **3. Get
private download URL** and **4. Download ZIP**.

For the full path, run **1. Create fresh air-gapped build**, then repeatedly run
**2. Poll build status** until it is complete. Continue with requests 3 and 4.

Point out that the create call returns immediately, and the durable build record
can be recovered later through the build-list endpoint.

### 3:00 — Explain webhook notification

Show the **Webhook reference** examples. A configured
`airgappedbuild.updated` webhook fires only at `complete` or `failed`; the
receiver checks `target.status`. Polling is still available when the customer
does not expose an inbound webhook endpoint.

Do not claim that this model event is signed or retried. See `WEBHOOKS.md`.

### 3:45 — Run the exact Docsie-generated package

```bash
./scripts/deploy-offline.sh
./scripts/verify-offline.sh
```

Show that verification checks the package checksums, reader, deployment API
snapshot, and local search index. Mention the generated Dockerfile and Helm
chart, but do not claim they were deployed unless you actually run them.

### 5:00 — Local proof

Run **Local offline proof** in Postman. Return to the browser, search for a
second phrase, and navigate to another result.

### 6:00 — Update story

Open the generated package README and show:

```bash
bash update.sh
bash update.sh --download-only
bash update.sh --rollback
```

Explain that an update is a complete replacement export authorized through
Docsie OAuth. Normal serving remains offline, and no update runs automatically.

### 7:00 — Close

Show the public GitHub repository. The repository contains only reusable
scripts, Postman configuration, and documentation. API keys, signed URLs,
customer documentation, and generated ZIPs stay outside Git.

## Claims supported by the current production proof

- The current Docsie Help deployment can be exported from production.
- The generated ZIP runs without compatibility rewriting.
- The packaged verifier checks 2,136 files for the observed production build.
- The observed build exposed 1,081 local search documents and zero failed assets.
- Browser search and article navigation work against the local package.

Those counts describe the verified build and may change as the public
documentation changes. Docker/Helm deployment and a live OAuth update are not
part of that specific proof unless recorded separately.
