# Phase 2 handoff (Dev 2, 2026-10-21)

> **Status: implementation complete and verified locally. The exit gate is NOT passed.** Items 1, 3, 4, 5 and 8 of the 10.4 gate need the PR, the Heroku deploy and real credentials (see "Exit gate"). Nothing in this note has been run against real Google Cloud or SerpAPI. "Verified" means verified locally with the fake AI adapter and stubbed HTTP, unless it says otherwise.

## Contents

1. Progress
2. Shipped (implemented functionality)
3. Architecture and service contracts
4. Not done / deferred
5. Deviations from the design doc
6. Decisions made where the doc was silent
7. Changes to Phase 1 infrastructure (Phase 1 issues found and fixed)
8. Known issues: remaining Phase 1 issues for Dev 1
9. Security and reliability decisions
10. Schema changes after Phase 1
11. Config vars and flags
12. Deployment instructions
13. Known limitations and residual risks
14. Integration tests that need real credentials
15. How to verify
16. Local verification results
17. Exit gate (10.4)
18. AI spend
19. bin/ai_smoke output
20. Questions for the next phase

## 1. Progress

All Phase 2 work is committed directly on `phase-2`, one or more logical commits per step. It goes to `main` as a single PR at the end, the same approach as Phase 1. The PR is not open yet.

| Step | Commit | Status |
|---|---|---|
| 1. Acceptance specs (and CI maintenance) | `797e03a`, `55ce9ae` | Done |
| 2. Test infrastructure and prerequisites | `d9cf933` | Done |
| 3. Model layer | `5d1912f` | Done |
| 4. Wardrobe UI and manual garment management | `3ec529d` | Done |
| 5. AI image generation and bulk garment creation | `edaa1ce` | Done |
| 6. Garment image search and remote image import | `290f349` | Done |
| 7. AI photo intake | `661d975` | Done |
| 8. Receipt parsing and intake | `9ff2aa0` | Done |
| 9. Security, authorization and reliability review | `a7438c0` | Done |
| 10. Demo data, final verification and handoff | the commit that adds this note | Done (exit gate still open, section 17) |

## 2. Shipped (implemented functionality)

Each feature lists the scenarios that cover it. No Phase 2 scenario is `@wip`.

| Feature | Scenarios |
|---|---|
| Wardrobe page (`GET /wardrobe`): count, planning hint, "Next: plan your week", add panel (Photo AI / Describe item (Manual, Search) / Receipt), category filter in a Turbo Frame, cards, empty states | `features/wardrobe/manage.feature` (12 scenarios, 2 `@javascript`) |
| Manual add (`POST /garments`), with an optional AI product image | `features/wardrobe/manual_add.feature` (11, 2 `@javascript`) |
| Hide / show (`Wardrobe::SetHidden`) and delete | `manage.feature` |
| Image generation (`Wardrobe::GenerateGarmentImageJob`), the kill switch, the blocked fallback, retry after failure | `manual_add.feature` |
| Garment image search (SerpAPI) and remote image import (`Media::SafeFetcher`) | `features/wardrobe/search.feature` (10, 1 `@javascript`) |
| AI photo intake: upload, scanning, draft review, edits, commit, discard, purge | `features/wardrobe/photo_intake.feature` (12, 2 `@javascript`) |
| Receipts: pasted text, PDF, text file, receipt image (vision), review, commit | `features/receipts/receipts.feature` (10, 1 `@javascript`) |
| Feature flags hide the Photo AI and Receipt tabs | `manage.feature` |
| Demo wardrobe seed (15 garments with images, idempotent, never touches the user's own garments) | `spec/seeds/demo_seeds_spec.rb` |
| Demo account seed hardening (Phase 1 fix) | `spec/seeds/demo_user_spec.rb` |

Details by step:

- **Acceptance specs (Step 1):** the five feature files above, written first as `@wip`, and their step definitions in `features/step_definitions/{wardrobe,search,photo_intake,receipt}_steps.rb`.
- **Test harness (Step 2):**
  - `features/harness/test_harness.feature` with `harness_steps.rb` and `features/support/harness_jobs.rb`.
  - `spec/infrastructure/test_harness_spec.rb`.
  - Implemented the steps "my wardrobe contains:" (the 8.3 canonical table), "AI image generation is disabled", "the AI blocks images for {string}" and "the {string} feature is disabled".
  - Factories in `spec/factories/garments.rb`: `:garment` (traits `:hidden`, `:pending_image`, `:with_image`), `:intake_batch`, `:garment_draft`.
  - Upload fixtures in `spec/fixtures/files/`. Oversized uploads are generated at run time.
- **Model layer (Step 3):**
  - `Garment`:
    - `thumb` (256 fill) and `card` (512 limit) variants;
    - `Garment.normalize_kind`;
    - normalization of the name, sub-category, colours and blank fields;
    - an 80-character name limit;
    - `price_cents` and `times_recommended` must be non-negative;
    - `#placeholder_asset`, `Garment.outfit_ready?` and `Garment.with_image_variants`.
  - `GarmentDraft`: status, the `attrs` hash, ownership checks, the scopes `ordered`, `committable` and `stale`, and the predicates.
  - `IntakeBatch`: kind, status, progress and parser-strategy validations; the 600-character `extracted_text_preview`; the scopes `photos`, `receipts` and `stale`; and the methods `mark_processing!`, `mark_ready!` and `mark_failed!`.
  - Placeholder images in `app/assets/images/placeholders/*.jpg`.
- **Wardrobe UI (Step 4):** `GarmentsController` and its partials:
  - `garments/_garment`;
  - `garments/_thumb`, the contract partial for Phase 3, with `dom_id(garment, :thumb)`;
  - `_status`, `_add_panel`, `_form`, `_inventory` and `_empty`.
- **AI images and bulk add (Step 5):**
  - `Wardrobe::Prompts.garment_image` (exactly the 6.4 prompt);
  - `Wardrobe::GenerateGarmentImageJob`;
  - `POST /garments/:id/retry_image`;
  - `Wardrobe::AddGarments` and `Wardrobe::StarterImport`.
- **Search and import (Step 6):**
  - `Wardrobe::Search::{ImageSearch, FilterAndRank, WordLists, AddResult, Error}`;
  - `Wardrobe::SearchesController` (`new`, `create`, `select`);
  - `Wardrobe::ImportRemoteImageJob`.
- **Photo intake (Step 7):**
  - Controllers: `Wardrobe::PhotoIntakesController`, `IntakeBatchesController` (`commit` and `destroy`) and `DraftsController#update`.
  - Photo-intake services: `Wardrobe::PhotoIntake::{Prompts, Mapper, ImagePreparer, Commit}`.
  - Jobs: `Wardrobe::ExtractGarmentsJob`, `GenerateDraftImageJob` and `PurgeStaleDraftsJob` (daily at 4am, `config/recurring.yml`).
- **Receipts (Step 8):**
  - `Wardrobe::ReceiptsController`.
  - Receipt services: `Receipts::{TextParser, PdfText, VisionParser, Prompts, Intake, Commit}`.
  - `Receipts::ParseImageJob`.
  - Shared with photo intake: `Wardrobe::DraftEdits` and `IntakeBatchJobSupport`.
- **Security review (Step 9):** see section 9. The regression specs are in `spec/requests/phase2_security_spec.rb`, `spec/requests/rate_limits_spec.rb` and `spec/channels/cable_authorization_spec.rb`.
- **Demo data (Step 10):**
  - `db/seeds.rb` now calls `DemoWardrobe.seed(user)` (`db/seeds/demo_wardrobe.rb`), which seeds the 15 garments listed in `db/seeds/demo_wardrobe_items.rb`.
  - The images are `db/seeds/images/*.jpg` (512x512 JPEG, about 140 KB in all), generated by `script/generate_seed_images.rb`.
  - The silhouette drawing is shared with the placeholder script through `script/lib/garment_silhouettes.rb`. The six placeholder JPEGs it produces are byte-identical to the Step 3 versions.

### The demo wardrobe

| Category | Garments |
|---|---|
| Top | White Oxford Shirt, Light Blue Button-down, Navy Crewneck Sweater, Grey Performance Tee |
| Bottom | Charcoal Dress Pants, Dark Wash Jeans, Khaki Chinos, Black Running Shorts |
| Dress | Black Midi Dress |
| Outerwear | Camel Wool Coat, Denim Jacket |
| Shoes | White Leather Sneakers, Brown Leather Loafers, Black Running Shoes |
| Accessory | Black Leather Belt |

The set covers formal, business, smart casual, casual and athletic, and every season, so Phase 3's engine has something to choose from for each occasion.

What a seed run does:
- Each seeded garment is marked with `source: "starter"` and a `source_url` of `demo-seed:<image file>` (for example `demo-seed:white_oxford_shirt.jpg`). A run looks garments up by that marker only, so running it again updates the same 15 rows and never duplicates them.
- A garment the user added is never matched, even with the same name as a demo garment, because it lacks the marker. Starter-catalog garments from Phase 4 have no `source_url` either. No column was added: `source_url` is free for seeded rows (they have no web source), and no view links to it.
- It sets `image_status: "ready"`.
- It attaches the image only when there is none or its checksum differs, so a second run creates no new blobs.
- It leaves `times_recommended`, `hidden_from_recommendations` and any garment the user added by hand untouched.
- It makes no AI calls and queues no jobs.

## 3. Architecture and service contracts

Phase 2 provides these contracts (4.2, 10.1). Each exists with its documented signature and has RSpec coverage.

| Contract | Signature | Returns / raises | Spec |
|---|---|---|---|
| Starter import (for Phase 4) | `Wardrobe::StarterImport.call(user:, items:)` | `Array<Garment>`; queues `GenerateGarmentImageJob` after commit | `spec/services/wardrobe/starter_import_spec.rb` |
| Bulk add | `Wardrobe::AddGarments.call(user:, items:, source:, generate_images: true)` | `Array<Garment>`; one transaction; raises `ActiveRecord::RecordInvalid` | `spec/services/wardrobe/add_garments_spec.rb` |
| Garment hide (Phase 3 calls it) | `Wardrobe::SetHidden.call(user:, garment:, hidden:)` | the garment; broadcasts the card and header to `[user, :wardrobe]` | `spec/services/wardrobe/set_hidden_spec.rb` |
| Thumbnail partial (Phase 3 renders it) | `render "garments/thumb", garment:, class: "..."` | `<img id=dom_id(garment, :thumb)>`; jobs re-broadcast it | `spec/views/garments/_thumb.html.erb_spec.rb` |
| Read-only model API | `user.garments.visible`, `Garment.outfit_ready?`, `Garment.with_image_variants` | scopes | `spec/models/garment_spec.rb` |
| Safe fetch (Phase 1 contract, hardened) | `Media::SafeFetcher.fetch(url, max_bytes:, timeout:)` | `Ai::Image`; raises `Media::UnsafeUrlError` or `Media::FetchError` (`Media::TransientFetchError` is a subclass) | `spec/services/media/safe_fetcher_spec.rb` |

Internal entry points (not called across domains):
- `Wardrobe::Search::ImageSearch.call(...)` returns an array of `{ image_url, title, source_url, thumbnail_url }` and raises `Wardrobe::Search::Error`, which carries an HTTP status.
- `Wardrobe::Search::FilterAndRank` (the 6.5 algorithm).
- `Wardrobe::PhotoIntake::Commit.call(batch:, edits:)`.
- `Receipts::TextParser.call(text)`.
- `Receipts::PdfText.call(io)` raises `Receipts::UnreadableError`.
- `Receipts::VisionParser`.
- `Receipts::Intake.from_text` and `Receipts::Intake.finish`.
- `Receipts::Commit.call(batch:, edits:, generate_images:)`.

### Jobs and queues

| Job | Queue | Concurrency key |
|---|---|---|
| `Wardrobe::GenerateGarmentImageJob` | `ai_images` | one run per garment |
| `Wardrobe::GenerateDraftImageJob` | `ai_images` | one run per draft |
| `Wardrobe::ExtractGarmentsJob` | `ai_text` | one run per batch |
| `Receipts::ParseImageJob` | `ai_text` | one run per batch |
| `Wardrobe::ImportRemoteImageJob` | `default` | one run per garment |
| `Wardrobe::PurgeStaleDraftsJob` | `default` | recurring, daily at 4am |

How the pieces connect:
- Every job declares its handlers in the same order: a catch-all `rescue_from` first, then the specific handlers, then `retry_on`, then `discard_on`.
- Every live update is a Turbo broadcast to `[user, :wardrobe]`. The image broadcasts are shared through `Wardrobe::GarmentBroadcasts`.
- Photo intake and receipts share the same tables (`IntakeBatch` and `GarmentDraft`), the same commit and discard routes, the edit step (`Wardrobe::DraftEdits`), the job support (`IntakeBatchJobSupport`), the upload concern (`IntakeUpload`) and the `wardrobe--draft-selection` Stimulus controller.

## 4. Not done / deferred

- **Photo intake click-to-zoom `<dialog>`** (6.6, listed "may defer" in 11.2): not built. Proposed for Phase 4's stretch list.
- **Receipt LLM cleanup** (`RECEIPT_LLM_CLEANUP`, an optional stretch in 6.12): not built. Phase 4 stretch list.
- **Search re-ranking with the Ranking API** (`SEARCH_RERANK_ENABLED`, a 6.5 stretch): not built. Phase 4 stretch list.
- **Production verification:** nothing has been run against real Vertex, Imagen, SerpAPI, GCS or Heroku. See sections 14 and 17.

## 5. Deviations from the design doc

**Process**
- [DEVIATION] 10.7: Phase 2 is one PR with logical commits on `phase-2`, not one PR per `p2/<topic>` branch. This follows the Phase 1 approach, at the team's request. Step 1 was written on `p2/acceptance-specs` and fast-forwarded into `phase-2`.
- [DEVIATION] 10.7: Step 1 also carries two CI-maintenance changes (the Brakeman EOL entry and untracking `spec/examples.txt`), so CI stays green for the rest of Phase 2.

**Reconstructed reference material**

The original sources were not available, so these were rebuilt. None of them claims to match the original.
- [DEVIATION] 6.4: the six placeholder images are new flat silhouettes, drawn with libvips by `script/generate_placeholder_images.rb`, because `misfitai-mobile/assets/stock/` is not available. The doc maps four stock photos onto six categories; there is now one image per category.
- [DEVIATION] 9.4: the 15 demo images in `db/seeds/images/` are generated silhouettes in the garment's colour, drawn by `script/generate_seed_images.rb`, not product photos. That keeps the seed free of third-party image rights and of AI calls. They can be replaced with real photos (same file names) at any time; the seed re-attaches any image whose checksum changed.
- [DEVIATION] 6.5: the lists `STOPWORDS`, `NEGATIVE_WORDS`, `APPAREL_HINTS` and `GARMENT_NOUNS` (`app/services/wardrobe/search/word_lists.rb`) are rebuilt from the role 6.5 gives each one, because `backend/garment_search_filter.py` is not available. `filter_and_rank_spec` pins the algorithm with cases whose outcome follows from the doc.
- [DEVIATION] 8.4: the inputs in `spec/services/receipts/text_parser_spec.rb` are written from the 6.12 algorithm, because the original `receipt_parser.py` tests are not available.

**Behaviour**
- [DEVIATION] 3.6 and 6.4: Phase 2 garment product images are generated by a Gemini image model, not Imagen.
  - **What the doc specifies:** `generate_image` calls Imagen (`IMAGEN_MODEL`, `imagen-4.0-fast-generate-001`) through `:predict`.
  - **Why it changed:** Google's release notes (March 24, 2026) list the Imagen GA endpoints, including `imagen-4.0-fast-generate-001`, as discontinued, with `gemini-2.5-flash-image` as the recommended migration. Integration check 5 got HTTP 404 from that model for our project and region.
  - **What was built:**
    - For `kind: :garment_image`, `generate_image` uses the new `GARMENT_IMAGE_MODEL` (default `gemini-2.5-flash-image`). A `gemini-*` model is called through `generateContent`, with the request `contents: [{role: "user", parts: [{text: prompt}]}]` and `generationConfig: {responseModalities: ["TEXT", "IMAGE"], imageConfig: {aspectRatio: "1:1"}}`.
    - The image is the first `inlineData` part of the response, with its MIME type.
    - The 6.4 prompt and the draft-image prompt are unchanged.
    - An `imagen-*` value keeps the original Imagen request byte for byte.
    - Other image kinds (the Phase 4 avatar) still read `IMAGEN_MODEL`.
- [DEVIATION] 3.6 and 3.7: Vertex error handling distinguishes more failure kinds. The five 3.7 classes are unchanged; new classes are added alongside them.
  - **What the doc specifies:**
    - 3.7 lists `TransientError` (429, 5xx, timeouts) and `ContentBlockedError` ("safety filter / empty result").
    - 3.6 says an empty Imagen `predictions` is a `ContentBlockedError`.
  - **What was built:**
    - `ContentBlockedError` now needs an explicit safety indicator. An empty result without one, including empty Imagen predictions, is the new `Ai::InvalidResponseError`.
    - New classes: `Ai::InvalidRequestError`, `Ai::AuthenticationError`, `Ai::NotFoundError`, `Ai::RateLimitedError` (a `TransientError`) and `Ai::InvalidResponseError` (section 7).
  - **Why:** before the first real calls, a 400 schema error, a 401/403 credentials problem or a 404 wrong model ID was reported as a safety block or a parse error. Jobs then quietly fell back to a placeholder.
- [DEVIATION] 3.4: Google authentication also supports Application Default Credentials for local development.
  - **What the doc specifies:** `Ai::GoogleToken` always reads `GOOGLE_SERVICE_ACCOUNT_JSON`, because Heroku has no ADC.
  - **What was built:**
    - When `GOOGLE_SERVICE_ACCOUNT_JSON` is set and nonblank, the service-account key is used exactly as before. This is the deployment path, and its behaviour is unchanged.
    - When the variable is absent or blank, `Google::Auth.get_application_default` is used instead (`gcloud auth application-default login`, `GOOGLE_APPLICATION_CREDENTIALS`, or the metadata server).
  - **Why:** the team chose local integration testing with `gcloud` ADC rather than creating and downloading a service-account key (2026-10-22). Production keeps the doc's key-based setup.
  - **Scope:** Vertex AI only. GCS authentication (`config/storage.yml`) is unchanged and still reads `GOOGLE_SERVICE_ACCOUNT_JSON`.
- [DEVIATION] 6.12: the receipt review is a list of editable cards instead of a table, so it works at 390 px. It has the fields 6.12 lists.
- [DEVIATION] 6.6: the response schema gains an optional `confidence` number. It is not required, and the prompt text is unchanged. Drafts store `confidence` and `needs_confirmation`, and a draft is flagged "Please double-check" when its confidence is under 0.75 (the receipt threshold in 6.12) or when its category fell back to `top`.
- [DEVIATION] 6.12: `Receipts::TextParser` fixes three bugs of the original (approved in Step 8). Specs pin each fix:
  - Sizes are looked for after removing prices, SKUs and the leading quantity. The original ran `SIZE_RE` over the whole line, so a price gave a size ("$39.90" became size "39").
  - `NON_ITEM_TERMS` match whole words, with an optional plural. The original matched substrings, so "card" excluded every "Cardigan" line.
  - A priced line that names no garment ("Coffee 3.50") is still returned, but it is flagged, marked `category_found: false`, and starts unselected.
  - Also: names lose hyphens left at their ends by the removals.
  - Kept as in 6.12: the fallback hint is a whole word ("trouser" misses "trousers"), and its 24-character snippet can merge nearby words.

## 6. Decisions made where the doc was silent

**Copy and UI**
- [DECISION] The manual-add submit button reads "Add to wardrobe".
- [DECISION] Validation messages are the Rails defaults ("Name can't be blank", "Name is too long (maximum is 80 characters)", "Category can't be blank"). A blank category gives one error, not two.
- [DECISION] The photo-intake commit button is "Add selected" (the 12.1 sample), not "Commit". The flash reads "N items added", or "1 item added".
- [DECISION] Photo upload errors reuse the 6.11 avatar copy ("Image too large", "Please upload a JPEG, PNG, WebP or HEIC image"). A receipt over 10 MB shows "File too large".
- [DECISION] A failed photo or receipt shows "Try again", which discards the batch and returns to the form. There is no retry route in 7.1.
  - The vision cap message is "You've reached today's photo analysis limit. Please try again tomorrow."
  - An unreadable stored photo gets "We couldn't read that photo. Please upload a JPEG, PNG, WebP or HEIC image."
- [DECISION] 12.3 says "SEARCH_BRANDS, 50" but lists 51 brands. All 51 are kept, in the doc's order.
- [DECISION] The add panel opens on "Describe item" (Manual). Inactive panels are rendered `hidden` and switched by `shared--tabs`.
- [DECISION] Card actions ("Hide from outfits" or "Show in outfits", and "Delete") are visible buttons, not a `<details>` menu, which would hide them from rack-test and from a first glance on mobile.
- [DECISION] The name field has no `maxlength`, because browsers would silently cut the name. The 80-character limit is enforced by the model instead, with a hint and an error.
- [DECISION] "Next: plan your week" and the planning hint count visible garments only (the 6.7 planner guard), so the link never leads to a guard error.
- [DECISION] A filtered view with no matches shows "No {category} items in your wardrobe yet."
- [DECISION] `PATCH /garments/:id/hide` without `hidden` hides the garment, as in Phase 1.
- [DECISION] Draft image broadcasts replace only the image area and the progress bar, so edits made while images arrive are kept.
- [DECISION] `turbo_stream_from` sits inside the `photo_intake` and `receipt_intake` frames, because Turbo keeps only the frame's contents when the frame navigates.

**Models and data**
- [DECISION] Enums stay as string columns with `inclusion` validations (the Phase 1 convention). Status predicates are defined from the `STATUSES` constants.
- [DECISION] `garment_drafts.status` and `intake_batches.status` default to `pending` through the Rails attribute API, not a database default. This keeps the schema change to the approved G6 migration.
- [DECISION] Blank form strings are stored as nil on `Garment`, so `formality: nil` keeps meaning "untagged" for the engine (6.8.3).
- [DECISION] Form objects are built with `Garment.new`, never `current_user.garments.new`, so an unsaved record never joins the loaded association and is never counted.
- [DECISION] Garments created by the "Given my wardrobe contains:" step use `source: manual` and `image_status: placeholder`.
- [DECISION] Demo-seeded garments are identified by `source: "starter"` plus a `demo-seed:<image file>` `source_url`, not by name, so the seed never updates a garment the user created. This needs no schema change.
- [DECISION] A draft is committable when it is selected and `pending` or `ready`. A draft whose image failed keeps the placeholder and stays committable. `failed` means it cannot be committed.

**Images**
- [DECISION] Image status:
  - `placeholder` means "no image by design" (manual add without the checkbox, switched off, over quota, blocked). It offers no retry.
  - `failed` means the last transient retry failed. The card offers "Retry image".
- [DECISION] `IMAGE_GEN_SPACING_SEC` is not used: each job generates one image, and production runs `ai_images` with one thread (6.4 rule 5).
- [DECISION] `garments/_thumb` takes an optional `class:`, defaulting to `h-full w-full object-cover`. Callers should size the wrapping element, because broadcasts re-render the partial with the default.
- [DECISION] `StarterImport` defaults the season to `all_season` (12.3) and accepts the catalog's `sub_category`. With images requested the status is `pending` (6.3), otherwise `placeholder`.
- [DECISION] `AddGarments` and `StarterImport` save every item in one transaction and queue image jobs in `ActiveRecord.after_all_transactions_commit`, so they wait for every open transaction, including a caller's outer one. A rollback queues nothing. Unknown item keys are ignored, and `color` is accepted for `color_primary`. Phase 4 should validate onboarding rows before calling.

**Search**
- [DECISION] Search results also carry `thumbnail_url` (the provider's thumbnail) for the preview. The server downloads only `image_url`, and only after the user picks it.
- [DECISION] When a picked result has no category, `AddResult` takes the category of the chosen kind. Failing that, it uses a garment noun from the title or keywords; failing that, it shows "Category can't be blank".
- [DECISION] Search errors answer with the status the error implies: 422 (missing query), 502 (provider failure), 503 (not configured) or 504 (timeout or connection failure). They render in the results frame. SerpAPI's 200 "no results" response counts as an empty result.

**Receipts**
- [DECISION] Receipt input limits:
  - 10 MB per file;
  - pasted text up to 20,000 characters;
  - PDF text from the first 20 pages, at most 50,000 characters;
  - text files read up to 20,000 characters.
  - The kind of input is decided from its bytes, never its name or Content-Type.
- [DECISION] A receipt with no items found ends as a failed batch ("We couldn't find any clothing items on that receipt."). Receipt images are prepared at up to 2400 px (photos: 1600 px) so small print stays legible.
- [DECISION] Edited receipt prices accept "39.90", "$39.90" or "39,90". Anything else shows "Price must be a number like 39.90" and saves nothing. A blank price means unknown, so there is no price note. The 6.12 price note (`fit_notes = "Receipt price: $%.2f"`) is built by `Receipts::Commit`.

**Tests**
- [DECISION] The extra scenarios beyond the 12.1 minimum cover:
  - the category requirement and the 80-character limit;
  - the image kill switch and the blocked fallback;
  - a private-address image is never fetched;
  - the 6-draft cap, draft image failure, discard, and the source-photo purge;
  - the feature-flag tabs;
  - one `@javascript` scenario per intake path.

## 7. Changes to Phase 1 infrastructure (Phase 1 issues found and fixed)

### Fixed on behalf of Phase 1 (owner to notify: Dev 1)

Each fix has a regression spec that fails on the old code, unless stated.

- **AI error classes did not autoload** (`app/services/ai/{error,transient_error,content_blocked_error,quota_exceeded_error,disabled_error}.rb`).
  - They were defined inside `ai/client.rb`, so a job's class-level `retry_on Ai::TransientError` raised `NameError` in development and test. CI hid it by eager loading.
  - Each class now has its own file with the same definition, and `bin/rails zeitwerk:check` passes.
- **Media error classes had the same problem** (`app/services/media/{invalid_image,unsafe_url,fetch}_error.rb`). `BLOCKED_HOSTS` moved to `Media::SafeFetcher::BLOCKED_HOSTS`; nothing referenced the old constant.
- **The flash container was destroyed by the first Turbo Stream error** (`app/controllers/application_controller.rb`). `handle_application_error` used `turbo_stream.replace("flash", ...)` on a partial with no `#flash` wrapper. It now uses `update`. Spec: `spec/controllers/application_controller_spec.rb`.
- **`Ai::Client::Fake#generate_json` and `#generate_text` skipped the quota checks**, so the vision cap and global budget were never tested (3.7 says the fake exists so "the budget logic gets tested too"). Both now call `check_quotas!`, as Vertex does.
- **AI fixture PNGs were corrupt** (`spec/fixtures/ai/*.png`): all ten were 1x1 PNGs with a bad zlib checksum. They are regenerated as valid 64x64 PNGs, one colour per kind (8.2 allows refining fixtures).
- **Missing favicon links** in `app/views/layouts/application.html.erb`. Chrome requested `/favicon.ico`, the routing error was re-raised by Capybara, and every `@javascript` scenario failed.
- **Phase 1 gap list from Step 0:**
  - G1: the AI extraction fixtures now hold `items` shaped like the 6.6 and 6.12 schemas.
  - G2: `config/options.yml` has the full 21-item starter catalog plus `search_brands`, `search_materials` and `search_kinds_by_category`.
  - G3: the test Action Cable adapter is `async`; RSpec swaps in the test adapter per example.
  - G4: "When background jobs finish" drains the queue, and under rack-test it then reloads the page after a GET.
  - G5: `Media::SafeFetcher` is hardened (section 9).
  - G6: the `garment_drafts.attrs` default (section 10).
  - G8: the `.pill`, `.tab`, `.badge`, `.spinner` and `.input` CSS.
  - G9 was a false alarm: libvips loads at boot, so `config/initializers/vips.rb` applies.

- **Demo account seed** (`db/seeds.rb`, new `db/seeds/demo_user.rb`). Spec: `spec/seeds/demo_user_spec.rb` (each case fails on the old seed).
  - The seed printed `demo@misfit.ai / <password>`, which lands in Heroku logs. It now prints only the email.
  - Production fell back to the known password `changeme`, and `db:prepare` (run by `bin/docker-entrypoint` and `bin/setup`) seeds every new database, so a deploy could create that account by accident. In production now:
    - with no `DEMO_PASSWORD` (or a blank one), the demo account and its wardrobe are skipped, with a message, and the deploy carries on;
    - a known password (`changeme`, `password`, `demo`, `misfit`, in any case) or one under 12 characters stops the seed with `DemoUser::InsecurePasswordError`, before anything is created or changed, including an existing demo account's password.
  - Development and test keep the `changeme` default from `.env.example`.

### Other changes to Phase 1 files

- **Garment images through Gemini** (`app/services/ai/client/vertex.rb`; [DEVIATION] 3.6/6.4 in section 5; approved 2026-10-22). The public interface `generate_image(kind:, prompt:, aspect_ratio: "1:1", user:)` is unchanged, and the image jobs, prompts, fake adapter and authentication are untouched.
  - **Model selection:** `kind: :garment_image` reads `GARMENT_IMAGE_MODEL` (default `gemini-2.5-flash-image`). A `gemini-*` model goes through the new private `generate_gemini_image`; any other value keeps the Imagen `:predict` request unchanged (regression-tested). Every other image kind still reads `IMAGEN_MODEL`. `IMAGEN_MODEL`, `AVATAR_IMAGEN_MODEL`, `OUTFIT_SUBJECT_MODEL` and `OUTFIT_GEMINI_IMAGE_MODEL` are unchanged.
  - **Request differences from Imagen:**
    - `generateContent` on the model, with `contents` (the prompt);
    - `generationConfig.responseModalities ["TEXT", "IMAGE"]` and `generationConfig.imageConfig.aspectRatio`;
    - no `instances`, `sampleCount`, `personGeneration`, `addWatermark` or `outputOptions`.
  - **Response differences from Imagen:**
    - Gemini returns `candidates[0].content.parts[]`, which may mix text and image parts. The first `inlineData` part is decoded (`Base64.strict_decode64`) with its `mimeType`; a missing or non-image MIME type falls back to `image/png`.
    - Imagen returned `predictions[0].bytesBase64Encoded` and was always treated as PNG.
    - The bytes go through `Media::ImageNormalizer.to_square_jpeg`, which checks the type from the bytes, as before.
  - **Safety and errors:**
    - **Safety block** (`ContentBlockedError`, logged `blocked`, the garment keeps the placeholder): no image, together with `promptFeedback.blockReason` or a `finishReason` of `IMAGE_SAFETY`, **`IMAGE_PROHIBITED_CONTENT`** (newly added to the blocked list), `SAFETY`, `PROHIBITED_CONTENT`, `BLOCKLIST`, `SPII` or `RECITATION`.
    - **`InvalidResponseError`** (garment `failed`, "Retry image"): a text-only answer without a safety indicator (Google documents that a refused prompt usually comes back as text with `STOP`), `NO_IMAGE`, `IMAGE_OTHER`, missing or invalid image data, or malformed `candidates`/`content`.
    - **HTTP errors** use the shared mapping from `3394bec`.
  - **Image validation** (garment path only; `generate_image_multimodal` does not use it). Before a Gemini garment image counts as a success, `validated_garment_image`:
    1. detects the type from the bytes with `Media::ImageNormalizer.sniff!`, accepting PNG, JPEG or WebP only; the declared `mimeType` is not trusted, and the detected type is what is returned;
    2. decodes every pixel with libvips (`fail_on: :error`, then `avg`), which rejects truncated files and corrupt PNG data;
    3. rejects images over 50 million pixels.

    Any failure is an `InvalidResponseError` inside the attempt: one `error` row, no `ok` row, 0¢, `images_out 0`. The jobs then fail the garment ("Retry image") or leave the draft committable with the placeholder.
    - The image is not resized here; the jobs still normalize it to 512×512.
    - **Limitation:** corruption inside JPEG or WebP image data has no checksum and can decode to wrong pixels without an error. It is not detectable short of looking at the image.
  - **Quotas and logging, unchanged:**
    - the kill switch and the daily image cap (`check_quotas!(kind, user, 0, 1)`), and the global budget;
    - one `ai_calls` row per attempt: success is `ok` with `images_out 1` and the `garment_image` estimate; failures are non-billable;
    - no HTTP-level retries.
  - **Shared decoder:** `generate_image_multimodal` (Phase 4's outfit preview) now uses the same decoder. It behaves the same, except that malformed or invalid base64 image data now raises `InvalidResponseError` instead of decoding loosely.
  - **Specs:**
    - `spec/services/ai/client/vertex_gemini_image_spec.rb` (45 examples): request shape, model selection and Imagen compatibility, PNG, JPEG and WebP decoding, image validation (non-images, GIF, SVG, truncated and corrupt data, the pixel bound), mixed text and image, safety, text-only and malformed responses, HTTP errors, quotas, logging, leak checks.
    - `spec/jobs/gemini_garment_image_jobs_spec.rb` (7 examples): both image jobs end with a 512×512 JPEG or the existing fallbacks; an undecodable image gives one error row and no success row.
    - The existing Imagen examples in `vertex_spec.rb` and `vertex_error_handling_spec.rb` pin `GARMENT_IMAGE_MODEL` to Imagen and still pass.
    - Against the previous adapter, 36 of the first 40 examples fail. The 4 that pass check behaviour that did not change: the kill switch, the budget, the Imagen request, and avatars on `IMAGEN_MODEL`.
    - With the image validation removed, 11 of the 52 fail. With the byte check kept but no full decode, the truncated-halfway and corrupt PNG cases and the job-level case still fail, so the full decode is what catches them.

- **Vertex error handling** (`app/services/ai/client/vertex.rb`; [DEVIATION] 3.6/3.7 in section 5; approved 2026-10-22). Request payloads, URLs, headers, model IDs, regions, authentication and the parsing of successful responses are unchanged; that was checked with a diff.
  - **HTTP mapping**, from the status and Google's structured fields only (`error.message` is never read):

    | Response | Raised |
    |---|---|
    | 400 | `InvalidRequestError`; `ContentBlockedError` only when a `google.rpc.ErrorInfo` detail's `reason` (an enum value) names a safety reason |
    | 401, 403 | `AuthenticationError` |
    | 404 | `NotFoundError` |
    | 408, 5xx, timeouts and connection failures | `TransientError` |
    | 429 | `RateLimitedError`, a `TransientError` |
    | Any other 4xx | `InvalidRequestError` |
    | A 2xx body that is not a JSON object | `InvalidResponseError` |

  - **Safety blocks** (`ContentBlockedError`, logged as `blocked`) are recognized only from:
    - Gemini `promptFeedback.blockReason`;
    - a Gemini `finishReason` of `SAFETY`, `PROHIBITED_CONTENT`, `BLOCKLIST`, `SPII`, `IMAGE_SAFETY` or `RECITATION` with no output;
    - Imagen `raiFilteredReason`;
    - the structured 400 above.

    Without one of these, empty or unparseable output is an `InvalidResponseError`: Gemini JSON cut off at `MAX_TOKENS`, empty Imagen predictions, or no image from the multimodal model.
  - **Messages and logs** carry only validated values:
    - the exception message: `"Vertex HTTP 403 PERMISSION_DENIED"`, or `"Vertex request failed (Faraday::TimeoutError)"`;
    - `Ai::Error#http_status` and `#google_status` (canonical `google.rpc.Code` names only);
    - one `Rails.logger.warn` line per failure, with the kind, model, HTTP status, Google status, error class and latency.

    They never include prompts, images, tokens, credentials, request bodies or response bodies.
  - **`ai_calls`:** every HTTP attempt that gets a response or fails on the network writes exactly one row. A failure records `status` `error` or `blocked`, its `error_class`, latency, kind, model and user, with `images_in = images_out = 0` and `est_cost_cents = 0` (`Ai::CallLogger.log(billable: false)`), so failed attempts do not use up the per-user image or vision caps or the budget.
    - **Zero estimated cost does not mean the provider charged nothing**; Google Cloud Billing is the authoritative source.
    - Our own quota and kill-switch refusals, and credential failures before the request, make no request and write no row, as before.
  - **Retries:** the Faraday retry middleware is removed. It never ran, because faraday-retry only retries idempotent methods and every Vertex call is a `POST`. The jobs' `retry_on Ai::TransientError, attempts: 3` (429 included) is the only retry, so each job attempt sends exactly one request.
  - **Timeouts:** a 10-second `open_timeout` is added; the 120-second request timeout is kept.
  - **What jobs now do** (job code unchanged):
    - `AuthenticationError`, `NotFoundError`, `InvalidRequestError` and `InvalidResponseError` reach each job's catch-all, so the garment is `failed` (with "Retry image") or the intake batch is `failed`, and the error is re-raised, instead of a silent placeholder;
    - genuine blocks still keep the placeholder.
  - **Specs:** `spec/services/ai/client/vertex_spec.rb` (every category, safety, malformed responses, successes, failure logging, leak checks, a single request per attempt), `spec/jobs/vertex_error_handling_spec.rb` (the job policies with the real adapter and stubbed HTTP) and `spec/services/ai/call_logger_spec.rb`. Against the original adapter, 47 of the 61 Vertex and job examples fail. The 14 that pass cover behaviour that was already right: successes, quota and credential refusals, 429 as transient, the placeholder for a genuine block, and the 5xx job retry.

- **ADC support in `Ai::GoogleToken`** (`app/services/ai/google_token.rb`; [DEVIATION] 3.4 in section 5; approved 2026-10-22).
  - **Deployment:** with `GOOGLE_SERVICE_ACCOUNT_JSON` set and nonblank, it builds the same `ServiceAccountCredentials` with the same `cloud-platform` scope, and caches the token the same way.
  - **Local:** with the variable absent or blank (empty or whitespace), it falls back to Application Default Credentials.
  - **Errors:** a failure raises the new `Ai::GoogleToken::CredentialsError` in three cases: an invalid key, no ADC found, or a refused token request such as an expired `gcloud` login. The message names only the credential source and the error class; it never contains the token, the key or the original message (a JSON parse error can quote the key), and the original exception is not attached. Nothing is printed or logged.
  - **`GoogleToken.source`** reports "service account" or "application default credentials" for diagnostics.
  - **Error-type change:** previously a missing or invalid key raised the raw parse error. Jobs still treat the new error as a failure.
  - **Tests:** `spec/services/ai/google_token_spec.rb` grew from 1 to 17 examples, all with mocked credentials or a locally generated key and no network. The service-account examples pass on the original code, except the one for the new `source` method.

- `config/brakeman.ignore`: one entry, the Rails 8.0 pending-EOL warning (fingerprint `98b26f60…22db42`). Every other check stays on. **Rails must be upgraded before 2026-11-07**: on that date the warning changes code and fingerprint, and CI fails again until Rails is upgraded.
- Cucumber always uses the fake AI adapter (`features/support/ai_fake.rb`), and `ENV` is restored after each scenario (`features/support/env_sandbox.rb`).
- `spec/examples.txt` is untracked and in `.gitignore`.
- The garment factory moved to `spec/factories/garments.rb`. Its default `image_status` is now `placeholder`, since no image is attached.
- Phase 2 cases were added to `spec/requests/authorization_spec.rb`.
- New test support:
  - `FakeDns`, so tests make no DNS lookups;
  - a cache emptied per test;
  - `features/support/browser_network.rb`, so browsers may load only the test server.
- `config/initializers/content_security_policy.rb`, `config/initializers/rack_attack.rb`, `config/routes.rb` and `config/initializers/filter_parameter_logging.rb` changed for the reasons in section 9.

## 8. Known issues: remaining Phase 1 issues for Dev 1

None of these blocks Phase 2. All are to be filed as `phase-1` issues.

| Issue | Severity | Workaround |
|---|---|---|
| Rails 8.0 reaches end of life on 2026-11-07, and CI's Brakeman step will fail from that date | High (date-bound) | Upgrade Rails to 8.1 before 2026-11-07 |
| The 9.4 Phase 1 seed (a demo user "with a filled-in profile and measurements") is missing. The seed creates the user only, so the Phase 3 engine sees an empty profile | Medium (affects the Phase 3 demo) | Add profile and measurements to the Phase 1 seed |
| `:user_profile` factory always fails: the user's `after_create` already creates a profile, and the factory saves a second one (unique index) | Low | The Phase 2 `FactoryBot.lint` is scoped to Phase 2 factories |
| `shared/_pill_group`'s magic comment is not strict-locals syntax (no parentheses), so its defaults are never applied | Low | Callers pass `selected:` and `multiple:` explicitly |
| `ApplicationJob` has no default queue or retry/discard policy | Low | Each Phase 2 job declares its own |
| `AVATAR_IMAGEN_MODEL` is not read; avatars use `IMAGEN_MODEL` | Low (Phase 4) | None needed yet |
| `APP_HOST` is not read; the mailer host is hard-coded to `example.com` | Low | None in Phase 2 (no mail) |

## 9. Security and reliability decisions

**Authorization**
- Every Phase 2 member route looks records up through `current_user`, so another user's garment, batch, draft or receipt gives 404 and changes nothing.
- Jobs act only on the records their ids name, and take the user from them.
- Uploaded source photos and receipts are never linked from any page. Photos are purged once the batch is ready or failed.

**Action Cable**
- `ApplicationCable::Connection` requires the Warden session's user.
- `UserStreamAuthorization` (prepended to `Turbo::StreamsChannel` by `config/initializers/turbo_stream_authorization.rb`) accepts a subscription only when the stream's first part is that user.
- Before this, a signed stream name copied from a page worked without signing in and after sign-out.
- **Phases 3 and 4 must keep their streams user-first** (`[user, :planner]`, `[user, :avatar]`), as 2.4 specifies.

**Uploads**
- Every upload is checked before anything is stored: missing, empty, over the size limit (15 MB for photos, 10 MB for receipts), or a type not allowed by content sniffing (first 64 KB). Names and Content-Type are ignored.
- Pixel count is checked from the header (50 MP) before decoding. Images are auto-rotated by EXIF, limited to 1600 px (2400 px for receipts), and converted to sRGB JPEG.
- The upload is never held whole in Ruby memory: Rack streams it to a temp file, Active Storage streams it, and the job reads from disk.
- `POST /rails/active_storage/direct_uploads` answers 404. It was unauthenticated and handed out signed bucket URLs, and the app never uses direct uploads.

**SSRF**

`Media::SafeFetcher` checks every hop: the first URL and each of at most 3 redirects. Each hop must:
- use http or https on the default port;
- carry no credentials in the URL;
- have a host outside `BLOCKED_HOSTS`.

Beyond those checks:
- `ssrf_filter` refuses private, loopback, link-local, shared and metadata addresses, and connects to the vetted IP, so DNS rebinding is not possible.
- Only a 2xx response counts.
- The body is streamed under the byte limit, with an overall deadline.
- Error messages never contain the URL.

**Search**
- Search preview thumbnails are rendered only from the hosts in `config.x.search_thumbnail_hosts`, over https and with `referrerpolicy="no-referrer"`. The CSP allows exactly those hosts.
- Result links that carry `api_key` or our key are dropped.

**PDF**
- PDFs are parsed in the request, under four bounds:
  - a 10 MB file, checked before reading;
  - the first 20 pages;
  - at most 50,000 characters;
  - a 5-second timeout.
- A 20 MB inflation budget is checked chunk by chunk before pdf-reader inflates a page's content, so a compression bomb is refused early.

**Rate limits (Rack::Attack)**
- Garment search: 10 per minute and 60 per hour per user.
- Adding a search result: 30 per minute per user.
- AI posts (photo intake, receipts, avatar, outfit previews): 10 per minute and 60 per hour per user.

**Logs:** `receipt_text` is in `filter_parameters`.

**Reliability**
- **Jobs are queued only after commit.** That includes a caller's outer transaction, so a rollback queues nothing.
- **Upload batches are created in a fixed order:** save the batch, attach the file (stored when `attach` returns), queue the job. If attaching or queueing fails, the stored file is purged and the batch removed, so no `processing` batch is ever left without a file or job.
- **No duplicate AI calls or overwrites:**
  - Every image and intake job uses `limits_concurrency`, one run per record.
  - Attaches happen under a row lock and are skipped when a ready image exists.
  - `retry_image` claims the garment with one compare-and-set `UPDATE`.
  - A draft committed while its image was generating hands the image to its garment, so one AI call serves both. A `GenerateGarmentImageJob` queued 10 minutes later is the safety net.
- **Idempotent intake:**
  - `ExtractGarmentsJob` writes the drafts and the `ready` status in one transaction under the batch lock, and skips a finished batch, so a re-run after a worker crash adds nothing.
  - Committing twice adds nothing ("No new items to add.").
  - The failure handler reloads the batch, so rolled-back drafts are never re-inserted.
- **Stale cleanup:** `PurgeStaleDraftsJob` removes batches idle for more than 24 hours (by `updated_at`, which the jobs touch), each under the batch lock. Re-runs are harmless.
- **Retries:**
  - `Ai::TransientError` gets 3 attempts, then the garment is `failed`.
  - Remote imports retry `Media::TransientFetchError` (timeouts, network errors, 408, 429, 5xx) 3 times, then keep the placeholder.
  - Disabled, over-quota and blocked calls go straight to the placeholder, with no retry.

## 10. Schema changes after Phase 1

- `db/migrate/20261021230001_add_default_to_garment_drafts_attrs.rb` (G6): `garment_drafts.attrs` gets the `{}` default from 5.3. `null: false` is unchanged. Reversible. `db/schema.rb` changes only the version and that column.

No other migrations. Draft-to-garment links are stored in `garment_drafts.attrs["garment_id"]`, and draft confidence in `attrs["confidence"]`, with no new columns.

## 11. Config vars and flags

No new config vars were introduced. Phase 2 reads these, all already listed in 9.3 and `.env.example`:

| Var | Required | Default | Used by |
|---|---|---|---|
| `SERPAPI_KEY` | **yes, for search** | none | `Wardrobe::Search::ImageSearch`. Without it, search answers "Garment search is not configured" (503). Free plan: 250 searches a month. |
| `VISION_MAX_GARMENT_IMAGES` | no | `6` (clamped to 1..20) | photo intake draft cap |
| `GARMENT_ASSET_SIZE` | no | `512` | garment and draft image normalization |
| `HEIC_SUPPORTED` | no | `true` | photo and receipt uploads. Set `false` if the Heroku HEIC check (9.2) fails |
| `AI_IMAGE_GEN_ENABLED`, `AI_DAILY_IMAGE_LIMIT`, `AI_DAILY_VISION_LIMIT`, `AI_DAILY_BUDGET_CENTS` | Phase 1 | Phase 1 | kill switch and quotas, honored by every Phase 2 AI job |
| `GCS_BUCKET`, `GOOGLE_*`, `VERTEX_*`, `IMAGEN_MODEL`, `AI_ADAPTER` | Phase 1 | Phase 1 | AI and storage |
| `GARMENT_IMAGE_MODEL` | no | `gemini-2.5-flash-image` | Phase 2 garment and draft product images (`kind: :garment_image`). `gemini-*` uses `generateContent`; `imagen-*` uses the Imagen `:predict` request. New in Phase 2 (section 5). |
| `GOOGLE_SERVICE_ACCOUNT_JSON` | yes for deployment (Vertex and GCS) | none | Vertex: when absent or blank, `Ai::GoogleToken` falls back to Application Default Credentials (local development, section 5). GCS still needs it. |
| `DEMO_PASSWORD` | yes, to create the demo account in production | none in production (the account is skipped); `changeme` in development and test | `db/seeds/demo_user.rb`. Production rejects known passwords and anything under 12 characters |
| `IMAGE_GEN_SPACING_SEC` | no | `1.5` | **not used** (section 6) |
| `SEARCH_RERANK_ENABLED`, `RECEIPT_LLM_CLEANUP` | no | `false` | **not used**: stretch features not built (section 4) |

Flags (`config/features.yml`; `FEATURE_<NAME>` overrides them):

| Flag | Production state for Phase 2 |
|---|---|
| `photo_intake` | **on** (default `true`) |
| `receipts` | **on** (default `true`) |
| `onboarding`, `profile`, `avatar`, `outfit_preview` | off (Phase 4 forward slots, unchanged) |
| `calendar_sync` | on (Phase 3, unchanged) |

Phase 2 leaves no new forward slots (10.3) and changes no flag defaults.

## 12. Deployment instructions

These steps have **not been run yet**. They are the plan for the exit gate.

1. Open the Phase 2 PR (`phase-2` → `main`) and wait for CI to pass on the PR, then on `main` after merging.
2. Set the Heroku config:
   ```bash
   heroku config:set SERPAPI_KEY=<key>                # the only new required var
   heroku config:set DEMO_PASSWORD=<password>         # 12+ characters, not a known default; without it the seed skips the demo account
   heroku config:get HEIC_SUPPORTED                   # set to false if the 9.2 HEIC check failed
   ```
3. Deploy `main`. The release phase (`Procfile`: `release: bin/rails db:migrate`) runs the G6 migration. It is backward compatible: a column default only.
4. Seed the demo account and wardrobe: `heroku run bin/rails db:seed`. It can be re-run safely and never prints the password. Check that the output says `Demo user: demo@misfit.ai (password from DEMO_PASSWORD)`, not `Demo user skipped`.
5. Check that the recurring purge is loaded: `config/recurring.yml` declares `purge_stale_drafts` (daily at 4am) for the Solid Queue scheduler. It needs the worker that runs Solid Queue (`SOLID_QUEUE_IN_PUMA` or a worker dyno, as set up in Phase 1).
6. Smoke and spend checks: `heroku run bin/rails runner bin/ai_smoke`, `/admin/ai_usage`, and GCP Billing Reports. Record the results in sections 18 and 19.
7. By hand at 390 px wide, run each intake path once with real AI: manual add with an image, search and add, photo intake, receipt (text, PDF and photo). Watch `heroku logs` for R14 (memory) during the photo and receipt jobs.
8. Merge this note and push the tag `phase-2-complete`.

Rollback: `heroku rollback vNN`. The migration needs no rollback, because the old code ignores the default. To stop image costs immediately: `heroku config:set AI_IMAGE_GEN_ENABLED=false`. To switch off one intake path: `FEATURE_PHOTO_INTAKE=false` or `FEATURE_RECEIPTS=false`.

## 13. Known limitations and residual risks

**Accepted risks**
- Active Storage blob and representation URLs are signed but never expire, so anyone holding a garment or draft image link can open it. The redirect goes to a 1-hour signed storage URL. These are product images; source photos and receipts are never linked.
- Quota checks read today's `ai_calls` before calling, so parallel jobs for one user can go slightly over a cap.
- A pasted receipt's text stays in `extracted_text_preview` (600 characters) and in its drafts until the batch is purged, 24 hours after the last activity. Only its owner can see it.

**Concurrency**
- `limits_concurrency` works only with Solid Queue (development and production). The test adapter ignores it, so the specs exercise the row-lock guard instead.
- If one image run lasts longer than the 10-minute concurrency window, a second run may make a second AI call. Its image is then discarded by the overwrite guard, so the cost is one extra call, never a replaced image.
- The double-click retry spec runs its requests one after another. Protection against truly simultaneous requests rests on the single compare-and-set `UPDATE`.

**PDF**
- The inflation budget covers page content streams and form XObjects. Fonts and ToUnicode maps are decoded without a pre-check; they are bounded by the 10 MB file limit and the 5-second timeout.
- `Timeout` interrupts the request thread at an arbitrary point. That is acceptable because pdf-reader holds no locks or connections, but the block must stay free of database work.
- A PDF can hold one Puma thread for up to about 5 seconds. Rack::Attack limits receipt uploads per user.

**Gemini garment images**
- **Cost estimate:** `config/ai_pricing.yml` now has `garment_image: 4.0` (approved 2026-10-22; it was 2.0).
  - **Basis:** Google's published price for `gemini-2.5-flash-image` is $30 per million image-output tokens, at 1,290 tokens per image up to 1024×1024, so $0.039 per image (Google Developers Blog, October 2, 2025, and the Gemini API pricing page). The Vertex model page confirms the 1,290 tokens. The Vertex AI pricing table itself could not be read. 4.0¢ rounds 3.87¢ up to cover the prompt's input tokens and any text parts.
  - **It is an internal estimate.** Google Cloud Billing is authoritative.
  - **Rejected or malformed responses** (safety blocks, text-only answers, invalid image data) are recorded at 0¢ but may still be charged by the provider.
  - **The global budget uses this estimate.** With `AI_DAILY_BUDGET_CENTS=1000`, image generation alone stops at about 250 images a day across the app (500 at the old 2.0), sharing the budget with photo and receipt analysis. The 40-image daily cap allows up to 160¢ per user per day. A photo intake's up to 6 draft images are about 24¢.
  - The cost of `garment_image` does not depend on the model, so an Imagen model, if configured, would also be estimated at 4.0¢ (an overestimate).
- **Model shutdown dates differ by platform:** the Gemini Developer API pricing page says `gemini-2.5-flash-image` "will be shut down on October 2, 2026" on that API. The Vertex model page gives a retirement date of March 15, 2027, and the Vertex model metadata shows it as GA. We call Vertex. The first real request (check 5) will show whether it is still served; a 404 would mean moving `GARMENT_IMAGE_MODEL` to a newer model, a configuration change.
- **Model lifetime:** `gemini-2.5-flash-image` is scheduled to retire on March 15, 2027 (model page). Plan a move to a newer Gemini image model before then; `GARMENT_IMAGE_MODEL` makes that a configuration change, as long as the request shape stays compatible.
- **Text-only refusals:** a prompt the model refuses usually returns text with `finishReason: STOP` and no structured safety signal, so the garment ends `failed` with "Retry image", not with the placeholder.
- **Not tested against the real API yet:** check 5 stays BLOCKED. The output size (expected 1024×1024 for 1:1) and the MIME type are unverified, and the forum reports of false `IMAGE_SAFETY` blocks on harmless clothing are unconfirmed for our prompts.
- **Kill switch:** `AI_IMAGE_GEN_ENABLED=false` (inspected, not changed):
  - image jobs raise `Ai::DisabledError` before any request and write no row;
  - `GenerateGarmentImageJob` sets the garment to `placeholder`;
  - `GenerateDraftImageJob` leaves the draft `ready` with "Product image unavailable" and committable;
  - a draft committed while its image was pending leaves a `pending` garment until the 10-minute safety-net `GenerateGarmentImageJob` runs, which then sets `placeholder`.

  Garments are therefore never stuck in `pending`, as long as a Solid Queue worker runs.
- **Kill-switch gap in a Phase 4 path (Phase 1 code, not fixed):** `Ai::Client::Vertex#generate_image_multimodal` (the outfit preview, `kind: :outfit_preview_gemini`) does not call `check_disabled!`, although `Ai::Client::Fake#generate_image_multimodal` does. `AI_IMAGE_GEN_ENABLED=false` therefore would not stop real outfit-preview images, and tests on the fake adapter would not show it. The garment image path checks it. To fix before Phase 4 relies on the preview.
- **Minor:** for `generate_image_multimodal`, `post_gemini` records `output_chars` as the JSON size of the returned `Ai::Image`, image bytes included, so the value has no meaning there (checked locally: it does not raise). The garment image path does not use `post_gemini`.

**Vertex error handling**
- `ai_calls.est_cost_cents` is our estimate, and failed attempts are recorded as 0. The provider may still charge for some of them (for example a blocked Gemini prompt's input tokens). Use GCP Billing for real spend.
- The safety reasons Vertex puts in a 400's `ErrorInfo` are not documented for every model. `SAFETY_REASON` matches enum values that contain `SAFETY`, `RAI`, `RESPONSIBLE_AI`, `PROHIBITED_CONTENT` or `BLOCKLIST`; confirm it against the first real Imagen block. Until then, an unrecognized safety 400 is an `InvalidRequestError`: a visible failure with "Retry image", which is the safe direction.
- The configured model IDs (`gemini-2.5-flash` for `VERTEX_VISION_MODEL` and `VERTEX_TEXT_MODEL`, `imagen-4.0-fast-generate-001` for `IMAGEN_MODEL`) have not been checked against Vertex AI in `us-central1`. Models are retired on Google's schedule; check them in the Model Garden before the first real calls. A retired or unavailable model now fails as `Ai::NotFoundError` (HTTP 404), not as a safety block.
- The Imagen request does not ask for `includeRaiReason` (request payloads were not changed), so an Imagen-filtered image may come back as empty predictions. That is now an `InvalidResponseError` (garment `failed`, "Retry image"), not a placeholder, and retrying will likely be filtered again. Adding `includeRaiReason: true` is a payload change for a later step.
- The `rescue_from(StandardError)` catch-all in the image jobs re-raises configuration errors. In production, Solid Queue records them as failed jobs, which is intended so they are noticed.

**Google credentials**
- `Ai::GoogleToken` caches one token without recording which credential source issued it. If `GOOGLE_SERVICE_ACCOUNT_JSON` or the ADC login changes while a process is running, the old token stays in use until it nears expiry (refreshed 60 seconds early; tokens last about an hour), until `Ai::GoogleToken.reset!`, or until a restart. Restart `bin/dev` or the console after changing credentials. Production is not affected, because config var changes restart the dynos.
- With user ADC, `GoogleToken` sends only the bearer token, not the `x-goog-user-project` header. If Vertex answers 403 asking for a quota project, run `gcloud auth application-default set-quota-project <project>`; if that is not enough, the header has to be sent, which is a code change.
- Under ADC the account needs `roles/aiplatform.user` (or Owner or Editor) and the Vertex AI API enabled. When no credentials exist at all, googleauth probes the metadata server before failing, so the error can take a few seconds.

**Unverified in production**
- Real Gemini output against the Phase 2 schemas (including `confidence`), Imagen output, GCS blob handling, HEIC support on Heroku and dyno memory under real photos have not been tested (section 14).

**Demo**
- The demo images are silhouettes, not photos (section 5).

## 14. Integration tests that need real credentials

Checks 1, 2, 3 and 4 have been run, locally, and passed; check 5 was run once and is blocked (details below). The rest are still open; no result has been recorded or assumed for them. These are local runs against the real services, not production checks: Phase 2 is not deployed to Heroku.

| # | Check | Needs | Status |
|---|---|---|---|
| 1 | SerpAPI search: response shape matches `spec/fixtures/serpapi/*`, page-2 backfill, quota use, and the thumbnail hosts are covered by the CSP | `SERPAPI_KEY` | **Passed locally** (2026-10-21, one request); page-2 backfill not triggered |
| 2 | `ImportRemoteImageJob` fetching real third-party image hosts through `Media::SafeFetcher` (redirects, content types, sizes) | network | **Passed locally** (2026-10-21, one download); Active Storage on local disk, so GCS is untested (check 6) |
| 3 | Vertex `garment_extraction` with the 6.6 schema plus `confidence`, on real outfit photos, including HEIC from a phone | Vertex credentials | **Passed locally** (2026-10-22, one real product photo, local ADC); HEIC from a phone and further photos not yet tested |
| 4 | Vertex `receipt_extraction` with the 6.12 schema on receipt photos and screenshots; real retailer PDF receipts through `pdf-reader` | Vertex credentials, sample receipts | **Passed locally** (2026-10-22, one synthetic receipt image, local ADC); real receipt photos and retailer PDFs not yet tested |
| 5 | Imagen `garment_image` for garments and drafts, including the content-blocked fallback | Vertex credentials | **BLOCKED** — configured Imagen model unavailable (HTTP 404) (2026-10-22) |
| 6 | GCS uploads, variants and blob hand-over on draft commit | `GCS_BUCKET`, a service account with `storage.objectAdmin` | Not run |
| 7 | Second GCP billing check (3.4 step 6) | GCP console | Not run |
| 8 | Heroku: all four intake paths at 390 px with real AI, and no R14 memory errors | Heroku app plus 1 to 7 | Not run |

### Check 1: SerpAPI search (local, 2026-10-21)

- **Path tested:** the public `Wardrobe::Search::ImageSearch.call(query: "Nike white t-shirt", color: "White", kind: "T-shirt", limit: 8)`, from `bin/rails runner`.
  - The AI adapter was `fake`.
  - The result cache was replaced with a null store for that process only, so the request was real.
  - Instrumentation was in-process and changed no code. It counted the requests, recorded each status, and would have refused a third request.
- **Requests:** 1 SerpAPI request (up to 2 were approved). The page-2 backfill was not needed.
- **Response:** HTTP 200 in about 6.3 seconds, with `search_metadata.status` "Success" and no `error`.
- **Results:** 99 raw `images_results`. All 99 passed URL screening (http(s) only, no `data:`, no `api_key`) and dedupe. FilterAndRank kept 8, and 8 were returned.
- **Structure:**
  - Every result has exactly `image_url`, `thumbnail_url`, `title` and `source_url`.
  - `image_url`: 8 of 8 are https with a host and no credentials.
  - `thumbnail_url`: 8 of 8 are https on `encrypted-tbn0.gstatic.com`, which is in `config.x.search_thumbnail_hosts`, so the CSP allows them.
  - `source_url`: 8 of 8 are valid retailer pages.
  - The response shape matches the fixtures' assumptions.
- **Errors and leaks:**
  - No `Wardrobe::Search::Error`, no parsing errors, no exceptions.
  - The key did not appear in any result or in any printed output: no request URLs, params or raw bodies were printed.
- **Observations, not changed (for later decision):**
  - The 6.3-second response is close to the 8-second `READ_TIMEOUT`.
  - SerpAPI ignored `num=8` and returned 99, so the backfill will rarely run.
  - The top result was a long-sleeve top for kind "T-shirt".
  - Results 6 to 8 share one title and retailer page, with different image URLs (dedupe is by image URL).
- **Not covered by this run:** real image import. That was tested separately as check 2, below.

### Check 2: real image import (local, 2026-10-21)

- **Path tested:** the app's own pipeline, `Wardrobe::Search::AddResult.call` -> `Wardrobe::ImportRemoteImageJob` -> `Media::SafeFetcher` -> `Media::ImageNormalizer` -> Active Storage, from `bin/rails runner`.
  - `AI_ADAPTER=fake`, with a null cache store.
  - Active Job used the `:test` adapter in that process only. The one queued `ImportRemoteImageJob` was captured and run exactly once with `ActiveJob::Base.execute`, and any retry would have been recorded, never run.
  - Instrumentation was in-process and changed no code. It capped the run at 1 SerpAPI request and 1 image fetch, and counted TCP connections, request hops and DNS answers.
- **Search:** 1 SerpAPI request (the same query as check 1), HTTP 200, 99 raw results, 8 returned. The picked result was rank 1, from `media.jdsports.com`.
- **Download:**
  - 1 real image download from `media.jdsports.com`, over https;
  - 1 request hop, 0 redirects, 1 TCP connection;
  - the host resolved to a public address only (`23.207.14.179`);
  - 0 retries queued or run.
- **Original image:** JPEG (detected from the bytes), 2000×2000, 219,875 bytes, within the 10 MB limit.
- **Processed image:**
  - JPEG, 512×512, 57,822 bytes, attached to the garment, with its file stored;
  - the `thumb` (256×256) and `card` (512×512) variants processed successfully.
- **Garment:** created `pending` (source `search`, category `top`) and moved to `ready` once the image was attached.
- **SSRF and validation checks** (offline, before the download; 0 TCP connections opened). Each was refused with `UnsafeUrlError`:
  - `127.0.0.1`, `10.0.0.1` and `169.254.169.254`, refused as private addresses before any connection;
  - `metadata.google.internal`, refused as a blocked host before any DNS lookup;
  - a non-default port and credentials in the URL, refused before DNS;
  - a `file://` URL.

  Non-image bytes were refused with `InvalidImageError`.
- **Result:** all 27 checks passed.
- **Cleanup:** every temporary record and file was removed: the throwaway test user and its profile, 1 garment, 3 blobs, 3 attachments, 2 variant records and 3 files on disk. This was verified by each record's ID and each file's path, and the global counts matched the starting numbers. No existing user or garment was touched.
- **Storage:** Active Storage used the local Disk service (`storage/`). **GCS uploads and variants remain untested** (check 6).
- **Observation:** the imported image was the search's rank-1 result, the "Long-Sleeve Top" for kind "T-shirt" noted under check 1. This is the existing ranking-quality observation; the import itself behaved correctly.

### Check 3: real Gemini garment extraction (PASSED, local, 2026-10-22)

**Environment**
- Google Cloud project `misfitai-512403`; model `gemini-2.5-flash`; region `us-central1`.
- Authentication: local Application Default Credentials (`gcloud auth application-default login`, an `authorized_user` credential), through `Ai::GoogleToken`'s ADC fallback. `GOOGLE_SERVICE_ACCOUNT_JSON` was blank.
- Checked before the request:
  - the Vertex AI API (`aiplatform.googleapis.com`) is enabled on the project;
  - `publishers/google/models/gemini-2.5-flash` exists in `us-central1` with launch stage GA (a read-only metadata request, not a generation request).
- `AI_ADAPTER=vertex` and `GOOGLE_CLOUD_PROJECT=misfitai-512403` were set only in the environment of the one test process (`bin/rails runner`). `.env` is unchanged: `AI_ADAPTER=fake`, and `GOOGLE_CLOUD_PROJECT` is still blank there, so it has to be set to run Vertex locally.

**Test input**
- One real JD Sports product photograph: a white Nike Pro long-sleeve crop top and black Nike Pro shorts. It is the same image as check 2: `media.jdsports.com`, JPEG, 2000×2000, 219,875 bytes.
- Downloaded once through `Media::SafeFetcher`, checked with `Media::ImageNormalizer.sniff!`, and deleted from the scratchpad after the test.

**Path tested:** the app's own code, with no separate implementation:
1. `Wardrobe::PhotoIntake::ImagePreparer`;
2. `Ai::Client.current` (`Ai::Client::Vertex`) `generate_json(kind: :garment_extraction)`, with the real `PhotoIntake::Prompts::EXTRACTION` and `GARMENT_SCHEMA`;
3. `PhotoIntake::Mapper`.

There was no job and no retry. In-process instrumentation capped the run at one request, and nothing printed or stored contained the token, the request body or the image data.

**Results**
- Exactly one Gemini generation request.
- HTTP 200, latency 2,608 ms (`ai_calls.latency_ms`; 2,677 ms including fetching the token), `finishReason: STOP`.
- Token usage: 2,959 prompt and 169 output tokens.
- The response passed the existing JSON schema: every required field present, every enum value valid, no fields outside the schema. The optional `confidence` field was filled in.
- `PhotoIntake::Mapper` produced two drafts, and both garments were classified correctly:

  | Name | Category / sub_category | Colour | Brand | Material | Fit | Formality / season | Confidence | Needs confirmation |
  |---|---|---|---|---|---|---|---|---|
  | Long Sleeve Crop Top | top / `crop_top` | white | Nike | synthetic | athletic | casual / all_season | 0.9 | no |
  | Athletic Shorts | bottom / `shorts` | black | Nike | synthetic | athletic | casual / all_season | 0.9 | no |

  Gemini answered `pattern: "solid"`, which the mapper stores as no pattern, as designed.
- No wardrobe records were created: no garments, drafts, intake batches or users.

**Usage**
- One `ai_calls` row is kept: `garment_extraction`, `gemini-2.5-flash`, `status ok`, `images_in 1`, `images_out 0`, `est_cost_cents 0.5`, no user.
- 0.5¢ is our internal estimate (`config/ai_pricing.yml`), not the actual Google Cloud charge; GCP Billing is authoritative. From the token counts, the list price is likely well below the estimate.

**Additional observations** (no code changed)
- **SerpAPI timeout:** the approved SerpAPI search, meant to find a multi-garment image, timed out after 8 seconds (`Net::ReadTimeout` -> `Wardrobe::Search::Error`, "request failed"). No retry was attempted, and the JD Sports image was used instead. The request may still have counted toward SerpAPI usage.
- **Follow-up: the 8-second SerpAPI read timeout may be too restrictive.** Check 1 took 6.3 seconds and this request passed 8. Revisit it as a separate change; it is recorded here, not changed.
- **`input_chars` for vision calls:** the field includes the base64 image (448,222 for this call), so it does not represent meaningful text input size. This is existing Phase 1 logging.
- **Prepared image size:** `ImagePreparer` turned the 220 KB JPEG into a 334 KB JPEG (1600×1600, quality 90). This is a possible optimization, not a functional defect.
- **Scope:** this test validates the Vertex extraction and mapping path, not the complete browser-based intake workflow (upload, `ExtractGarmentsJob`, drafts, review, commit).

**Next integration checks**
1. Gemini receipt extraction (check 4).
2. Imagen image generation (check 5).
3. Google Cloud Storage (check 6).

### Check 4: real Gemini receipt extraction (PASSED, local, 2026-10-22)

**Environment**
- Google Cloud project `misfitai-512403`; model `gemini-2.5-flash`; region `us-central1`.
- Authentication: local Application Default Credentials (`GOOGLE_SERVICE_ACCOUNT_JSON` blank).
- `AI_ADAPTER=vertex` and `GOOGLE_CLOUD_PROJECT=misfitai-512403` were set only in the environment of the one test process (`bin/rails runner`). `.env` is unchanged, with `AI_ADAPTER=fake`.

**Test input**
- A synthetic receipt rendered locally with libvips, from the fictional retailer SAMPLE OUTFITTERS: 1183×1621 JPEG, monospace print on off-white paper, rotated −2°, slight grain, on a neutral grey background.
- It lists five clothing and accessory products, plus a gift card, gift wrap, a member discount, subtotal, tax, total and a payment line (`VISA ************0000`, `AUTH: 000000`). The totals add up: $428.40 − $10.00 + $37.13 tax = $455.53.
- No personal information and no external image download. The image was deleted after the test.

**Execution**
- The app's own path: `Wardrobe::PhotoIntake::ImagePreparer` (`max_side: Receipts::ParseImageJob::MAX_SIDE`, 2400), then `Receipts::VisionParser.call`, with the real `Receipts::Prompts::VISION` and `RECEIPT_SCHEMA`.
- There was no job and no retry. In-process instrumentation capped the run at one request and printed nothing that contained the token, the request body or the image data.
- Exactly one Gemini generation request: HTTP 200, about 3,127 ms (`ai_calls.latency_ms` 3,128), `finishReason: STOP`, 1,918 input and 285 output tokens.

**Extraction results**
- The raw response passed `RECEIPT_SCHEMA`.
- All five expected products were identified, and all 30 attribute checks passed (category, brand, size, colour and price for each).
- No product was missed. No non-clothing line was included: the gift card, gift wrap, discount, subtotal, tax, total and payment lines were all excluded.
- Gemini returned a confidence for every item, from 0.90 to 0.95, so `VisionParser.normalize` did not have to compute any. None is flagged "Please double-check".

| Product | Category | Brand | Size | Colour | Price | Confidence |
|---|---|---|---|---|---|---|
| Levi's 501 Original Jeans | bottom | Levi's | W32 L30 | Dark Wash | $69.50 | 0.95 |
| Uniqlo Merino Crew Neck Sweater | top | Uniqlo | M | Navy | $39.90 | 0.95 |
| Nike Air Force 1 '07 Sneakers | shoes | Nike | 10 | White | $115.00 | 0.95 |
| Patagonia Better Sweater Jacket | outerwear | Patagonia | L | Grey | $139.00 | 0.95 |
| Leather Belt | accessory | none | 34 | Brown | $35.00 | 0.90 |

**Draft validation**
- `Receipts::Intake.draft_attrs` gave the correct attributes for every item, with prices in cents (6950, 3990, 11500, 13900, 3500) and lowercased colours.
- `Receipts::Intake.finish` was run with a throwaway user and batch inside a database transaction that was always rolled back. Before running it, the code was checked for anything that could outlast a rollback: it only writes rows, with no jobs, broadcasts, attachments or external calls, and the models have no `after_commit` callbacks.
  - It created five drafts that were `ready`, selected and committable, and the batch reached `ready` at 100%.
  - No background jobs were queued (`solid_queue_jobs` stayed at 0).
  - After the rollback, none of the temporary records existed (checked by ID), and the counts of users, profiles, batches, drafts, garments and blobs were unchanged.

**Usage**
- One `ai_calls` row is kept: `kind receipt_extraction`, `status ok`, `images_in 1`, `est_cost_cents 0.5`, no user.
- 0.5¢ is our internal estimate; Google Cloud Billing is authoritative.

**Follow-up observations** (not reasons to mark the test failed)
- **Colour normalization:** Gemini reported the jeans' colour as "Dark Wash", stored as `color_primary: "dark wash"` rather than a standard colour such as "blue". Colour matching in later phases may not recognise it.
- **Size normalization:** Gemini kept "W32 L30", while the rule-based `TextParser` produces "W32L30", so the two receipt paths store sizes in different formats.
- **Synthetic receipt limits:** blur, glare, faded thermal print, crumpled paper and long receipts from real-world use remain untested.
- **`input_chars`** includes the base64 image data (362,876 for this call), as in check 3.
- **Not exercised:** the full browser flow (upload, `Receipts::ParseImageJob`, review, commit), and the job's deletion of the uploaded receipt after reading it.

**Next checks**
1. Check 5: real Imagen garment image generation.
2. Check 6: Google Cloud Storage integration.

### Check 5: real Imagen garment image generation (BLOCKED — configured Imagen model unavailable (HTTP 404), 2026-10-22)

**Environment**
- Project `misfitai-512403`, region `us-central1`, model `imagen-4.0-fast-generate-001` (the configured `IMAGEN_MODEL`).
- Local ADC.
- `AI_ADAPTER=vertex` and `GOOGLE_CLOUD_PROJECT` were set only in the environment of the one test process. `.env` is unchanged, with `AI_ADAPTER=fake`.

**The diagnostic request**
- Exactly one Imagen request, with no retries, no job and no wardrobe changes: `Ai::Client::Vertex#generate_image(kind: :garment_image, user: nil)` with the real `Wardrobe::Prompts.garment_image` prompt for an unsaved "Plain White T-Shirt" (`Garment.new`, never saved).
- `POST .../v1/projects/<project>/locations/us-central1/publishers/google/models/imagen-4.0-fast-generate-001:predict`.
- **HTTP 404 in 892 ms**, Google status `NOT_FOUND`, no structured error details.
- Google's message (read in the terminal for diagnosis only; the app does not read or log it) says the publisher model "was not found or your project does not have access to it" and asks to check the model name and its availability in the region.
- The adapter raised **`Ai::NotFoundError`** ("Vertex HTTP 404 NOT_FOUND", `http_status 404`, `google_status "NOT_FOUND"`), as the error mapping from `3394bec` intends. Before that change, this 404 would have been reported as a content block, and garments would have quietly kept their placeholder.
- **`ai_calls` failure logging was correct:** one row with `kind garment_image`, the model ID, `status error`, `error_class Ai::NotFoundError`, latency 894 ms, `input_chars 357`, `images_in 0`, `images_out 0`, `est_cost_cents 0`, no user. The row is kept.
- No image was produced. The garment, blob and queued-job counts were unchanged.

**Evidence that the model is unavailable to this project and configuration**
- **Credentials, permission and endpoint are not the problem.** The same ADC credentials, project, region and API version made successful `generateContent` calls to `gemini-2.5-flash` in checks 3 and 4, which need the same `aiplatform.endpoints.predict` permission. A credentials or permission failure would answer 401 or 403.
- **Read-only metadata requests** (`GET .../publishers/google/models/{model}`, preflight, no generation): `imagen-4.0-fast-generate-001`, `imagen-4.0-generate-001`, `imagen-4.0-ultra-generate-001`, `imagen-3.0-generate-002`, `imagen-3.0-fast-generate-001` and `imagen-3.0-capability-001` all returned 404 on `v1` and `v1beta1`. `gemini-2.5-flash-image` returned 200 (GA) from the same endpoint.
- **The publisher model catalog** listed for `us-central1` (130 models) contained no Imagen models. Its image-generation models were Gemini image models: `gemini-2.5-flash-image`, `gemini-3.1-flash-image` and `gemini-3-pro-image` (GA).
- **Google's release notes** (Vertex AI generative AI release notes, entry of March 24, 2026, "Imagen generation GA endpoints deprecation") list `imagen-4.0-fast-generate-001`, `imagen-4.0-generate-001`, `imagen-4.0-ultra-generate-001`, `imagen-3.0-generate-002` and `imagen-3.0-capability-001` as discontinued endpoints, with `gemini-2.5-flash-image` as the recommended migration. They advise "updating your model endpoints before June 30, 2026, to avoid service disruption". That is consistent with the 404 observed on 2026-10-22.
- **What this does and does not show:** this establishes unavailability for project `misfitai-512403` in `us-central1` with the current configuration. It does not establish that Imagen is withdrawn everywhere. Google's message also allows "your project does not have access", which only the console's Model Garden or Google Cloud support can rule out.

**Impact on Phase 2**
- While `IMAGEN_MODEL` points at this model, every product image fails with `Ai::NotFoundError`:
  - manual add's "Generate a product image";
  - `Wardrobe::StarterImport`;
  - product images after a receipt commit;
  - photo-intake draft images (`GenerateDraftImageJob`).
- Garments end `image_status: "failed"` with "Retry image" (retrying fails again). Drafts keep the placeholder and stay committable.
- Everything else in Phase 2 is unaffected: manual add without images, search and import, photo and receipt extraction.
- Until the image path is fixed, `AI_IMAGE_GEN_ENABLED=false` would make new garments keep their placeholder instead of failing. That is a configuration decision, not made here.

**Possible impact on Phase 4**
- The avatar (`AVATAR_IMAGEN_MODEL`, today read as `IMAGEN_MODEL`) and the outfit preview's subject strategy (`OUTFIT_SUBJECT_MODEL=imagen-3.0-capability-001`, `generate_image_with_subject`) also use Imagen models, and both IDs returned 404 in the metadata preflight.
- The preview's second strategy (`OUTFIT_GEMINI_IMAGE_MODEL=gemini-2.5-flash-image`, `generate_image_multimodal`) uses a model that is listed as GA.
- Phase 4 should plan for this before building on Imagen.

**Migration (2026-10-22):** garment images were moved to a Gemini image model (`GARMENT_IMAGE_MODEL`, default `gemini-2.5-flash-image`; section 5 [DEVIATION] and section 7). It is tested with stubbed HTTP only. **Check 5 stays BLOCKED** until one real request with the new implementation succeeds.

**Phase 4 implications** (not implemented)
- The avatar (`kind: :avatar_portrait`) still reads `IMAGEN_MODEL`, a discontinued Imagen model, and will get 404s until Phase 4 moves it to `GARMENT_IMAGE_MODEL`-style selection or its own Gemini model setting. `AVATAR_IMAGEN_MODEL` is still not read.
- The outfit preview's subject strategy (`generate_image_with_subject`, `OUTFIT_SUBJECT_MODEL=imagen-3.0-capability-001`) uses Imagen subject customization. That endpoint is on the discontinued list, and there is no Gemini equivalent with the same request shape. Phase 4 should use the Gemini strategy (`generate_image_multimodal`).
  - `gemini-2.5-flash-image` accepts at most 3 input images per prompt (model page), which may be too few for an avatar plus a full outfit. Newer Gemini image models accept more, at a higher cost.
  - Fix the missing kill-switch check in `Vertex#generate_image_multimodal` first (see "Gemini garment images" in section 13).

## 15. How to verify

```bash
bin/setup                                             # or bundle install && bin/rails db:prepare
bin/rails db:seed                                     # demo@misfit.ai with the 15-item wardrobe (safe to repeat)
AI_ADAPTER=fake COVERAGE=true bundle exec rspec
bundle exec cucumber                                  # @wip excluded by the default profile; fake AI is forced
AI_ADAPTER=fake bundle exec cucumber --no-profile --dry-run --strict --tags @wip features   # finds no @wip scenarios
bin/rubocop && bin/brakeman --no-pager -q -w2 && bundle exec bundler-audit check --update
bin/rails zeitwerk:check
```

By hand, with `bin/dev`:
1. Sign in as `demo@misfit.ai` and open `/wardrobe`. You should see 15 cards with images and working category pills.
2. Add a garment by hand with "Generate a product image" checked. The fake image should appear without a reload.
3. Hide and delete a garment.
4. Paste the receipt text from `spec/requests/wardrobe/receipts_spec.rb`, review it and choose "Add selected".
5. Upload `spec/fixtures/files/outfit.jpg` under Photo AI.

Search needs `SERPAPI_KEY`; without it, it shows "Garment search is not configured".

## 16. Local verification results (2026-10-21, fake AI, stubbed HTTP)

| Check | Result |
|---|---|
| RSpec | 618 examples, 0 failures. SimpleCov `app/services`: 95.09% (891 / 937 lines; minimum 85) |
| Cucumber | 74 scenarios (74 passed), 436 steps (436 passed), including the 8 `@javascript` (Cuprite) scenarios. The `@wip` dry run matches 0 scenarios |
| `@wip` scenarios | none (`grep -rn @wip features/` finds no tags) |
| RuboCop | 228 files inspected, no offenses |
| Brakeman (`-w2`) | No warnings (exit 0) |
| bundler-audit | No vulnerabilities found (advisory database updated before the check) |
| `bin/rails zeitwerk:check` | All is good |
| `bin/rails db:seed`, run twice on development | 15 garments, all carrying the `demo-seed:` marker, 15 attached images and 15 blobs after both runs. The password is not printed |
| Demo wardrobe at 1280 px (desktop) | 15 cards render with images; grid correct; `scrollWidth` 1280, so no horizontal overflow |
| Demo wardrobe at 390 px (mobile) | 15 cards render with images; grid correct; `scrollWidth` 390, so no horizontal overflow |

The screenshots were taken with Cuprite against the local test server. That is not a check on Heroku: exit-gate item 3 still needs a check by hand at 390 px on Heroku with real AI.

## 17. Exit gate (10.4)

| # | Item | Status | Evidence / what is missing |
|---|---|---|---|
| 1 | Every scenario and spec of Phases 1 and 2 passes in CI on `main`; none `@wip` | **BLOCKED** | Everything passes locally and no `@wip` scenarios remain (section 16). The PR is not open and nothing is merged, so there is no CI run on `main`. |
| 2 | Brakeman and bundler-audit report no new warnings; RuboCop clean; SimpleCov at 85% or above for `app/services` | **PASS** (locally) | Section 16. The only Brakeman suppression is the documented Rails EOL entry from Step 1. |
| 3 | `main` deployed to Heroku, `/up` green, features work there with real AI, checked by hand at 390 px | **BLOCKED** | No deploy, no credentials. Verified only locally with the fake adapter. |
| 4 | `bin/ai_smoke` passes on Heroku | **BLOCKED** | Not run (section 19). |
| 5 | AI spend checked in `/admin/ai_usage` and GCP Billing; both numbers in this note | **BLOCKED** | Not checked (section 18). |
| 6 | Every Phase 2 contract exists with its documented signature and RSpec coverage | **PASS** | Section 3. |
| 7 | Every forward slot this phase leaves is in place, with its flag in the default state | **PASS** | Phase 2 leaves no new slots; `photo_intake` and `receipts` are on by default and Phase 1's slots are unchanged (section 11). |
| 8 | `docs/handoff/phase-2.md` merged and tag `phase-2-complete` pushed | **BLOCKED** | Held back on purpose until review, the PR and items 1 and 3 to 5. |
| 11.2 | All four intake paths work on Heroku | **BLOCKED** | Needs items 3 and 14.8. |
| 11.2 | `filter_and_rank_spec` and `text_parser_spec` green | **PASS** | Part of the RSpec run. |
| 3.4 | Second GCP billing check at Phase 2 entry | **BLOCKED** | Needs GCP console access (section 14, item 7). |

**Phase 2 is not complete.** It is ready for final integration testing once credentials and the Heroku app are available.

## 18. AI spend

- `/admin/ai_usage` today: **not checked (BLOCKED)**: no production deploy.
- GCP billing to date: **not checked (BLOCKED)**.
- Credits applied: **unknown (BLOCKED)**.

Locally, every AI call went through the fake adapter, so no spend came from Phase 2 development.

## 19. bin/ai_smoke output

Not run: it needs Heroku and real Vertex credentials (BLOCKED). Paste the output here at the exit gate.

## 20. Questions for the next phase

- **Phase 3:**
  - Render garments with `garments/_thumb` (size the wrapping element).
  - Hide garments through `Wardrobe::SetHidden`.
  - Read wardrobes through `user.garments.visible`.
  - Keep streams user-first (`[user, :planner]`), or the cable authorization refuses the subscription.
- **Phase 3:** the demo user has no profile or measurements yet (section 8). The engine and the demo week seed need them.
- **Phase 4:**
  - `Wardrobe::StarterImport` saves all rows in one transaction and raises on the first invalid one, so validate onboarding rows before calling.
  - The deferred stretch items are in section 4.
- **Dev 1:** the Rails upgrade before 2026-11-07, and the other items in section 8.
- **Team:** SerpAPI's free plan is 250 searches a month, and Rack::Attack allows up to 60 per user per hour. Watch usage during the demo.

## Working agreements for Phase 2 tests

- `@javascript` scenarios wait on conditions (Capybara's waiting finders and matchers such as `have_content`, `have_css`, `have_no_css`), never fixed `sleep`s.
- Tests make no real network or DNS calls: WebMock, `FakeDns`, and a browser limited to the test server.
- The fake AI adapter is forced in Cucumber.
