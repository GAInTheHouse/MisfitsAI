# misfitAI — CourseWorks iteration 2 submission

Personal wardrobe planner SaaS: digitize a closet, sync the week from Google Calendar, get weather- and laundry-aware outfit recommendations with AI-written explanations, track what you wear, and preview outfits on an illustrated avatar.

## Team

| Name | UNI |
|------|-----|
| Gautam Agarwal | ga2726 |
| Markos Bontozoglou | mb5644 |
| Taha Lahlou | tl3386 |
| Ashton Lollis | adl2199 |

## Links

| Resource | URL |
|----------|-----|
| **Heroku (live prototype)** | https://misfits-ai-demo-5e25da632c7b.herokuapp.com/ |
| **Health check** | https://misfits-ai-demo-5e25da632c7b.herokuapp.com/up |
| **GitHub** | https://github.com/GAInTheHouse/MisfitsAI |
| **CI (tests + merged coverage)** | https://github.com/GAInTheHouse/MisfitsAI/actions/workflows/ci.yml |
| **Photo intake flatlay** | https://github.com/GAInTheHouse/MisfitsAI/pull/66 |

## Product summary (main features)

1. **Account** — Email/password and Google sign-in; per-user data; time zone drives the week and weather location.
2. **Wardrobe** — Manual add, image search, photo AI (a flatlay generated from the uploaded photo), receipts, onboarding starter catalog; filter, hide, delete, retry images.
3. **Laundry & wear history** — Confirming an outfit records wears; garments enter laundry at their wash threshold and stay out of recommendations until washed.
4. **Week plan** — Seven-day view, demo week, manual event types, **Google Calendar sync** with reconnect when OAuth expires.
5. **Outfits** — Rule-based recommendations per event type; Mon–Sun UI; streamed LLM explanations with template fallback; hide/regenerate; missing-slot banners.
6. **Full-day planning** — `/outfits/today` timeline; separate outfits per segment; “I wore this” locks the day when regenerating.
7. **Weather** — OpenWeatherMap by user city (stubbed in tests); outerwear rules by temperature (see `features/planner/weather_outfits.feature`).
8. **Profile & onboarding** — Sizes, measurements, style preferences; guided onboarding.
9. **Avatar & On Me** — Selfie to illustrated avatar (Gemini); outfit preview on avatar (feature-flagged).
10. **Admin metrics** — `GET /api/metrics` and `GET /admin/metrics` with `X-Analytics-Key` (covered in RSpec, not Cucumber).

Stack: Ruby 3.3.14, Rails 8, Hotwire, PostgreSQL, Solid Queue, Vertex AI (fake adapter in CI/test), Cucumber + RSpec, Heroku.

### What changed since iteration 1

- Laundry tracking and wear history
- Full-day, laundry-aware planning and today timeline
- OpenWeatherMap integration by user city
- Calendar sync UX, OAuth return path, reconnect prompt
- Planner bug fixes (week boundary, calendar completion, outfit scope, explanations)
- Weekly outfits UI (tabs, collage, hide, missing-slot banner)
- Avatar via Gemini; On Me and stepper polish; profile swatch UX
- Photo AI builds each draft image from the uploaded photo (image-conditioned flatlay, [#66](https://github.com/GAInTheHouse/MisfitsAI/pull/66)); the raw upload is removed after those images finish
- Iteration 2 submission work: product-focused Cucumber and merged SimpleCov in CI

---

## How to run locally

```bash
createdb misfit_development misfit_test
bundle install
cp .env.example .env
bin/rails db:migrate db:seed
bin/dev
```

Open http://localhost:3000. Use `AI_ADAPTER=fake` in `.env` for tests and local runs without billed GCP calls.

---

## How to test

```bash
AI_ADAPTER=fake bundle exec rspec
AI_ADAPTER=fake bundle exec cucumber
```

**Coverage (iteration 2):**

```bash
COVERAGE=true AI_ADAPTER=fake bundle exec rspec
COVERAGE=true AI_ADAPTER=fake bundle exec cucumber
```

On GitHub Actions, open the latest green **CI** run → **coverage** job → download artifact **coverage-report** for merged `index.html`.

**User-facing Cucumber scenarios:** 124 (130 total scenarios minus 6 `@harness` infrastructure scenarios).

| Area | Feature files | Scenarios |
|------|----------------|-----------|
| Auth | `email_signup`, `email_login`, `google_sign_in` | 10 |
| Wardrobe | `manage`, `manual_add`, `search`, `photo_intake`, `laundry_and_wear_history` | 46 |
| Receipts | `receipts` | 10 |
| Planner | `week_plan`, `outfits`, `calendar_sync`, `full_day_plan`, `end_to_end`, `weather_outfits` | 29 |
| Onboarding & profile | `onboarding`, `profile` | 12 |
| Avatar | `avatar`, `outfit_on_me` | 10 |
| Navigation | `stepper` | 5 |
| Security (product) | `authorization` | 2 |
| **User stories total** | 22 feature files | **124** |
| Harness (not user stories) | `harness/test_harness` | 6 |

**RSpec:** request, model, job, and service specs under `spec/` (including encryption, login rate limits, metrics, recommendation engine, weather, calendar). Example count changes with each merge; see the **rspec** job in CI.

---

## Manual smoke on Heroku

1. Open the [deployment URL](https://misfits-ai-demo-5e25da632c7b.herokuapp.com/).
2. Sign up or sign in; complete onboarding if prompted.
3. **Wardrobe** — Add a top and bottom with **Generate a product image** unchecked (fastest path), or add via search for a real product photo.
4. **Week plan** — Load the demo week and **Generate outfits**.
5. **Outfits** — Check Mon–Sun cards and explanations.
6. **Today** — Confirm **I wore this**; open wear history and laundry when thresholds hit.
7. Optional: Calendar sync, photo AI (flatlay from your photo), avatar / On Me.

---

## Deployment

| Item | Detail |
|------|--------|
| App URL | https://misfits-ai-demo-5e25da632c7b.herokuapp.com/ |
| Platform | Heroku, Rails 8, Puma, Solid Queue in-process |
| Tests in CI | RuboCop, Brakeman, bundler-audit, RSpec + Cucumber + merged SimpleCov |

---

## CourseWorks comment (copy/paste)

```
Team: Gautam Agarwal (ga2726), Markos Bontozoglou (mb5644), Taha Lahlou (tl3386), Ashton Lollis (adl2199)
Product: misfitAI — AI wardrobe planner (Rails 8 SaaS)
Heroku: https://misfits-ai-demo-5e25da632c7b.herokuapp.com/
GitHub: https://github.com/GAInTheHouse/MisfitsAI
Tests: 124 Cucumber user scenarios + RSpec; merged SimpleCov in CI (coverage-report artifact). Run locally with AI_ADAPTER=fake.
Submission README: submissions/iter-2.md
```