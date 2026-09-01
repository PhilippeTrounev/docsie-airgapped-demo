# Postman walkthrough

This collection demonstrates both production paths:

- reuse the newest completed Docsie Help build for a short recording; or
- create a fresh asynchronous build, poll it, and download it.

It then verifies the extracted package through localhost. The collection does
not create an API key or store one in the repository.

## 1. Import and configure

Import:

- `postman/Docsie Airgapped Demo.postman_collection.json`
- `postman/Docsie Airgapped Production.postman_environment.json`

Select **Docsie Airgapped Production**. Set only the local/current value of
`api_key`; leave its shared value empty. Close the environment editor before
recording.

| Variable | Purpose |
| --- | --- |
| `base_url` | Production External API host |
| `deployment_id` | Public Docsie Help portal to export |
| `api_key` | Secret organization API key; never shared |
| `build_id` | Captured from create or latest-build selection |
| `download_url` | One-hour signed URL; never show on camera |
| `local_url` | Extracted portal address |

## 2A. Short recording: select the newest completed build

Run **0. Select latest completed build**. The API returns builds newest first;
the test script selects the first `complete` build for `deployment_id` and saves
its ID.

Continue with **3. Get private download URL** and **4. Download ZIP**.

## 2B. Full recording: create a fresh build

Run these requests in order:

1. **Create fresh air-gapped build** queues the production Celery job and saves
   `build_id`.
2. **Poll build status** shows `pending`, `extracting`, `packaging`, then
   `complete` or `failed`. In the request builder, send it again until terminal.
   The Collection Runner loops every five seconds for at most 30 minutes.
3. **Get private download URL** requests a temporary signed URL.
4. **Download ZIP** uses no Docsie API header. In Postman Desktop choose
   **Send and Download**, saving it as `.artifacts/airgapped-build.zip`.

The API key is sent only to `https://app.docsie.io/api_v2/003/`. The signed
object-storage download deliberately uses `No Auth`.

## 3. Start the generated package

If Postman saved the ZIP to `.artifacts/airgapped-build.zip`, run:

```bash
./scripts/deploy-offline.sh
./scripts/verify-offline.sh
```

The repository extracts the ZIP and delegates to the generated `run.sh` and
`verify.sh`. No compatibility patch is applied to the production artifact.

## 4. Prove the offline result

Run the **Local offline proof** folder. These requests use `No Auth` and verify:

- the reader declares offline mode;
- the manifest matches the Docsie Help deployment;
- the package exposes API-shaped deployment JSON;
- the local search index contains documents.

Open <http://127.0.0.1:8091/>, search for `API key`, and open a result. Port 8091
keeps this recording separate from cached assets left by older port-8088 demos.

## 5. Explain the webhook

Open the **Webhook reference** folder and show the completion and failure
request bodies without pressing **Send**. They use the reserved `.invalid`
domain so they cannot reach a real receiver.

When an enabled Docsie webhook is subscribed to
`airgappedbuild.updated`, Docsie sends the event after either `complete` or
`failed`. The receiver checks `target.status`. Polling remains the authoritative
fallback and requires no separate webhook configuration.

See [`WEBHOOKS.md`](WEBHOOKS.md) before making security or delivery guarantees.

## Recording safety

- Hide Postman environment values before entering the key.
- Never display `.env`, `api_key`, or `download_url`.
- Do not commit `.artifacts/` or the downloaded ZIP.
- The demo contains the public Docsie Help portal, not customer-private content.
- Run `./scripts/cleanup.sh` when finished.
