# misfitAI — CourseWorks iteration 1 submission

Personal wardrobe planner SaaS: digitize a closet, plan the week, get rule-based outfit recommendations with AI-written explanations, and optional avatar / “outfit on me” previews.

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

## Product summary (MVP)

1. **Account** — Email/password and Google sign-in (Devise); data scoped per user.
2. **Wardrobe** — Add garments manually, via image search, photo AI, receipts, or onboarding starter catalog; filter, hide, delete.
3. **Week plan** — Seven-day view, demo week, optional Google Calendar sync; generate outfits when the wardrobe has enough pieces.
4. **Outfits** — Rule-based recommendations per event type (work, date night, gym, etc.) with streamed LLM explanations.
5. **Profile & onboarding** — Sizes, measurements, style preferences; multi-step onboarding for new users.
6. **Avatar & On Me** — Selfie → illustrated avatar; preview outfits on the avatar (feature-flagged).
7. **Metrics** — Internal `GET /api/metrics` for studio dashboard (API key).

Stack: Ruby 3.3, Rails 8, Hotwire, PostgreSQL, Solid Queue, Cucumber + RSpec, deployed on Heroku.

---

## How to run locally

### Prerequisites

- Ruby **3.3.12**, Bundler **2.6.x**
- PostgreSQL **16**
- **libvips** (image processing)
- Optional: Google Cloud, SerpAPI, and related keys for real AI (see [`.env.example`](../.env.example))

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

With default `AI_ADAPTER=fake` in `.env`, AI and image generation use deterministic fixtures (no GCP billing).

### Demo data (local seed)

`db:seed` can create a demo user `demo@misfit.ai` when `DEMO_PASSWORD` is set in the environment (12+ characters). The seed output prints the email only, not the password.

---

## How to test

### Automated suite (required for grading)

From the repository root:

```bash
AI_ADAPTER=fake bundle exec rspec
AI_ADAPTER=fake bundle exec cucumber
```

**Latest CI on `main` (representative):**

| Suite | Result |
|-------|--------|
| RSpec | 824 examples, 0 failures |
| Cucumber | 111 scenarios, 0 failures |
| Line coverage (CI, `COVERAGE=true`) | 91.50% |

CI also runs RuboCop, Brakeman, and `bundler-audit` on every push and pull request. See [.github/workflows/ci.yml](../.github/workflows/ci.yml).

### Manual smoke on Heroku

1. Open the [deployment URL](https://misfits-ai-demo-5e25da632c7b.herokuapp.com/).
2. **Sign up** or sign in (Google if configured on the app).
3. **Wardrobe** — add a top and a bottom (manual add is the simplest path).
4. **Planner** — open the week view, load the demo week if offered, **generate outfits**.
5. **Outfits** — confirm recommendations appear for days that have events.
6. Optional: **Profile**, **onboarding**, **avatar** depending on Heroku feature flags.

If something fails only on Heroku, check `heroku logs --tail` and config vars against [docs/runbook.md](../docs/runbook.md).

### Real AI smoke (optional, billed)

```bash
AI_ADAPTER=vertex bin/rails runner bin/ai_smoke
```

Not required for graders running the fake adapter locally.

---

## User stories (Cucumber)

Behavior is specified under [`features/`](../features/) in Gherkin. Scenarios run in headless Chrome (Cuprite) against the Rails test server.

| Area | Feature files | Scenarios |
|------|----------------|-----------|
| Auth (email) | `features/auth/email_signup.feature`, `email_login.feature` | 7 |
| Auth (Google) | `features/auth/google_sign_in.feature` | 4 |
| Wardrobe | `manage`, `manual_add`, `search`, `photo_intake` | 45 |
| Receipts | `features/receipts/receipts.feature` | 10 |
| Planner | `week_plan`, `outfits` | 8 |
| Onboarding & profile | `onboarding`, `profile` | 11 |
| Avatar | `avatar`, `outfit_on_me` | 8 |
| Navigation | `features/navigation/stepper.feature` | 4 |
| Security | `authorization`, `rate_limits` | 2 |
| Metrics API | `features/metrics/metrics_api.feature` | 6 |
| Test harness | `features/harness/test_harness.feature` | 6 |
| **Total** | 19 feature files | **111** |

Example story (from auth):

```gherkin
Feature: Email sign up
  As a new visitor
  I want to create an account with email
  So that I can save my wardrobe
```

Core MVP stories for iteration 1: **sign up / sign in**, **manage and add garments**, **week plan and generate outfits**, **onboarding**, and **authorization** (users cannot access each other's data).

---

## RSpec tests

Specs live in [`spec/`](../spec/). They cover:

- **Domain logic** — outfit recommendation engine, event classifier, receipt/text/vision parsers, search filter/rank, photo intake mapping
- **Jobs** — garment images, photo extraction, outfit explanations, remote image import
- **HTTP** — garments, wardrobe search/receipts/photo intakes, metrics, rate limits, authorization
- **AI platform** — `Ai::Client` fake/vertex adapters, call logging, token handling
- **Infrastructure** — media safe fetch, image normalization, seeds, navigation progress

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
| Feature flags | [`config/features.yml`](../config/features.yml) (production defaults enable main product paths) |
| AI | Configurable via `AI_ADAPTER` and Vertex-related env vars; tests and CI use `fake` |

Operational notes: [docs/runbook.md](../docs/runbook.md), [docs/google-cloud-setup.md](../docs/google-cloud-setup.md)

---



# TEAM NOTES BELOW


## Assignment checklist

| Requirement | Where |
|-------------|--------|
| README: team names & UNIs | **Team** section above (fill in before submit) |
| README: run & test instructions | **How to run locally** and **How to test** above |
| Cucumber user stories | [`features/`](../features/) |
| RSpec tests | [`spec/`](../spec/) |
| Working prototype | Heroku link + passing CI |
| Heroku deployment link | https://misfits-ai-demo-5e25da632c7b.herokuapp.com/ |
| GitHub repository link | https://github.com/GAInTheHouse/MisfitsAI |

## Additional materials (optional uploads)

- Screenshots of wardrobe, week plan, and outfits (mobile width ~390px).
- PDF export of this README.
- Link to the latest green [CI run](https://github.com/GAInTheHouse/MisfitsAI/actions) on `main`.

---

## Suggested CourseWorks comment (copy/paste)

```
Team: [names and UNIs — same as table in submissions/README.md]
Product: misfitAI — AI wardrobe planner (Rails 8 SaaS)
Heroku: https://misfits-ai-demo-5e25da632c7b.herokuapp.com/
GitHub: https://github.com/GAInTheHouse/MisfitsAI
Tests: 111 Cucumber scenarios and 824 RSpec examples (see repo CI). Run locally with AI_ADAPTER=fake.
Submission README: submissions/README.md in the repository.
```