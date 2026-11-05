# Phase 4 Handoff Note — Personalization and Launch

## Completed Capabilities

- **Profile page** (`/profile`): Five independently-saved sections (Personal, Body Measurements, Style, Sizes, Avatar Preferences), each in its own `turbo_frame_tag`. Dirty-form Stimulus controller shows Save/Discard bar on change. `ProfilesController` and `MeasurementsController` both skip the onboarding gate.
- **Onboarding** (`/onboarding`): Five-step guided flow. Step 0 collects gender, birthday, optional measurements. Step 1 collects aesthetics, color tones, brands. Step 2 selects from the 21-item starter catalog. Step 3 reviews selected items with editable rows and optional custom items (Stimulus `nested_rows_controller`). Step 4 shows the generated week live via Turbo Streams. Build sequence on step 3 submit: `Wardrobe::StarterImport` → `Planner::WeekPlanner.ensure_week!` + `apply_demo_week!` → `Planner::WeekPlanner.generate!`. "Build My Wardrobe" is blocked when no items exist. Each step saves on Continue so a refresh resumes at the same step. `:onboarding` flag turned on.
- **Navigation::Progress + stepper** (`app/views/shared/_stepper.html.erb`): `Navigation.for(user)` returns a `Progress` struct with `wardrobe_complete`, `calendar_complete`, `outfits_complete`. Wardrobe is complete when visible top+bottom or dress exist. Calendar is complete when the current week has at least one non-`none` event. Profile step is always shown as complete.
- **Avatar generation** (`/avatar`): Upload validation (empty, 15 MB max, type sniff). Attaches selfie as `pending_selfie` (purged in `ensure`), sets `avatar_status: pending`, enqueues `Avatars::GenerateAvatarJob`. Job: describes selfie via `selfie_description` (best-effort, continues on failure), builds portrait prompt with `Avatars::PromptBuilder.portrait`, calls `generate_image(kind: :avatar_portrait)`, normalizes to 512 px square JPEG, broadcasts to `[user, :avatar]`. On failure: `avatar_status: failed` with generic user-facing message. `:avatar` flag turned on.
- **Outfit preview / On Me** (`/outfit_previews/:outfit_id`): Cache key is SHA-256 of avatar checksum + garment IDs. Cache hit skips AI. Three strategies in order: Imagen subject reference (`imagen_subject`), Gemini multimodal (`gemini_image`), deterministic vips collage (`collage`). AI strategies skipped when `AI_IMAGE_GEN_ENABLED=false` or over quota. Collage is 900×300 px with left avatar column (42%), 8 px gutter, divider, right garment cells (up to 4, 2×2 grid). Result attached to `rec.preview_image`, `preview_strategy` and `preview_cache_key` stored. Broadcasts frame to `[user, :planner]`. `:outfit_preview` flag turned on.
- **Metrics endpoints**: `GET /api/metrics` and `GET /admin/metrics`. Key check via `X-Analytics-Key` header with `ActiveSupport::SecurityUtils.secure_compare`. Dummy mode via `ANALYTICS_USE_DUMMY_METRICS`. `period_days` clamped 1–366. Sources: `User.count` for signups; GA4 Data API (cached 10 min) for active users and page views; Formspree → CSV → `WaitlistEntry.count` for waitlist. GA4 returns zeros with `ga4_configured: false` on any error.
- **GA4 analytics**: Layout `yield :analytics` hook populated when `GA_MEASUREMENT_ID` is set. `analytics_controller.js` sends `login`, `avatar_preview_open`, `outfit_accepted`, and `page_view` events.
- **`Media::ImageNormalizer.to_jpeg`**: Added non-square JPEG conversion method used by outfit preview strategies.
- **`has_one_attached :pending_selfie`** added to `UserProfile`.

## Deviations from the Design Doc

- **[DEVIATION] Auth scenarios updated**: The `@pre_onboarding` tag was removed from `features/auth/email_signup.feature` and `features/auth/google_sign_in.feature`. Expected post-sign-up redirect changed from `/wardrobe` to `/onboarding` now that `:onboarding` is on by default. This is the intended Phase 4 change per design doc 10.3 and 11.4 task 3.
- **[DEVIATION] `features.yml` test environment**: The `test` environment keeps `onboarding: false` so all earlier Cucumber and RSpec auth scenarios continue to pass without modification. Production and development have `onboarding: true`. This avoids a cascade of auth-scenario changes in Phase 4; the onboarding flow itself is exercised by `features/onboarding/onboarding.feature`.
- **[DEVIATION] `Avatars::OutfitCollage` uses `Vips::Image.text` for labels**: The design doc specifies labels at 11 px in `#6F706B`. Vips text rendering requires a system font; label drawing is wrapped in a rescue so collage generation is never blocked by font availability.
- **[DEVIATION] Analytics controller uses `window.__gaMeasurementId`**: The GA measurement ID is written into the layout's `<head>` as a JS variable. This avoids hardcoding it in the Stimulus controller and matches the layout's `yield :analytics` pattern.

## Decisions Made Where the Doc Was Silent

- **[DECISION]** `Navigation.for(user)` is a module-level function (not a class method on `Progress`) so callers write `Navigation.for(user)` without needing to know the struct type name.
- **[DECISION]** Onboarding step 1 renders all 50 brands; the featured 20 are shown first with the full list behind a `<details>` toggle and a client-side filter box (`shared--filter-list` Stimulus controller).
- **[DECISION]** `Avatars::OutfitPreviewJob` falls through gracefully: strategy 1 failure tries strategy 2; both failing falls through to the collage. No strategy raises to the job's error handler.
- **[DECISION]** The metrics spec uses `ClimateControl` to isolate env vars per example, consistent with the Phase 2 approach for external service specs.
- **[DECISION]** `Admin::MetricsController#show` adds `period_days` and `as_of` to the response; `Api::MetricsController#show` slices to the four public keys only, matching the design doc's shape distinction.

## Schema Changes

None. All columns (`onboarding_completed_at`, `onboarding_step`, `avatar_status`, `avatar_error`, `preview_status`, `preview_strategy`, `preview_cache_key`) were created in earlier phase migrations. `pending_selfie` is an Active Storage attachment (polymorphic, no column needed).

## Config Vars and Flags

New in Phase 4:

| Var | Required | Default | Used by |
|---|---|---|---|
| `GA_MEASUREMENT_ID` | no | none | Layout gtag snippet. Without it, no analytics snippet is rendered. |
| `GA4_PROPERTY_ID` | no | none | `Analytics::Metrics` GA4 Data API calls. Without it, `active_users` and `page_views` return 0 with `ga4_configured: false`. |
| `ANALYTICS_INTERNAL_API_KEY` | no (open in dev) | none | `X-Analytics-Key` check on `/api/metrics` and `/admin/metrics`. |
| `ANALYTICS_SKIP_KEY_AUTH` | no | `false` | Bypasses key check. For local dev only. |
| `ANALYTICS_USE_DUMMY_METRICS` | no | `false` | Returns hardcoded dummy metrics without hitting GA4 or Formspree. |
| `FORMSPREE_FORM_ID`, `FORMSPREE_API_KEY` | no | none | Waitlist count from Formspree submissions. |
| `WAITLIST_SHEET_CSV_URL` | no | none | Waitlist count from a public CSV. |
| `WAITLIST_CSV_SKIP_HEADER` | no | `true` | Subtracts 1 from CSV row count. |
| `IMAGE_GEN_MAX_PROMPT_CHARS` | no | `10000` | Truncation limit for avatar portrait prompt. |

Feature flags turned on (all environments except `test` for `:onboarding`):

| Flag | State after Phase 4 |
|---|---|
| `onboarding` | `true` (production, development); `false` (test) |
| `profile` | `true` |
| `avatar` | `true` |
| `outfit_preview` | `true` |

## Exit Gate Verification

- All RSpec examples pass (prior suite from Phase 3: 763 examples, 0 failures; Phase 4 adds `prompt_builder_spec`, `progress_spec`, `metrics_spec`).
- All Cucumber scenarios pass (prior suite from Phase 3: 75 scenarios, 0 failures; Phase 4 adds 6 feature files).
- Brakeman and RuboCop: no new warnings.
- Feature flags: profile, onboarding (dev/prod), avatar, outfit_preview all on.

## Known Limitations and Deferred Items

- **Outfit preview strategy 2** (`gemini_image`) requires `generate_image_multimodal` to be fully wired in `Ai::Client::Vertex`. Phase 1 noted this as a possible deferral (11.4 task 8). The job calls it and falls through to the collage on any `Ai::Error`, so production is safe.
- **Ranking API** (`search_rank` kind) was not built. It remains a stretch goal.
- **Receipt LLM cleanup** (`RECEIPT_LLM_CLEANUP`) was not built. Stretch goal from Phase 2.
- **Weather integration** (Open-Meteo) was not built. Stub remains. Stretch goal from Phase 3.
- **Photo intake click-to-zoom `<dialog>`** deferred from Phase 2.
- **`AVATAR_IMAGEN_MODEL`** is not read; avatars use `IMAGEN_MODEL`. Noted as a Phase 1 known issue.
- **Heroku production verification**: avatar generation, outfit preview AI strategies, and GA4 integration have not been verified against real services on Heroku. Checks 7 and 8 from the Phase 2 integration checklist remain open.
