# MisfitAI operations runbook

## GCP setup (Phase 1)

1. Enable APIs: Vertex AI, Discovery Engine, Calendar, Analytics Data, Cloud Storage.
2. Create service account `misfit-heroku` with roles `aiplatform.user`, `discoveryengine.user`, and bucket-scoped `storage.objectAdmin`.
3. Store the JSON key in Heroku `GOOGLE_SERVICE_ACCOUNT_JSON`.
4. Create private GCS bucket in `us-central1`.

## Verify AI access

```bash
AI_ADAPTER=vertex bin/rails runner bin/ai_smoke
```

## Billing checks

Open GCP Billing → Reports grouped by Service after smoke tests. Confirm Discovery Engine and Vertex usage are covered by trial credits.

## Heroku

```bash
heroku ps
heroku logs --tail
heroku run rails db:migrate
```

Health: `GET /up`
