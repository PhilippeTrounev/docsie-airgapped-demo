# Air-gapped build webhook

Docsie emits a terminal build notification to enabled webhooks subscribed to
`airgappedbuild.updated` (or `*`). The webhook may be scoped to the deployment's
workspace or its organization.

The event is emitted only when the build is saved with `status` equal to
`complete` or `failed`; intermediate `pending`, `extracting`, and `packaging`
updates are not sent.

## Configure

Configure the webhook in the authenticated Docsie enterprise webhook settings:

- target: a public HTTPS endpoint controlled by the customer;
- event: `airgappedbuild.updated`;
- enabled: true;
- scope: the deployment workspace, or the whole organization.

Webhook management is session-authenticated and is separate from the
organization API key used by the air-gapped build collection. The Postman demo
therefore uses polling as its portable fallback.

## Completed payload

The payload includes other serializer fields and the full manifest. The fields
most useful to an automation receiver are shown here:

```json
{
  "message": "<human-readable Docsie notification>",
  "url": "https://app.docsie.io/api/v1/airgapped/build/airgap_example/",
  "action": "airgappedbuild.updated",
  "target": {
    "id": "airgap_example",
    "deployment_id": "deployment_EFk3AIigMh599HRk6",
    "deployment_type": "portal",
    "status": "complete",
    "include_docker": true,
    "include_helm": true,
    "plugins": ["search"],
    "manifest": {},
    "error_message": "",
    "download_url": "https://temporary-signed-download.example/...",
    "detail_url": "https://app.docsie.io/api_v2/003/airgapped_builds/airgap_example/",
    "action": "airgappedbuild.updated"
  }
}
```

Treat `target.download_url` as a secret: it is a temporary one-hour signed URL.
An integration can instead authenticate to `target.detail_url` and then call
the stable `/download/` action when it is ready to transfer the package.

## Failed payload

Failure uses the same event name. Inspect `target.status` and
`target.error_message`:

```json
{
  "action": "airgappedbuild.updated",
  "target": {
    "id": "airgap_example",
    "deployment_id": "deployment_EFk3AIigMh599HRk6",
    "status": "failed",
    "error_message": "Build error summary",
    "download_url": null,
    "detail_url": "https://app.docsie.io/api_v2/003/airgapped_builds/airgap_example/",
    "action": "airgappedbuild.updated"
  }
}
```

## Current delivery-security boundary

The current `airgappedbuild.updated` model-event path sends JSON with
`Content-Type: application/json`. It does **not** use the newer signed named-event
delivery task, so it does not currently include `X-Docsie-Signature` or automatic
delivery retries. Protect the receiver with an unguessable callback URL or an
allowlisted ingress, and re-fetch the build through the authenticated External
API before acting on the callback.

For the recording, describe the webhook as a notification and polling as the
authoritative fallback. Do not claim signed or guaranteed delivery for this
event until the model-event delivery path is moved to the signed asynchronous
dispatcher.
