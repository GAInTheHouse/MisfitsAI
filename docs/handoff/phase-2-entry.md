# Phase 2 entry (read after Phase 1 PR merges)

Phase 1 code is merge-ready when CI is green on the PR. **Live GCP/Heroku exit checks can finish in parallel** while Phase 2 starts locally.

## Start Phase 2 now (no production credentials required)

1. Check out `main` after the Phase 1 PR merges (or continue from `gxa/phase-A` until then).
2. `bin/setup` — uses `AI_ADAPTER=fake` via `.env` / test defaults.
3. `AI_ADAPTER=fake COVERAGE=true bundle exec rspec && AI_ADAPTER=fake bundle exec cucumber`
4. Read [phase-1.md](phase-1.md) and sections 6.4–6.6, 6.12, 11.2 of the design doc.
5. Use `Profiles::Context`, `Ai::Client.current` (Fake in tests), `Media::SafeFetcher`, shared partials under `app/views/shared/`, and Stimulus under `app/javascript/controllers/shared/`.

## Finish Phase 1 exit gate later (needs credentials)

When GCP/Heroku/OAuth are ready (owner or Dev 1):

| Step | Command / action |
|------|------------------|
| Provision GCP | `./script/provision/gcp.sh YOUR_PROJECT_ID`. **Placeholder:** it only prints a message and provisions nothing. For what actually exists, see [`docs/google-cloud-setup.md`](../google-cloud-setup.md) |
| OAuth client | Console checklist in [runbook.md](../runbook.md). *(Note, 2026-10-22: the runbook has no OAuth checklist.)* |
| Provision Heroku | `./script/provision/heroku.sh misfit-ai` + GitHub auto-deploy. **Placeholder:** the script only prints a message |
| Smoke test | `AI_ADAPTER=vertex bin/rails runner bin/ai_smoke` (paste output into `phase-1.md`) |
| Billing | GCP Billing > Reports; `/admin/ai_usage` with `X-Analytics-Key` |
| Tag | After merge + smoke: `git tag phase-1-complete && git push --tags` |

## Canonical Cucumber tables (Phase 2 implements steps)

**Wardrobe:**

```gherkin
Given my wardrobe contains:
  | name | category | formality | color | size | gender | hidden | times_recommended |
```

**Week (Phase 3):**

```gherkin
Given my week is:
  | day | event_type |
```

## Contracts you consume

- `Ai::Client.current` — never call Vertex directly
- `Media::SafeFetcher.fetch(url)` — never raw `Net::HTTP` for user URLs
- `Profiles::Context.for(user)` — read profile data in services
