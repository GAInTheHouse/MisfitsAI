# Phase 1 handoff (Dev 1, 2026-10-19)

## Merge status

- **Branch:** `gxa/phase-A` → open PR into `main`
- **Offline gate:** RSpec + Cucumber + RuboCop green with `AI_ADAPTER=fake`
- **Live gate (deferred):** `bin/ai_smoke` on real GCP, Heroku manual check, billing — see [phase-2-entry.md](phase-2-entry.md). Phase 2 may start locally without these.

## Shipped

- Rails 8 skeleton, full schema (5.3), Solid Queue/Cable/Cache in primary DB (D14)
- Devise email auth + Google OAuth (calendar scope), encrypted tokens, account linking
- Layout, design tokens, shared partials, Stimulus controllers (`shared/*`), empty stepper, analytics hook
- `Feature`, `config/features.yml`, `config/options.yml` (12.3)
- Routes skeleton (7.1) with Coming Soon placeholders
- `Profiles::Context`, `Ai::Client` (Fake + Vertex, all 10 kinds), `Media::SafeFetcher`, `Media::ImageNormalizer`
- Rack::Attack, CSP/security headers, `/admin/ai_usage`
- CI (8.5), CODEOWNERS, Cucumber auth/security, authorization harness, AI fixtures
- `script/provision/gcp.sh`, `script/provision/heroku.sh`, `docs/runbook.md`, `bin/ai_smoke`

## Not done / deferred (non-blocking for Phase 2 code)

- Heroku production sign-up smoke and live `bin/ai_smoke` output (credentials)
- GCP billing check and trial end date (credentials)
- Git tag `phase-1-complete` (after live smoke + merge)

## Deviations from the design doc

- [DEVIATION] Single PR on branch `gxa/phase-A` instead of multiple `p1/<topic>` PRs (doc 10.7).
- [DEVIATION] `bin/ai_smoke` against real APIs deferred until `.env` / Heroku vars are filled (doc 3.6 ordering).
- [DEVIATION] Phase 1 **exit gate** live items waived for Phase 2 start; tracked in [phase-2-entry.md](phase-2-entry.md).
- [DEVIATION] Active Record encryption keys in `config/initializers/active_record_encryption.rb` for dev/test; production should use credentials.
- [DECISION] Pinned `json` ~> 2.7 to avoid cookie/session serialization issues with json 3.x.
- [DECISION] Authorization feature defers cross-user garment 404 until Phase 2 routes exist.

## Config vars and flags

- Production flags (defaults): `FEATURE_ONBOARDING=false`, `FEATURE_PROFILE=false`, `FEATURE_AVATAR=false`, `FEATURE_OUTFIT_PREVIEW=false`
- Copy `.env.example` → `.env` for local dev; use `AI_ADAPTER=fake` until GCP is ready

## How to verify

```bash
bin/rails db:prepare db:seed
AI_ADAPTER=fake COVERAGE=true bundle exec rspec
AI_ADAPTER=fake bundle exec cucumber
bin/rubocop
```

## AI spend

TODO: after first real smoke — `/admin/ai_usage` and GCP Billing > Reports.

## bin/ai_smoke output

TODO: paste after `AI_ADAPTER=vertex bin/rails runner bin/ai_smoke`.

## Trial end date

TODO: from GCP Billing once project is linked.

## Questions for the next phase

- Confirm SerpAPI key for Phase 2 search quota.
