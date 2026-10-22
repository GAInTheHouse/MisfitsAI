# Phase 2 handoff (Dev 2) — IN PROGRESS

> Draft kept up to date during Phase 2. It becomes the final handoff note (design doc 10.4) at the exit gate.

## Progress

| Step | Branch | Status |
|---|---|---|
| 1. Acceptance specs | `p2/acceptance-specs` | In review |

## Shipped

- Acceptance specs (all `@wip`, excluded from CI by `config/cucumber.yml`):
  - `features/wardrobe/manual_add.feature`, `manage.feature`, `search.feature`, `photo_intake.feature`
  - `features/receipts/receipts.feature`
  - Pending step definitions: `features/step_definitions/{wardrobe,search,photo_intake,receipt}_steps.rb`

## Not done / deferred

- Everything after Step 1. See `Progress`.

## Changes to Phase 1 infrastructure

- **Brakeman: temporary suppression of the Rails 8.0 pending-EOL warning only.**
  - File: `config/brakeman.ignore`. One entry (fingerprint `98b26f60…22db42`, check `EOLRails`, Medium, "Support for Rails 8.0.5.1 ends on 2026-11-07").
  - All other Brakeman checks stay enabled. CI still runs `bin/brakeman --no-pager -q -w2`.
  - **Rails must be upgraded before 2026-11-07.** On that date Brakeman switches to a High-confidence "ended on" warning with a different warning code and fingerprint, which this entry does not cover. CI will fail again on its own until Rails is upgraded.
  - Upgrading is out of Phase 2 scope. To file as a `phase-1` issue (owner: Dev 1).
- **`spec/examples.txt` untracked.** It was committed but RSpec rewrites it on every run (per-machine state). Removed from the index with `git rm --cached` (the local file is kept) and added to `.gitignore`.

## Deviations from the design doc

- [DEVIATION] 10.7: Step 1 also carries the two CI-maintenance changes above, so CI stays green for every later Phase 2 branch.

Planned, not yet made (to be confirmed in their steps):

- [DEVIATION] 6.5: `STOPWORDS`, `NEGATIVE_WORDS`, `APPAREL_HINTS`, `GARMENT_NOUNS` will be rebuilt from the rules in 6.5, because `backend/garment_search_filter.py` is not available. They make no claim to match the original lists.
- [DEVIATION] 8.4: `text_parser_spec` inputs will be written from the 6.12 algorithm, because the original `receipt_parser.py` tests are not available.
- [DEVIATION] 6.4: placeholder images will be new neutral images, because `misfitai-mobile/assets/stock/` is not available.

## Decisions made where the doc was silent

- [DECISION] Manual add submit button: "Add to wardrobe".
- [DECISION] Manual add validation copy uses the Rails defaults: "Name can't be blank", "Name is too long (maximum is 80 characters)", "Category can't be blank".
- [DECISION] The photo-intake commit button is "Add selected" (12.1 sample), not "Commit" (6.6 flow label). The flash is "N items added", singular "1 item added".
- [DECISION] Photo upload errors reuse the 6.11 avatar copy: "Image too large" and "Please upload a JPEG, PNG, WebP or HEIC image".
- [DECISION] A failed photo analysis shows a "Try again" button that returns to the upload form. There is no retry route for photo intakes in 7.1.
- [DECISION] A receipt over 10 MB shows "File too large".
- [DECISION] Extra scenarios beyond the 12.1 minimum: a category is required, an 80-character name limit, the image kill switch and the blocked-image fallback, a private-address image is never fetched (4.4), the 6-draft cap, draft image failure, discard, the source photo is purged, and the feature flags hide the Photo AI and Receipt tabs.

## Known issues (Phase 1, to file; not blocking Phase 2)

- Rails 8.0 end of life on 2026-11-07 (see above).
- `config/initializers/vips.rb` checks `defined?(Vips)`, but `ruby-vips` is `require: false`, so the memory limits never apply (R14 risk on Heroku).
- Rack::Attack has no 60-per-hour per-user limit on AI POSTs (4.4).
- `ApplicationJob` has no default queue or retry/discard policy.
- `AVATAR_IMAGEN_MODEL` is not read; avatars use `IMAGEN_MODEL` (Phase 4 concern).
- `APP_HOST` is not read (OmniAuth `full_host`, mailer host is hardcoded to `example.com`).

## Schema changes after Phase 1

- None yet.

## Config vars and flags

- None added. Local development and all tests use `AI_ADAPTER=fake` and stubbed HTTP. No real credentials are configured.

## Integration tests that need credentials (run before the exit gate)

1. SerpAPI with a real `SERPAPI_KEY`: response shape matches `spec/fixtures/serpapi/*`, page-2 backfill, quota use.
2. `ImportRemoteImageJob` fetching real third-party image hosts through `Media::SafeFetcher`.
3. Vertex `garment_extraction` and `receipt_extraction` with the Phase 2 response schemas against real Gemini.
4. Imagen `garment_image` (garments and drafts), including the content-blocked fallback.
5. GCS uploads and blob copies on draft commit (`GCS_BUCKET`, service account `storage.objectAdmin`).
6. Second GCP billing check (design doc 3.4 step 6).
7. Heroku exit gate: all four intake paths at 390 px, no R14 memory errors.

## How to verify (Step 1)

```bash
AI_ADAPTER=fake COVERAGE=true bundle exec rspec
AI_ADAPTER=fake bundle exec cucumber                 # @wip excluded by the default profile
AI_ADAPTER=fake bundle exec cucumber --no-profile --dry-run --strict --tags @wip features   # all Phase 2 steps defined, none ambiguous
bin/rubocop && bin/brakeman --no-pager -q -w2 && bundle exec bundler-audit check --update
```
