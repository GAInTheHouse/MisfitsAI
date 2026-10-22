# MisfitAI operations runbook

For the full Google Cloud guide (architecture, authentication, environment variables, workflows, costs, limitations and onboarding), see [`docs/google-cloud-setup.md`](google-cloud-setup.md). This runbook keeps only the operational summary.

## Google Cloud: what exists today (development only)

These are **development resources**. They were checked on 2026-10-22 and used for the Phase 2 local integration checks. They are **not** verified production resources.

| Resource | Value |
|---|---|
| Project | `misfitai-512403` |
| Vertex AI region | `us-central1` |
| Development bucket | `misfitai-dev-images-2026`: region **`us-east1`**, uniform access, public access prevention enforced, 7-day soft delete |
| Storage signing service account | `misfitai-dev-storage@misfitai-512403.iam.gserviceaccount.com`: no user-managed keys; `roles/storage.objectViewer` on the development bucket only |
| Enabled APIs (relevant) | Vertex AI (`aiplatform`), Cloud Storage, IAM Credentials (`iamcredentials`, for keyless signing) |

Developers authenticate locally with Application Default Credentials (`gcloud auth application-default login`). Permissions and setup steps are in the guide, section C.

**Production does not exist yet.** There is no production bucket, no production runtime identity, and no credentials on Heroku, and the production storage authentication approach is undecided. See the guide, section G.

## Original Phase 1 plan (not provisioned)

The Phase 1 runbook planned the following. **None of these resources exist**; treat this as a plan, not a record:

- a service account `misfit-heroku` with `aiplatform.user`, `discoveryengine.user` and bucket-scoped `storage.objectAdmin`, with its JSON key in Heroku's `GOOGLE_SERVICE_ACCOUNT_JSON`. **This account does not exist**; the only service account is `misfitai-dev-storage`;
- a private GCS bucket in `us-central1`. **No such bucket exists**; the only bucket is `misfitai-dev-images-2026` in `us-east1`;
- enabling the Vertex AI, Discovery Engine, Calendar, Analytics Data and Cloud Storage APIs. Vertex AI and Cloud Storage are enabled; **Discovery Engine, Calendar and Analytics Data have not been verified.**

`script/provision/gcp.sh` is a **placeholder**. It only prints a message pointing back to this runbook and provisions nothing. Do not rely on it to create resources.

## Verify AI access

```bash
AI_ADAPTER=vertex bin/rails runner bin/ai_smoke
```

**`bin/ai_smoke` is not currently a reliable complete smoke test.** It runs every AI kind in order and stops at the first failure:
- its first kinds call Discovery Engine, which has not been verified;
- `avatar_portrait` and `outfit_preview_subject` use discontinued Imagen models, which return 404.

To check Phase 2's AI paths, use single, targeted runner calls instead, as described in the guide, section E. Remember that `AI_ADAPTER=vertex` makes real, billed calls; only the exact value `fake` selects the fake adapter.

## Billing checks

Open GCP Billing → Reports, grouped by service, after any real-service tests. `GET /admin/ai_usage` (with the `X-Analytics-Key` header) shows today's **estimated** spend per kind from `ai_calls`. These are estimates; GCP Billing is authoritative. **The GCP Billing check for Phase 2 is still outstanding** (handoff check 7). For costs measured so far, see the guide, section F.

## Heroku

**Nothing has been deployed to Heroku in Phase 2, and these commands have not been checked against a live app.**

```bash
heroku ps
heroku logs --tail
heroku run rails db:migrate
```

Health: `GET /up`

To stop image costs immediately: `heroku config:set AI_IMAGE_GEN_ENABLED=false`.
