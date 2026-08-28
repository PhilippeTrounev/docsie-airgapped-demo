# Postman walkthrough

This collection shows the API choreography for exporting a Docsie portal and
then proves that the result is served locally. It does not upload documentation,
create an API key, or send the key anywhere except the selected Docsie API host.

## 1. Import and configure

Import both files from `postman/` into Postman:

- `Docsie Airgapped Demo.postman_collection.json`
- `Docsie Airgapped Staging.postman_environment.json`

Select the **Docsie Airgapped Staging** environment. Open its variables and set
only the **Current value** of `api_key`. Keep the shared/initial value empty and
do not show the key while recording.

The remaining preconfigured values are:

| Variable | Purpose |
| --- | --- |
| `base_url` | Docsie API host used to create the export |
| `deployment_id` | Public help portal deployment to snapshot |
| `build_id` | Captured automatically by request 1 |
| `download_url` | Short-lived URL captured by request 3 |
| `local_url` | Isolated portal address after local deployment |

## 2. Build the export

Open **Cloud build API** and run the requests in order.

1. **Create air-gapped build** sends the deployment ID, requests Docker and Helm
   assets, and records the returned `build_id`.
2. **Poll build status** shows the Celery-backed job moving through `pending` or
   `processing` to `complete`. In the request builder, click **Send** again until
   complete. The folder's Collection Runner loops every five seconds for up to
   30 minutes.
3. **Get private download URL** obtains a short-lived URL and saves it as a
   secret environment value.
4. **Download ZIP** uses no API-key header. In Postman desktop, use
   **Send and Download** and save it as `.artifacts/airgapped-build.zip`.

The split download step is deliberate: the stable API endpoint is authenticated,
while the returned object-storage URL is temporary and should not be committed.

## 3. Deploy inside the isolated runtime

From the repository root:

```bash
./scripts/deploy-offline.sh
./scripts/verify-offline.sh
```

The workload container joins only an internal Docker network. A separate nginx
gateway publishes `127.0.0.1:8088` and acts like an on-prem ingress controller.
The verification script checks the manifest, API-shaped content, local search
index, Docker network isolation, and a blocked request to `app.docsie.io`.

## 4. Verify with Postman and the browser

Run the **Local offline proof** folder. Its requests have `No Auth`, so the
Docsie API key never goes to localhost. The tests verify:

- the page declares offline mode;
- the manifest matches the requested deployment;
- the local search index contains documents.

Open <http://127.0.0.1:8088/> and search for `api key`. The result list and
article navigation are backed only by `/search/index.json` and packaged content.

## 5. Recording safety

- Hide the Postman environment values before entering the API key.
- Never copy the `download_url` into the video; it is a temporary signed URL.
- Use the generated Eclypsium demo package only as a synthetic customer handoff.
  It contains the public Docsie help portal, not private Eclypsium documentation.
- Run `./scripts/cleanup.sh` when the demo is finished.
