# misfitAI — CourseWorks iteration 2 submission

Personal wardrobe planner SaaS: digitize a closet, sync the week from Google Calendar, get weather- and laundry-aware outfit recommendations for every part of the day with AI-written explanations, track what you wear, and preview outfits on an illustrated avatar.

## Team

| Name | UNI |
|------|-----|
| Gautam Agarwal| ga2726 |
| Markos Bontozoglou | mb5644 |
| Taha Lahlou | tl3386 |
| Ashton Lollis | adl2199 |

## Links

| Resource | URL |
|----------|-----|
| **Heroku (live prototype)** | https://misfits-ai-demo-5e25da632c7b.herokuapp.com/ |
| **Health check** | https://misfits-ai-demo-5e25da632c7b.herokuapp.com/up |
| **GitHub** | https://github.com/GAInTheHouse/MisfitsAI |
| **CI** | https://github.com/GAInTheHouse/MisfitsAI/actions/workflows/ci.yml |

## Product summary

1. **Account**: email/password and Google sign-in (Devise + OmniAuth). All data is scoped per user, and the user's time zone drives the week and the weather location.
2. **Wardrobe**: add garments manually, through image search (SerpAPI), from a photo (AI extraction with editable drafts), from receipts (PDF/text/image parsing), or from the onboarding starter catalog. Filter, hide and delete garments, and retry failed images.
3. **Laundry & wear history**: confirming an outfit records a wear on each garment. When a garment reaches its wash threshold it moves to the laundry and is left out of recommendations until it's washed (per garment or "wash all"). The wear history page shows wear counts and cost per wear.
4. **Week plan**: a seven-day view that follows the user's time zone. Load a demo week, set the event type for each day by hand, or sync events from **Google Calendar**. Synced events are classified by type, and the highest-priority type wins for each day.
5. **Outfits**: rule-based recommendations for each event type (work, date night, gym, etc.), shown as Mon–Sun tabs with a garment collage. Explanations come from an LLM, stream in as they're written, and fall back to a template if the AI is unavailable. You can hide an item, regenerate the week, and see a banner that links to the wardrobe when a slot (e.g. bottoms) is missing.
6. **Full-day planning**: `/outfits/today` shows the day as a timeline. Separate events, such as a morning gym session and then work, get separate outfits with a "change" note. Confirming what you wore locks that day when you regenerate.
7. **Weather**: the forecast for the user's city (OpenWeatherMap) feeds into recommendations. It falls back to a default forecast when no key is configured.
8. **Profile & onboarding**: sizes, measurements and style preferences, collected through multi-step onboarding for new users.
9. **Avatar & On Me**: a selfie becomes an illustrated avatar, and outfits can be previewed on that avatar (feature-flagged).
10. **Metrics & admin**: the internal `GET /api/metrics` endpoint for the studio dashboard, plus `GET /admin/metrics` and `GET /admin/ai_usage` (daily AI calls, estimated cost and latency for each kind of call). All three require the `X-Analytics-Key` header.

Stack: Ruby 3.3, Rails 8, Hotwire (Turbo Streams), PostgreSQL, Solid Queue, Active Storage, Vertex AI (Gemini / Imagen), Cucumber + RSpec, deployed on Heroku.

### What changed since iteration 1

- Laundry tracking and wear history (#9, #41)
- Full-day, laundry-aware planning with the day timeline and "I wore this" (#8, #42)
- Real weather from OpenWeatherMap, using the user's city rather than a hard-coded location (#13, #34, #47)
- Better Google Calendar sync: improved UX, the OAuth return path, and a reconnect prompt when the connection expires (#31, #38)
- Demo seeds for the planner (#32, #33)
- Fixes to the planner's week boundary, calendar completion, outfit scope and AI explanations (#43)
- Weekly outfits UI: Mon–Sun tabs, garment collage, a hide toggle and the missing-slot banner (#44)
- Fixes to avatar onboarding (#49, #51) and a new favicon (#36, #39)

---

## How to run locally

### Prerequisites

- Ruby **3.3.14** (see `.ruby-version`), Bundler **2.6.x**
- PostgreSQL **16**
- **libvips** (image processing)
- Optional: Google Cloud (Vertex AI, Calendar OAuth), SerpAPI, and OpenWeatherMap (`WEATHER_API_KEY`) keys for real integrations (see [`.env.example`](../.env.example))

### Setup

```bash
cd ..   # repo root
createdb misfit_development misfit_test
bundle install
cp .env.example .env
bin/rails db:migrate db:seed
bin/dev
```

Open http://localhost:3000

With the default `AI_ADAPTER=fake` in `.env`, AI and image generation use deterministic fixtures, so there's no GCP billing. Without `WEATHER_API_KEY`, the planner uses a default forecast.

### Demo data (local seed)

`db:seed` creates a demo user, `demo@misfit.ai`, when `DEMO_PASSWORD` is set in the environment (12+ characters). The seed output prints the email only, not the password. The seed also includes planner demo data, so the week plan and outfits can be shown right away.

---

## How to test

### Automated suite (required for grading)

From the repository root:

```bash
AI_ADAPTER=fake bundle exec rspec
AI_ADAPTER=fake bundle exec cucumber
```

**Latest CI on `main`** (run for #51):

| Suite | Result |
|-------|--------|
| RSpec | 897 examples, 0 failures |
| Cucumber | 134 scenarios (841 steps), 0 failures |
| Line coverage (CI, `COVERAGE=true`) | 91.04% (1596 / 1753 lines) |

CI also runs RuboCop, Brakeman and `bundler-audit` on every push and pull request. See [.github/workflows/ci.yml](../.github/workflows/ci.yml).

### Manual smoke on Heroku

1. Open the [deployment URL](https://misfits-ai-demo-5e25da632c7b.herokuapp.com/).
2. **Sign up** or sign in (Google if configured on the app), then complete **onboarding**.
3. **Wardrobe**: add a top, a bottom and shoes (manual add is the simplest path). Optionally try image search, photo intake or a receipt.
4. **Planner**: open the week view, then either load the demo week or **sync Google Calendar**, and **generate outfits**.
5. **Outfits**: switch between the Mon–Sun tabs and check that each day has an outfit and an explanation. Hide an item and regenerate.
6. **Today**: open `/outfits/today`, confirm "I wore this", and check that the worn pieces appear in **wear history** and, once they hit their wash threshold, in the laundry.
7. Optional: **Profile**, **avatar** and **On Me** previews, depending on Heroku feature flags.

If something fails only on Heroku, check `heroku logs --tail` and the config vars against [docs/runbook.md](../docs/runbook.md).

### Real AI smoke (optional, billed)

```bash
AI_ADAPTER=vertex bin/rails runner bin/ai_smoke
```

Graders running the fake adapter locally don't need this.

---

## User stories (Cucumber)

Behavior is specified in Gherkin under [`features/`](../features/). Scenarios run in headless Chrome (Cuprite) against the Rails test server.

| Area | Feature files | Scenarios |
|------|----------------|-----------|
| Auth (email) | `features/auth/email_signup.feature`, `email_login.feature` | 7 |
| Auth (Google) | `features/auth/google_sign_in.feature` | 4 |
| Wardrobe | `manage`, `manual_add`, `search`, `photo_intake`, `laundry_and_wear_history` | 46 |
| Receipts | `features/receipts/receipts.feature` | 10 |
| Planner | `week_plan`, `outfits`, `calendar_sync`, `full_day_plan`, `end_to_end` | 27 |
| Onboarding & profile | `onboarding`, `profile` | 11 |
| Avatar | `avatar`, `outfit_on_me` | 10 |
| Navigation | `features/navigation/stepper.feature` | 4 |
| Security | `authorization`, `rate_limits` | 3 |
| Metrics API | `features/metrics/metrics_api.feature` | 6 |
| Test harness | `features/harness/test_harness.feature` | 6 |
| **Total** | 23 feature files | **134** |

Example story (from full-day planning):

```gherkin
Feature: Full-day outfit planning
  I want an outfit for each part of my day, and to know when to change
  So that I'm dressed right from the morning workout to the evening dinner

  Scenario: A gym session and a work meeting get separate outfits and a change note
```

Core stories covered by the app: **sign up / sign in**, **manage and add garments** (manual, search, photo, receipt), **onboarding and profile**, **week plan with calendar sync**, **weekly and full-day outfit generation**, **laundry and wear tracking**, **avatar previews**, and **authorization** (users can't access each other's data).

---

## RSpec tests

Specs live in [`spec/`](../spec/). They cover:

- **Domain logic**: the outfit recommendation engine (including laundry exclusion), event classifier, day segmenter, week planner, weather client, Google Calendar sync, receipt text/vision/PDF parsers, search filter/rank, and photo intake mapping
- **Models**: garments (wear, wash threshold, laundry status, cost per wear), outfits, week plans and users
- **Jobs**: garment images, photo extraction, receipts, outfit explanations, and remote image import
- **HTTP**: garments, laundry, the wardrobe search/receipts/photo intakes, the planner, metrics, rate limits and authorization
- **AI platform**: the `Ai::Client` fake and Vertex adapters, call logging and token handling
- **Infrastructure**: safe media fetching, image normalization, seeds, navigation progress and channels

Run with:

```bash
AI_ADAPTER=fake COVERAGE=true bundle exec rspec
```

HTML coverage report: `coverage/index.html` (after a local run with `COVERAGE=true`).

---

## Deployment (Heroku)

| Item | Detail |
|------|--------|
| App URL | https://misfits-ai-demo-5e25da632c7b.herokuapp.com/ |
| Platform | Heroku, Rails 8, Puma, Solid Queue in-process |
| Database | Heroku Postgres (migrations via `bin/rails db:migrate`) |
| Feature flags | [`config/features.yml`](../config/features.yml): onboarding, profile, avatar, outfit preview, photo intake, receipts and calendar sync are all enabled in production |
| AI | Configured with `AI_ADAPTER` and the Vertex-related env vars; tests and CI use `fake` |
| Integrations | Google OAuth + Calendar, SerpAPI (image search), OpenWeatherMap (`WEATHER_API_KEY`) |

Operational notes: [docs/runbook.md](../docs/runbook.md), [docs/google-cloud-setup.md](../docs/google-cloud-setup.md)

---



# TEAM NOTES BELOW (delete before submitting)

- [ ] **CI lint job is red on `main`.** `bundler-audit` flags a high-criticality advisory in `rack-protection` (CookieTossing). RSpec and Cucumber pass. Bump the gem, or document the exception, before submitting so the CI link shows green.
- [ ] After any further merges, re-check the test counts and coverage in **How to test** against the latest CI run.

## Assignment checklist

| Requirement | Where |
|-------------|--------|
| README: team names & UNIs | **Team** section above |
| README: run & test instructions | **How to run locally** and **How to test** above |
| Cucumber user stories | [`features/`](../features/) |
| RSpec tests | [`spec/`](../spec/) |
| Working prototype | Heroku link + passing CI |
| Heroku deployment link | https://misfits-ai-demo-5e25da632c7b.herokuapp.com/ |
| GitHub repository link | https://github.com/GAInTheHouse/MisfitsAI |


---

## Suggested CourseWorks comment (copy/paste)

```
Team: Gautam Agarwal (ga2726), Markos Bontozoglou (mb5644), Taha Lahlou (tl3386), Ashton Lollis (adl2199)
Product: misfitAI — AI wardrobe planner (Rails 8 SaaS)
Heroku: https://misfits-ai-demo-5e25da632c7b.herokuapp.com/
GitHub: https://github.com/GAInTheHouse/MisfitsAI
Tests: 134 Cucumber scenarios and 897 RSpec examples, 91% line coverage (see repo CI). Run locally with AI_ADAPTER=fake.
Submission README: submissions/iter-2.md in the repository.
```
