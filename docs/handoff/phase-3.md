# Phase 3 Handoff Note — Planner & Recommendations

## Completed Capabilities
- **Recommendation Engine**: Implemented `Planner::RecommendationEngine` to filter user garments (`hidden_from_recommendations: false`) and assemble top/bottom/shoes combinations.
- **Weather Service**: Implemented `Planner::Weather` stub returning forecast structures.
- **Calendar Synchronization**: Implemented `Planner::CalendarSync` service and enqueued via `Planner::SyncCalendarJob`.
- **Controllers & UI**: Created `WeekPlansController`, `OutfitsController`, `CalendarSyncsController`, and rendered `app/views/week_plans/show.html.erb` for `/week_plan`.
- **Background Jobs**: Implemented `Planner::ExplainOutfitJob` and `Planner::SyncCalendarJob`.

## Exit Gate Verification
- All RSpec examples pass (763 examples, 0 failures).
- All Cucumber scenarios pass (75 scenarios, 0 failures).

## Follow-up: calendar sync UX and planner tests (issue #31)

### Deviations from the design doc
- [DEVIATION] `Users::OmniauthCallbacksController` (Phase 1): a signed-in user's Google callback now links the Google account to `current_user` (6.1, calendar connect), whatever its email. It previously saved a new user before rejecting the mismatch. A Google account already linked to someone else still gets "Account mismatch". A cancelled calendar connect now returns to `/week_plan` instead of `/`.
- [DEVIATION] `features/security/authorization.feature` and `spec/requests/authorization_spec.rb` (Phase 1 harness): added planner cases (another user's outfit, week event, outfits list and week plan), as 8.4 asks of each phase.

### Decisions made where the doc was silent
- [DECISION] "Connect Google Calendar" POSTs straight to `/users/auth/google_oauth2?origin=/week_plan?sync=1` with its own CSRF token, and the callback follows `origin` only when it is the week plan. A first version POSTed to `/calendar_sync` and answered `307` to OmniAuth. That fails in real browsers, because Rails' per-form CSRF tokens are bound to `/calendar_sync`; the test env turns forgery protection off, so a request spec with protection on now covers it. Turbo is off on the button because the flow leaves the site.
- [DECISION] Back from Google, `/week_plan?sync=1` queues one `SyncCalendarJob` and redirects to `/week_plan`, so a reload does not queue another.
- [DECISION] Sync feedback is broadcast into `#calendar_sync_status` on the planner stream (success, reconnect, "Couldn't reach Google Calendar. Please try again."). The reconnect prompt also shows on later visits: it is derived from state (Google linked or previously synced, but no refresh token), so no schema change.
- [DECISION] A second 401 after a successful refresh is treated like `invalid_grant`: both tokens are cleared, so the button goes back to "Connect Google Calendar". Other errors leave the week and the tokens alone.
- [DECISION] The generate guard renders the week plan with `422` and `flash.now`, which keeps the HTML-safe "Go to your wardrobe" link. A redirect's flash goes through the session and would lose it.

### Fixes found while testing
- `WeekEventsController#update` called `dom_id`, which controllers do not have. Every pill click returned a 500 after saving. It now uses `helpers.dom_id`.
- `CalendarSync` crashed when a day mixed all-day and timed events (it sorted strings against times), and a second 401 escaped the `rescue` and failed the job.
- The `I sync my calendar` step passed a Regexp to `click_button`, which Capybara does not match.

### Not done here
- `outfits.feature` scenarios that need the full Outfits page (hide toggle, regenerate, the missing-bottom banner) belong to issues #29 and #30.
- A broadcast can still be missed if the job finishes before the page subscribes to the stream; reloading shows the synced week.

## Follow-up: full-day outfit planning (issue #8)

### Schema changes after Phase 1
- New table `calendar_events` (under `week_events`): every synced event of a day, with summary, classified `event_type`, `starts_at`, `ends_at`, `all_day`, `location` and `position`. `week_events` is unchanged and keeps the day's winning type for the pills.
- `outfit_recommendations`: added `segment_index` (default 0), `starts_at`, `ends_at`, `segment_label`, `change_reason` and `worn_at`. The unique index moved from `[week_plan_id, date]` to `[week_plan_id, date, segment_index]`. Existing rows are segment 0.

### Decisions made where the doc was silent
- [DECISION] `Planner::DaySegmenter` (pure) splits a day into at most 3 time blocks. Same-type and casual events share an outfit. Gym next to work or a date night means a change. A work meeting and a date night share one smart-casual outfit when the wardrobe has one, and otherwise the user changes before dinner. All-day events never open a block of their own.
- [DECISION] `RecommendationEngine` takes segments in place of week events (any object with `#date` and `#event_type`; a segment's `#chain` overrides the formality chain). With one segment per day, its output is identical to before.
- [DECISION] The timeline lives at `/outfits/today` (`?date=` for other days of the week) with its own controllers, so the nav highlights "Outfits" and the Outfits rebuild (#30) is not touched.
- [DECISION] "I wore this" sets `worn_at` on the recommendation. A regenerate keeps every day with a worn outfit, and pieces worn in the last 7 days lose ties to unworn ones. Per-garment wear history and laundry status belong to #9 and are not touched here.
- [DECISION] A manual pill change or the demo week clears that day's `calendar_events`, so a manual choice always means one outfit.

### Not done here
- Laundry status in recommendations: it needs #9's data, so it is a follow-up once #9 merges.
- `/outfits` still lists every outfit (now including every segment) in the existing card layout; the full Outfits page is #30.
