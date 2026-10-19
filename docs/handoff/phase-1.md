# Phase 1 handoff (Dev 1, 2026-10-19)

## Shipped

- Rails 8 skeleton, full schema (5.3), Solid Queue/Cable/Cache in primary DB (D14)
- Devise email auth + Google OAuth (calendar scope), encrypted tokens, account linking
- Layout, design tokens, shared partials, Stimulus controllers, empty stepper, analytics hook
- `Feature`, `config/features.yml`, `config/options.yml` (12.3)
- Routes skeleton (7.1) with Coming Soon placeholders
- `Profiles::Context`, `Ai::Client` (Fake + Vertex, all 10 kinds), `Media::SafeFetcher`, `Media::ImageNormalizer`
- Rack::Attack, CSP/security headers, `/admin/ai_usage`
- CI (8.5), CODEOWNERS, Cucumber auth/security, authorization harness, AI fixtures
- `script/provision/gcp.sh`, `script/provision/heroku.sh`, `docs/runbook.md`, `bin/ai_smoke`

## Not done / deferred

- Heroku production verification and live `bin/ai_smoke` (blocked on GCP/Heroku config vars — see below)
- Phase 2–4 feature UIs (intentional forward slots)

## Deviations from the design doc

- [DEVIATION] Single PR on branch `gxa/phase-A` instead of multiple `p1/<topic>` PRs (doc 10.7).
- [DEVIATION] `bin/ai_smoke` against real APIs deferred until after `.env` / Heroku vars are filled (doc 3.6 ordering).
- [DEVIATION] Active Record encryption keys in `config/initializers/active_record_encryption.rb` for dev/test; production should use credentials.
- [DECISION] Pinned `json` ~> 2.7 to avoid cookie/session serialization issues with json 3.x.

## Config vars and flags

- Production flags (defaults): `FEATURE_ONBOARDING=false`, `FEATURE_PROFILE=false`, `FEATURE_AVATAR=false`, `FEATURE_OUTFIT_PREVIEW=false`
- Fill `.env` from `.env.example` before provisioning

## How to verify

1. `bin/setup` (or `bundle install`, `bin/rails db:prepare`)
2. `AI_ADAPTER=fake COVERAGE=true bundle exec rspec`
3. `AI_ADAPTER=fake bundle exec cucumber`
4. After credentials: `./script/provision/gcp.sh PROJECT_ID`, OAuth console steps in `docs/runbook.md`, `./script/provision/heroku.sh APP_NAME`
5. `bin/rails runner bin/ai_smoke` locally, then `heroku run bin/rails runner bin/ai_smoke`

## AI spend

TODO: `/admin/ai_usage` today; GCP billing check after first smoke run.

## bin/ai_smoke output

TODO: paste output after real API run.

## Trial end date

TODO: record from GCP Billing after project is linked.

## Questions for the next phase

- Confirm SerpAPI key for Phase 2 search quota.
