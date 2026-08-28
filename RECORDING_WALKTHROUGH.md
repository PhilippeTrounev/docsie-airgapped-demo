# Recording walkthrough: Docsie air-gapped portal demo

Target length: 6-8 minutes.

## Before recording

1. Import the Postman collection and environment.
2. Set the secret API key as a Postman current value, then close the environment editor.
3. Ensure Docker is running and port 8088 is free.
4. Keep the repository, Postman, terminal, and browser ready in separate windows.
5. Do not open `.env`, Postman secret values, `download.json`, or a signed download URL on camera.

## Suggested video flow

### 0:00 - Show the outcome

Open <http://127.0.0.1:8088/>, search for `api key`, and open a result. Explain
that the portal, article data, assets, and search index are served locally.

### 0:45 - Explain the boundary

Show the repository README. The Docsie build service needs connectivity while it
creates the snapshot. The resulting ZIP is what crosses the customer's secure
transfer boundary; its runtime needs no internet connection.

### 1:30 - Create the export in Postman

Run requests 1-3 in **Cloud build API**. Point out the asynchronous build ID,
status polling, and short-lived download URL. Use **Send and Download** for request 4.

### 3:00 - Deploy locally

```bash
./scripts/deploy-offline.sh
./scripts/verify-offline.sh
```

Call out the internal-only Docker workload, separate localhost gateway, local
manifest/search checks, and blocked outbound request.

### 4:15 - Show local proof

Run the **Local offline proof** Postman folder. Then return to the browser and
show search, result count, and article navigation.

### 5:15 - Show the customer handoff

```bash
./scripts/create-share-package.sh Eclypsium
```

The generated artifact is an Eclypsium-labeled synthetic demo package. It
contains the public Docsie help portal, deployment files, Postman examples, a
manifest, and recording notes. It contains no API key or signed URL.

Show the active Docsie File Share and download the shared ZIP once to demonstrate
that the recipient path works.

### 6:15 - Close

Show the GitHub repository structure and explain that production use replaces
the demo deployment ID, transfers the ZIP and approved base image through the
customer's secure media process, and deploys Docker or Helm inside the air gap.

## Claims supported by this demo

- The selected public portal can be exported through the Docsie API.
- The package contains reader assets, API-shaped content, Docker/nginx, Helm,
  and a local search index.
- The provided runtime serves the portal with the documentation workload on an
  internal Docker network and blocks its outbound request.
- Search and navigation work from the packaged index and content.

Do not claim that this synthetic artifact contains Eclypsium production data or
that every online-only Docsie integration works without connectivity.
