# misfitAI (Rails)

Personal wardrobe planner — Phase 1 foundation: schema, auth, layout, AI platform (`Ai::Client`), media helpers, CI, and Cucumber/RSpec harness.

## Local setup

```bash
createdb misfit_development misfit_test   # PostgreSQL 16
bundle install
cp .env.example .env
bin/rails db:migrate db:seed
bin/dev
```

## Tests

```bash
AI_ADAPTER=fake bundle exec rspec
AI_ADAPTER=fake bundle exec cucumber
```

## AI smoke (real GCP)

```bash
AI_ADAPTER=vertex bin/rails runner bin/ai_smoke
```

Design reference: [docs/ruby_rewrite_design_doc_v2.md](docs/ruby_rewrite_design_doc_v2.md)
