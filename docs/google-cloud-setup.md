# Google Cloud setup for MisfitAI

How MisfitAI uses Google Cloud, what exists today, how to authenticate, and how to work with it safely.

This guide is written for developers joining after Phase 2. It describes the code as it is on `phase-2` (2026-10-22), checked against the code itself rather than the design doc. Integration test history is in [`docs/handoff/phase-2.md`](handoff/phase-2.md), section 14.

> **Never put credentials, tokens, service-account keys or signed URLs in this repository, in issues, or in chat.** Every identifier in this guide (project, bucket, service-account email, model IDs) is a resource name, not a secret.

## Contents

- [Onboarding checklist](#onboarding-checklist)
- [A. Architecture and purpose](#a-architecture-and-purpose)
- [B. Existing Google Cloud resources](#b-existing-google-cloud-resources)
- [C. Authentication](#c-authentication)
- [D. Environment variables](#d-environment-variables)
- [E. Developer workflows](#e-developer-workflows)
- [F. Costs](#f-costs)
- [G. Known limitations](#g-known-limitations)
- [H. Handoff guidance](#h-handoff-guidance)

---

## Onboarding checklist

> ⚠️ **`AI_ADAPTER` must be set to exactly `fake` to use the fake adapter. If it is unset, or set to anything else, the app uses real Vertex AI and makes billed calls.** `.env.example` sets `AI_ADAPTER=fake`; keep it that way in your `.env`.

1. **Get access from a project administrator** for `misfitai-512403` (see [C](#c-authentication) for the commands):
   - `roles/aiplatform.user`, only if you will make real Vertex calls;
   - object access on `misfitai-dev-images-2026`, only if you will test GCS;
   - `roles/iam.serviceAccountTokenCreator` on `misfitai-dev-storage@misfitai-512403.iam.gserviceaccount.com`, only if you need signed URLs.

   Ask only for what you need, and never ask for, create or share a service-account key.
2. **Authenticate locally:**
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```
3. **Set the project and quota project:**
   ```bash
   gcloud config set project misfitai-512403
   gcloud auth application-default set-quota-project misfitai-512403
   ```
   The Vertex region is `us-central1`, the code default (`GOOGLE_CLOUD_LOCATION`); you don't need to set it.
4. **Start with fake AI and local storage:** copy `.env.example` to `.env` (keep `AI_ADAPTER=fake` and `GOOGLE_SERVICE_ACCOUNT_JSON` blank), then run `bin/setup`, `bin/rails db:seed` and `bin/dev`. This needs no Google Cloud access at all ([E1](#1-normal-development-fake-ai-and-local-storage)).
5. **Opt into real Vertex AI only on purpose:** set `AI_ADAPTER=vertex` and `GOOGLE_CLOUD_PROJECT=misfitai-512403` **for one process**, with low caps (`AI_DAILY_IMAGE_LIMIT`, `AI_DAILY_VISION_LIMIT`, `AI_DAILY_BUDGET_CENTS`). Don't put them in `.env` ([E2](#2-testing-real-vertex-ai-locally)).
6. **Opt into GCS only on purpose:** development always stores files on local disk. Use the development bucket only from a runner script, with `GOOGLE_CLOUD_PROJECT`, `GCS_BUCKET` (and `GCS_SIGNING_SERVICE_ACCOUNT` for signed URLs) set for that process, keys under `integration-checks/`, and cleanup in `ensure` ([E3](#3-using-the-development-gcs-bucket)).
7. **Understand the permissions:**
   - your own ADC login makes Vertex calls and GCS reads, writes and deletes;
   - `misfitai-dev-storage` is only the identity that signs URLs;
   - there are no project-wide storage or signing grants ([C](#c-authentication)).
8. **Avoid accidental cloud costs:**
   - keep `AI_ADAPTER=fake` in `.env`;
   - make one real call at a time;
   - set `AI_IMAGE_GEN_ENABLED=false` when you don't need images (about 4¢ each);
   - remember that retries and "Retry image" are new billed calls;
   - check `ai_calls` or `/admin/ai_usage` afterwards.

   GCP Billing is authoritative ([F](#f-costs)).
9. **When something fails:** see the troubleshooting table in [E5](#5-troubleshooting), the limitations in [G](#g-known-limitations), and the integration test history in [`docs/handoff/phase-2.md`](handoff/phase-2.md), section 14.

---

## A. Architecture and purpose

### Why Google Cloud

MisfitAI uses two Google Cloud services:

| Service | Used for | Code |
|---|---|---|
| **Vertex AI** (Gemini models) | Reading garments from outfit photos, reading clothing items from receipt images, and generating product images of garments | `app/services/ai/client/vertex.rb` |
| **Cloud Storage (GCS)** | Storing garment images (and other Active Storage files) in production | `config/storage.yml` (Active Storage `:google` service) |

The design doc also plans Discovery Engine (grounded text, ranking) for later phases. The adapter has the calls (`grounded_text`, `rank`), but nothing in Phase 2 uses them.

### Vertex AI's role

All AI calls go through one interface, `Ai::Client.current`. Application code never calls Vertex directly.

| Feature | Kind | Vertex call | Model (default) | Called from |
|---|---|---|---|---|
| Photo intake (garments in an outfit photo) | `garment_extraction` | `generateContent` with a JSON response schema, plus the photo | `VERTEX_VISION_MODEL` (`gemini-2.5-flash`) | `Wardrobe::ExtractGarmentsJob` |
| Receipt photos and screenshots | `receipt_extraction` | `generateContent` with a JSON schema, plus the image | `VERTEX_VISION_MODEL` (`gemini-2.5-flash`) | `Receipts::ParseImageJob`, through `Receipts::VisionParser` |
| Garment product images | `garment_image` | `generateContent` asking for an image (`responseModalities: ["TEXT","IMAGE"]`) | `GARMENT_IMAGE_MODEL` (`gemini-2.5-flash-image`) | `Wardrobe::GenerateGarmentImageJob` (manual add, starter import, receipt commit) and `Wardrobe::GenerateDraftImageJob` (photo-intake drafts) |

Pasted receipt text, text files and PDFs are parsed by rules (`Receipts::TextParser`), **not** by Gemini. Only receipt *images* go to Vertex.

**Adapters** (`app/services/ai/client.rb`):
- `AI_ADAPTER=fake` gives `Ai::Client::Fake`: deterministic fixture responses from `spec/fixtures/ai/`, no network, still writes `ai_calls` rows and still enforces quotas. Used by all tests and CI.
- **Any other value, or no value at all, gives `Ai::Client::Vertex`, which makes real, billed calls.** See [D](#d-environment-variables).

**Guards inside `Ai::Client`** (both adapters), run before any request:
- the image kill switch (`AI_IMAGE_GEN_ENABLED`);
- the per-user daily image and vision caps;
- the global daily budget, computed from the estimated cost in `ai_calls`.

**What the Vertex adapter does with responses** (summarized from `vertex.rb`):
- **HTTP errors** are mapped to typed errors:
  - `InvalidRequestError` (400), `AuthenticationError` (401/403), `NotFoundError` (404);
  - `RateLimitedError` (429, a kind of `TransientError`);
  - `TransientError` (408, 5xx, timeouts, connection failures).
- **Safety blocks** become `ContentBlockedError`, but only when Google gives an explicit safety signal.
- **Every attempt writes one `ai_calls` row** (`ok`, `error` or `blocked`). Failed attempts are recorded at 0¢.
- **There are no HTTP-level retries.** Jobs retry `Ai::TransientError` themselves (`retry_on … attempts: 3`).
- **Gemini garment images are validated before they count as a success:** the type is detected from the bytes (PNG, JPEG or WebP only), every pixel is decoded with libvips, and there is a pixel limit. The jobs then turn the image into a 512×512 JPEG with `Media::ImageNormalizer.to_square_jpeg`.

### Cloud Storage's role

Active Storage chooses its storage service per environment (`config/environments/*.rb`):

| Environment | Service | Where files go |
|---|---|---|
| development | `:local` | the `storage/` directory on disk |
| test | `:test` | the `tmp/storage/` directory on disk |
| production | `:google` | GCS bucket `GCS_BUCKET`, with signed URLs that expire after `service_urls_expire_in = 1.hour` |

There is **no environment variable to switch development to GCS**; the service is set in `config/environments/development.rb`. To exercise GCS locally, use the `:google` service directly from a runner script (see [E](#e-developer-workflows)).

**How images are served:** views never link to storage directly. They use Rails' redirect routes:
- `GarmentsHelper#garment_image_source` gives `rails_representation_path(variant)`;
- `Garment#image_or_placeholder_url` and the draft-image partial give `rails_blob_path`.

When a browser requests one of these, Rails redirects it to `blob.url`. For GCS that is a **signed URL**. The Content Security Policy already allows `https://storage.googleapis.com` in `img-src`.

### How the pieces fit together

```
Browser ──> Rails (Puma) ──> Active Job ──> Ai::Client.current ──> Vertex AI (generateContent)
                  │                │                                    (ADC or service-account token)
                  │                └──> garment.image.attach ──> Active Storage service
                  │                                                  ├─ development/test: local disk
                  │                                                  └─ production: GCS bucket
                  └──> rails_blob/representation redirect ──> blob.url ──> signed GCS URL
                                                                           (private key, or keyless IAM signBlob)
```

**Jobs per environment:**
- **Development:** no queue adapter is configured, so Active Job uses Rails' default **in-process threads**. Jobs run inside the Rails server process. Solid Queue's concurrency limits and recurring tasks don't apply.
- **Production:** uses **Solid Queue**. `ai_images` runs on its own worker with 1 thread (`config/queue.yml`). The recurring tasks are in `config/recurring.yml` (production only), including `purge_stale_intake_drafts` daily at 4am.

### Local versus production

| Integration | Local development (default) | Local, real-service testing | Production (planned; nothing is deployed) |
|---|---|---|---|
| AI | fake adapter (`AI_ADAPTER=fake` in `.env`) | Vertex through **your** ADC, set only for that process | Vertex through a service-account key in `GOOGLE_SERVICE_ACCOUNT_JSON` (design doc 3.4). **Not set up** |
| Storage | local disk | the `:google` service from a runner script, using your ADC | GCS bucket and production credentials. **Not set up** |
| Signed URLs | not needed (local disk) | keyless IAM signing as `misfitai-dev-storage` (`GCS_SIGNING_SERVICE_ACCOUNT`) | a key's private key, keyless signing, or proxy mode: **still a decision** ([G](#g-known-limitations)) |

---

## B. Existing Google Cloud resources

Verified on 2026-10-22, read-only, unless noted.

| Resource | Value | Notes |
|---|---|---|
| Project ID | `misfitai-512403` | the default gcloud project for the Phase 2 developer |
| Vertex AI region | `us-central1` | `GOOGLE_CLOUD_LOCATION`; the Vertex endpoint is `https://us-central1-aiplatform.googleapis.com/v1/...` |
| GCS bucket (development) | `misfitai-dev-images-2026` | **`us-east1`** (regional), Standard class, uniform access **on**, public access prevention **enforced**, **7-day soft delete**, no versioning or lifecycle rules. Empty after the integration tests |
| Service account (development storage signing) | `misfitai-dev-storage@misfitai-512403.iam.gserviceaccount.com` | display name "MisfitAI Development Storage", **no user-managed keys**. Its only permission is `roles/storage.objectViewer` on the development bucket |
| Production bucket | none | design doc: `misfit-prod-media` in `us-central1` |
| Production runtime identity | none | the runbook's `misfit-heroku` service account **does not exist** |

**Models** (defaults in `vertex.rb`; `.env.example` sets the same values):

| Setting | Model | Status (2026-10-22) |
|---|---|---|
| `VERTEX_VISION_MODEL`, `VERTEX_TEXT_MODEL`, `GROUNDED_MODEL` | `gemini-2.5-flash` | GA in `us-central1`; used in integration checks 3 and 4 |
| `GARMENT_IMAGE_MODEL` | `gemini-2.5-flash-image` | GA on Vertex; used in check 5. Vertex lists a **retirement date of March 15, 2027**. (The Gemini Developer API, not Vertex, lists a shutdown of October 2, 2026; Vertex still served the model on 2026-10-22) |
| `IMAGEN_MODEL` | `imagen-4.0-fast-generate-001` | **returns 404 for this project.** Google's release notes (March 24, 2026) list the Imagen GA endpoints as discontinued. Only the Phase 4 avatar kind still reads this setting |
| `OUTFIT_SUBJECT_MODEL` | `imagen-3.0-capability-001` | **404** in the metadata check; on the discontinued list (Phase 4) |
| `OUTFIT_GEMINI_IMAGE_MODEL` | `gemini-2.5-flash-image` | GA (Phase 4 outfit preview) |
| `RANKING_MODEL` | `semantic-ranker-default@latest` | Discovery Engine; not used in Phase 2; not verified |

**APIs:**

| API | State | Needed for |
|---|---|---|
| `aiplatform.googleapis.com` (Vertex AI) | enabled | all AI calls |
| `storage.googleapis.com` (plus `storage-api`, `storage-component`) | enabled | GCS |
| `iamcredentials.googleapis.com` (IAM Credentials) | **enabled 2026-10-22** | keyless signing (`signBlob`) |
| `discoveryengine.googleapis.com` | **not verified** | `grounded_text` and `rank` (Phase 3 and 4) |

**IAM:** the least-privilege setup from Stage B.

| Grant | Where | Who |
|---|---|---|
| `roles/storage.objectViewer` | bucket `misfitai-dev-images-2026` only | `serviceAccount:misfitai-dev-storage@…` |
| `roles/iam.serviceAccountTokenCreator` | service account `misfitai-dev-storage@…` only | `user:mb5644@columbia.edu` (the Phase 2 developer) |
| Default bucket roles (`legacyBucketOwner`, `legacyObjectOwner`, readers) | the bucket | project owners, editors and viewers (Google's defaults for a new bucket) |

The project-level IAM policy has 2 bindings, and the Phase 2 developer is a project **Owner**. No project-wide role was granted for storage or signing.

---

## C. Authentication

### Application Default Credentials (ADC)

ADC is Google's standard way for client libraries to find credentials without a key in the code. Locally it is usually the file written by `gcloud auth application-default login`. That file holds a refresh token for **your own Google account**.

MisfitAI uses ADC in two places:

1. **Vertex AI (`Ai::GoogleToken`):**
   - If `GOOGLE_SERVICE_ACCOUNT_JSON` is set and not blank, it uses that service-account key. This is the production path in the design doc.
   - If it is blank or absent, it uses `Google::Auth.get_application_default`, that is, your ADC.
   - Failures raise `Ai::GoogleToken::CredentialsError`, which names the credential source but never the token or key.
   - The token is cached until about 60 seconds before it expires.
2. **GCS (`config/storage.yml`, `:google` service):**
   - If `GOOGLE_SERVICE_ACCOUNT_JSON` is set and not blank, it becomes the storage client's credentials.
   - If it is blank or absent, the `credentials` setting is left out, and `google-cloud-storage` falls back to its default lookup: its own environment variables (`STORAGE_*`, `GOOGLE_CLOUD_CREDENTIALS*`, `GCLOUD_KEYFILE*`), then `~/.config/gcloud/application_default_credentials.json`, then application-default discovery.

> If you ever set `GOOGLE_CLOUD_CREDENTIALS` or `STORAGE_CREDENTIALS` in your shell, `google-cloud-storage` uses them **before** your ADC.

### Local authentication for a new developer (ordinary setup)

```bash
gcloud auth login                                        # your Google account, for gcloud itself
gcloud config set project misfitai-512403
gcloud auth application-default login                    # writes your ADC file (no key is created)
gcloud auth application-default set-quota-project misfitai-512403
```

Check, without making any AI call:

```bash
gcloud config get-value project                          # misfitai-512403
ls ~/.config/gcloud/application_default_credentials.json # exists
```

The Phase 2 Vertex calls worked with ADC and **without** the app sending an `x-goog-user-project` header. If you get a 403 asking for a quota project, run the `set-quota-project` command above.

### Permissions a developer needs (granted by an administrator)

| To do | Needs | Notes |
|---|---|---|
| Run real Vertex AI calls | `roles/aiplatform.user` on the project (or a broader role) | the Phase 2 developer had it through Owner; a new teammate needs it granted |
| Read, write and delete objects in the development bucket from runner scripts (with your ADC) | object create, get, delete and list on `misfitai-dev-images-2026`, for example `roles/storage.objectAdmin` **on that bucket** | project Owners and Editors get it from the bucket's default legacy roles; others need a bucket-scoped grant |
| Generate signed URLs with keyless signing | `roles/iam.serviceAccountTokenCreator` on `misfitai-dev-storage@…` **only** | grant it to each developer separately; never at project level |

### Your credentials versus the storage service account

- **Your ADC** (`authorized_user`) authenticates **your** calls: Vertex requests, GCS uploads, downloads and deletes, and the `signBlob` request itself.
- **`misfitai-dev-storage`** is used only as the **signing identity**. A signed URL lets whoever holds it act *as that service account* for one GET of one object, until it expires. That is why the account has read-only object access on one bucket and nothing else. It has **no key**; nothing can sign as it except through IAM.

### Signed URLs and keyless IAM signing

GCS needs a signature made with a private key. A user ADC login has no private key, so with your ADC alone `blob.url` raises **`Google::Cloud::Storage::SignedUrlUnavailable`**. That was the first check 6 result.

**Keyless signing** (Active Storage's `iam: true` mode) avoids needing a key:

1. Set `GCS_SIGNING_SERVICE_ACCOUNT=misfitai-dev-storage@misfitai-512403.iam.gserviceaccount.com`. `config/storage.yml` then adds `iam: true` and `gsa_email:` to the `:google` service.
2. When a URL is needed, `ActiveStorage::Service::GCSService#private_url` calls `file.signed_url`, passing `issuer: gsa_email` and a `signer`.
3. That signer calls the **IAM Credentials API** (`projects/-/serviceAccounts/<gsa_email>:signBlob`), authenticated with `Google::Auth.get_application_default`, which is your ADC locally.
4. Google signs the URL with the service account's system-managed key. The URL's `GoogleAccessId` is the service account, and it expires after the requested time (Active Storage's default; production sets 1 hour).

**Why the IAM Credentials API is needed:** `signBlob` is an IAM Credentials API method. With the API disabled, keyless signing cannot work. Calling it also needs `iam.serviceAccounts.signBlob` on the target service account, which `roles/iam.serviceAccountTokenCreator` provides.

**Behaviour when keys and signing are combined:**

| `GOOGLE_SERVICE_ACCOUNT_JSON` | `GCS_SIGNING_SERVICE_ACCOUNT` | Storage client uses | Signed URLs |
|---|---|---|---|
| blank or absent | blank or absent | your ADC | fail with `SignedUrlUnavailable` (no private key) |
| key | blank or absent | the key | signed locally with the key's private key |
| blank or absent | set | your ADC | IAM `signBlob` as the signing account, using your ADC |
| key | set | the key | IAM `signBlob` **using ADC, not the key**. Don't use this combination where there is no ADC (Heroku) |

**Cost of keyless signing:** every signed URL is one `signBlob` request; check 6 measured 383 ms. Active Storage does not cache signed URLs, so each image redirect makes one call. That is fine for development, but a production consideration.

### Administrator-only IAM setup (reference; already done for the development environment)

These commands change cloud resources. Run them only as a project administrator, after agreeing them with the team.

```bash
# 1. Signing service account, with no key
gcloud iam service-accounts create misfitai-dev-storage \
  --project misfitai-512403 --display-name "MisfitAI Development Storage"

# 2. Read-only object access on the development bucket only
#    (Phase 2 did this through the Storage JSON API, because `gcloud storage` was broken on that machine)
gcloud storage buckets add-iam-policy-binding gs://misfitai-dev-images-2026 \
  --member="serviceAccount:misfitai-dev-storage@misfitai-512403.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"

# 3. Allow one developer to sign as that service account (repeat per developer)
gcloud iam service-accounts add-iam-policy-binding \
  misfitai-dev-storage@misfitai-512403.iam.gserviceaccount.com --project misfitai-512403 \
  --member="user:<developer-email>" --role="roles/iam.serviceAccountTokenCreator"

# 4. Enable the IAM Credentials API
gcloud services enable iamcredentials.googleapis.com --project misfitai-512403

# Optional: give a developer Vertex access
gcloud projects add-iam-policy-binding misfitai-512403 \
  --member="user:<developer-email>" --role="roles/aiplatform.user"
```

IAM changes can take several minutes to take effect. In Phase 2, the first `signBlob` call less than two minutes after the grants was denied, and an identical retry about nine minutes later worked.

---

## D. Environment variables

Development and test load `.env` through `dotenv-rails`; copy `.env.example` to `.env`. **Variables already set in your shell or process override `.env`**, which is how one test process can use real services while `.env` keeps `AI_ADAPTER=fake`.

### Google Cloud and AI variables read by the code

| Variable | Purpose | Example / default | Required? | When to set |
|---|---|---|---|---|
| `AI_ADAPTER` | Chooses the AI adapter. **Only the exact value `fake` gives the fake adapter**; anything else, or unset, means real Vertex | `.env.example`: `fake` | **Always set it explicitly** | `fake` for normal development and tests; `vertex` only in a process you mean to make billed calls |
| `GOOGLE_CLOUD_PROJECT` | Project for Vertex URLs and the GCS client | `misfitai-512403` | Required for real Vertex and GCS | Real-service runs and production. **Blank in `.env.example`; a blank value produces broken Vertex URLs (`projects//…`)** |
| `GOOGLE_CLOUD_LOCATION` | Vertex region | `us-central1` (default) | Optional | Change only if a model is not available in `us-central1` |
| `GOOGLE_CLOUD_PROJECT_NUMBER` | Discovery Engine grounded-generation URL | numeric project number | Not used in Phase 2 | Phase 3 and 4 (`grounded_text`) |
| `GOOGLE_SERVICE_ACCOUNT_JSON` | A service-account key as **single-line JSON**, for Vertex and GCS | blank locally | Optional locally; the planned production credential | Production (not set up). **Leave blank locally** to use ADC |
| `GCS_BUCKET` | Bucket for the `:google` storage service | `misfitai-dev-images-2026` (development) | Required wherever `:google` is used | Production, or local GCS runner scripts |
| `GCS_SIGNING_SERVICE_ACCOUNT` | Turns on keyless IAM URL signing (`iam: true`, `gsa_email`) | `misfitai-dev-storage@misfitai-512403.iam.gserviceaccount.com` | Optional | Local GCS tests that need signed URLs. Production: a separate decision |
| `VERTEX_VISION_MODEL` | Model for photo and receipt extraction | `gemini-2.5-flash` | Optional | Only to change model |
| `VERTEX_TEXT_MODEL` | Model for `generate_text` | `gemini-2.5-flash` | Optional | Not used by Phase 2 features |
| `GROUNDED_MODEL` | Discovery Engine grounded generation | `gemini-2.5-flash` | Optional | Phase 3 and 4 |
| `GARMENT_IMAGE_MODEL` | Model for garment and draft product images (`kind: :garment_image`). `gemini-*` uses `generateContent`; `imagen-*` uses the old Imagen `:predict` request | `gemini-2.5-flash-image` | Optional | Change before `gemini-2.5-flash-image` retires (March 15, 2027) |
| `IMAGEN_MODEL` | Imagen model for **non-garment** image kinds (the Phase 4 avatar) | `imagen-4.0-fast-generate-001` (discontinued, returns 404) | Optional | Phase 4 must replace it |
| `OUTFIT_SUBJECT_MODEL` / `OUTFIT_GEMINI_IMAGE_MODEL` | Phase 4 outfit preview | `imagen-3.0-capability-001` (404) / `gemini-2.5-flash-image` | Optional | Phase 4 |
| `RANKING_MODEL` | Discovery Engine ranking | `semantic-ranker-default@latest` | Optional | Search re-ranking stretch (not built) |
| `AI_IMAGE_GEN_ENABLED` | Kill switch for every image kind. `false` raises `Ai::DisabledError` before any request; garments keep the placeholder | `true` | Optional | Set `false` to stop image spend immediately |
| `AI_DAILY_IMAGE_LIMIT` | Per-user daily cap on successful images | `40` | Optional | Lower it for local real-service testing |
| `AI_DAILY_VISION_LIMIT` | Per-user daily cap on vision calls (photo and receipt) | `30` | Optional | Lower it for testing |
| `AI_DAILY_BUDGET_CENTS` | Global daily budget, compared with the sum of `ai_calls.est_cost_cents` (an **estimate**, see [F](#f-costs)) | `1000` | Optional | Lower it for testing |
| `GARMENT_ASSET_SIZE` | Side of the normalized square JPEG | `512` | Optional | Rarely |
| `VISION_MAX_GARMENT_IMAGES` | Maximum drafts per photo (clamped to 1..20) | `6` | Optional | Rarely |
| `HEIC_SUPPORTED` | Accept HEIC uploads | `true` | Optional | Set `false` where libvips lacks HEIF support |
| `ANALYTICS_INTERNAL_API_KEY` | Protects `GET /admin/ai_usage` (`X-Analytics-Key` header) | random secret | Needed for `/admin/ai_usage` | Production; locally only to view usage |
| `FEATURE_PHOTO_INTAKE`, `FEATURE_RECEIPTS` | Override `config/features.yml` (both default `true`) | `true` / `false` | Optional | Switching off an intake path |

**Not Google Cloud but related:** `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` (Google sign-in, Devise and OmniAuth) and `SERPAPI_KEY` (garment search).

**Listed in `.env.example` but not read by any code** (checked): `AVATAR_IMAGEN_MODEL`, `IMAGE_GEN_SPACING_SEC`, `IMAGE_GEN_MAX_PROMPT_CHARS`, `SEARCH_RERANK_ENABLED`, `RECEIPT_LLM_CLEANUP`, `AVATAR_LOG_PROMPT_PREVIEW`, `APP_HOST`.

### Switching modes

- **Fake versus real AI:** keep `AI_ADAPTER=fake` in `.env`. For a real run, set it only for that process:
  ```bash
  AI_ADAPTER=vertex GOOGLE_CLOUD_PROJECT=misfitai-512403 bin/rails runner path/to/script.rb
  ```
  `Ai::Client.current` is memoized per process outside tests, so **restart the server or console after changing the adapter**.
- **Local disk versus GCS:** set per environment in `config/environments/*.rb`, not by environment variable. Development always uses local disk. To use the development bucket, fetch the `:google` service in a runner script (`ActiveStorage::Blob.services.fetch(:google)`, or `create_and_upload!(service_name: "google")`) with `GCS_BUCKET` and `GOOGLE_CLOUD_PROJECT` set for that process.

---

## E. Developer workflows

Real-service runs cost money and can create cloud objects. Prefer the fake adapter and local disk, and when you do call real services, make **one** call at a time with tight caps.

### 1. Normal development: fake AI and local storage

```bash
cp .env.example .env          # once; keep AI_ADAPTER=fake and GOOGLE_SERVICE_ACCOUNT_JSON blank
bin/setup                     # or: bundle install && bin/rails db:prepare
bin/rails db:seed             # demo@misfit.ai with a 15-item wardrobe (local images)
bin/dev                       # Rails and Tailwind; jobs run in-process
```

The tests always use the fake adapter (Cucumber forces it, RSpec forces it per example) and WebMock blocks the network:

```bash
AI_ADAPTER=fake COVERAGE=true bundle exec rspec
bundle exec cucumber
```

### 2. Testing real Vertex AI locally

1. Authenticate with ADC ([C](#c-authentication)) and make sure your account has `roles/aiplatform.user`.
2. Lower the caps and set real mode **only for one process**. The safest way is a runner script that makes exactly one call:
   ```bash
   AI_ADAPTER=vertex GOOGLE_CLOUD_PROJECT=misfitai-512403 \
   AI_DAILY_IMAGE_LIMIT=3 AI_DAILY_VISION_LIMIT=3 AI_DAILY_BUDGET_CENTS=50 \
     bin/rails runner path/to/one_call.rb
   ```
   Inside the script, call the application's own code, for example:
   - `Ai::Client.current.generate_json(kind: :garment_extraction, prompt: Wardrobe::PhotoIntake::Prompts::EXTRACTION, schema: Wardrobe::PhotoIntake::Prompts::GARMENT_SCHEMA, images: [ Wardrobe::PhotoIntake::ImagePreparer.call(path) ], user: nil)`;
   - or `Receipts::VisionParser.call(image:, user: nil)`.
3. Running the whole app against Vertex (`AI_ADAPTER=vertex GOOGLE_CLOUD_PROJECT=misfitai-512403 bin/dev`) works, but every photo, receipt image and "Generate a product image" checkbox is then a billed call. To stop image spend in that session, add `AI_IMAGE_GEN_ENABLED=false`.
4. Check the `ai_calls` rows (`bin/rails runner 'pp AiCall.order(:created_at).last(5)'`) or `GET /admin/ai_usage` with `X-Analytics-Key`.

### 3. Using the development GCS bucket

Local development stores files on disk. To exercise GCS, use a runner script with the `:google` service, and keep everything under `integration-checks/`:

```bash
GOOGLE_CLOUD_PROJECT=misfitai-512403 GCS_BUCKET=misfitai-dev-images-2026 \
GCS_SIGNING_SERVICE_ACCOUNT=misfitai-dev-storage@misfitai-512403.iam.gserviceaccount.com \
  bin/rails runner path/to/gcs_check.rb
```

The script should:
1. Generate a unique key, for example `integration-checks/<name>-<UTC timestamp>-<random>.jpg`, and confirm it does not exist (`service.exist?(key)`).
2. Upload with `ActiveStorage::Blob.create_and_upload!(io:, filename:, content_type:, key:, service_name: "google")`.
3. Verify the upload: `blob.download`, `service.download_chunk`, and `blob.url(expires_in: 5.minutes)` followed by one GET.
4. **Always** clean up in an `ensure` block: `blob.purge`, then delete the key and the blob row if they are still there.
5. **Never print `blob.url`**: it is a bearer link.

Remember that the bucket's **7-day soft delete** keeps a recoverable copy of anything you delete.

### 4. Verifying image generation and storage

- **Image generation (Vertex):** one `Ai::Client.current.generate_image(kind: :garment_image, prompt: Wardrobe::Prompts.garment_image(Garment.new(name: "Plain White T-Shirt", category: "top", color_primary: "white", material: "cotton")), user: nil)` returns a validated `Ai::Image`. `Media::ImageNormalizer.to_square_jpeg(image.bytes, size: 512)` gives the stored form. The unsaved `Garment.new` only builds the prompt. Each call costs about 4¢ (estimated).
- **The whole job flow, locally on disk:** with real Vertex enabled, add a garment with "Generate a product image" checked in the app. The job runs in-process, attaches a 512×512 JPEG and broadcasts the card. This flow has been tested with stubbed HTTP but **not end to end against real Vertex** (see [G](#g-known-limitations)).
- **Storage:** see workflow 3.

### 5. Troubleshooting

| Symptom | Likely cause | What to do |
|---|---|---|
| `Ai::GoogleToken::CredentialsError: No Google credentials …` | No ADC and no key | `gcloud auth application-default login` |
| `CredentialsError … (Signet::AuthorizationError)` | ADC login expired or revoked | Run `gcloud auth application-default login` again |
| `Ai::AuthenticationError: Vertex HTTP 403 PERMISSION_DENIED` | Missing `roles/aiplatform.user`, the API is disabled, or a quota project is needed | Check your role; run `gcloud auth application-default set-quota-project misfitai-512403` |
| `Ai::NotFoundError: Vertex HTTP 404 NOT_FOUND` | Wrong or retired model, wrong region, or a **blank `GOOGLE_CLOUD_PROJECT`** (the URL becomes `projects//…`) | Set `GOOGLE_CLOUD_PROJECT`; check the model ID; Imagen models return 404 for this project |
| `Ai::InvalidRequestError: Vertex HTTP 400 …` | Request or schema rejected | Check the schema; the exception message deliberately leaves out Google's text |
| `Ai::InvalidResponseError` on an image | A text-only refusal, no image, or invalid image data | The garment becomes `failed` with "Retry image"; check the prompt |
| `Ai::DisabledError` / `Ai::QuotaExceededError` | Kill switch, a daily cap, or the budget | Check `AI_IMAGE_GEN_ENABLED`, the caps, and today's `ai_calls` |
| `Google::Cloud::Storage::SignedUrlUnavailable` | No private key and no `GCS_SIGNING_SERVICE_ACCOUNT` | Set `GCS_SIGNING_SERVICE_ACCOUNT` (keyless signing) |
| `Google::Apis::ClientError: PERMISSION_DENIED … iam.serviceAccounts.signBlob` | No Token Creator on the service account, the IAM Credentials API is disabled, or a **recent grant still propagating** | Check the service account's policy and the API; wait several minutes after a grant before retrying once |
| GCS `403` on upload or delete | No object access on the bucket for your account | An administrator grants bucket-scoped object access |
| GCS client error mentioning the project | `GOOGLE_CLOUD_PROJECT` is blank and the credentials do not supply one | Set `GOOGLE_CLOUD_PROJECT` for the process |
| `gcloud storage …` fails with `No module named 'grpc'` | A broken local gcloud Python environment (seen in Phase 2) | `gcloud components reinstall`, or use the Storage JSON API or Ruby client |

To confirm which account your ADC uses without printing a token, compare `gcloud config get-value account` with the account in your ADC login. Phase 2 checked this with Google's `tokeninfo` endpoint.

---

## F. Costs

**Verified observations** come from `ai_calls` rows and API responses during the Phase 2 integration tests (2026-10-21 and 22). **Estimates** use list prices. **GCP Billing has not been checked yet** (handoff, check 7), so no actual charge has been confirmed.

| Operation | Measured (verified) | Internal estimate (`config/ai_pricing.yml`) | List-price calculation (estimate) |
|---|---|---|---|
| Garment extraction, 1 photo (`gemini-2.5-flash`) | 2,959 input + 169 output tokens; 2.6 s | 0.5¢ | ≈0.13¢, from Gemini 2.5 Flash text and image-input rates recalled from memory (**not verified against the Vertex price table**) |
| Receipt extraction, 1 image (`gemini-2.5-flash`) | 1,918 input + 285 output tokens; 3.1 s | 0.5¢ | ≈0.13¢ (same caveat) |
| Garment image, 1024×1024 (`gemini-2.5-flash-image`) | 74 input; 1,309 output tokens, **1,290 of them image tokens**; 6.1 s | **4.0¢** | ≈3.87¢ from Google's published **$30 per million image-output tokens / $0.039 per image** (Google Developers Blog and the Gemini API pricing page; the Vertex price table could not be read) |
| Failed or blocked AI attempt | recorded at 0¢ | 0¢ | **The provider may still charge** for some failures (for example a blocked prompt's input tokens) |
| Imagen 404 | no image produced | 0¢ | a 404 is not expected to be billed |
| `signBlob` (IAM Credentials) | 383 ms per URL | — | not known to be charged (not verified) |
| GCS: one 26 KB object, upload, read, delete, list | about 15 requests | — | well under $0.0001; storage of soft-deleted copies for 7 days rounds to $0.00 |
| SerpAPI garment search | 3 searches used (one timed out) | — | the free plan allows 250 searches a month |

**Billing points to keep in mind:**
- `AI_DAILY_BUDGET_CENTS` is enforced against **estimates**. At 4.0¢ per image, a 1000¢ budget allows about 250 images a day across the app, shared with vision calls. A photo intake with 6 draft images costs about 24¢.
- **Retries multiply cost:** a transient failure is retried up to 3 times per job, and "Retry image" starts a new billed call.
- **Keep real-service tests to one call,** with lowered caps, and check `ai_calls` afterwards.
- **GCP Billing Reports is authoritative.** Check it, grouped by service, after real usage. `/admin/ai_usage` reports today's estimated spend per kind.

---

## G. Known limitations

**Verified locally only:** the six integration checks passed **locally**. Nothing has been deployed, and **GCP Billing verification is still outstanding** (handoff check 7).

**Development is not production:**
- **Development jobs run in-process:** no Active Job queue adapter is set in development, so Rails' default runs jobs in threads inside the server process.
- **Solid Queue's production settings don't apply locally:** the `limits_concurrency` limits, the single-threaded `ai_images` worker in `config/queue.yml`, and the recurring tasks in `config/recurring.yml` (including `purge_stale_intake_drafts`, daily at 4am, production only). Concurrency behaviour seen locally is therefore not evidence for production.

**Still untested:**
- **Browser redirects through Rails:** `rails_blob_path` / `rails_representation_path` → `blob.url` → signed GCS URL, in a real page with the CSP. Check 6 signed and fetched a URL directly, not through the app's routes.
- **Image variants stored in GCS** (`thumb` 256 fill, `card` 512 limit): generated on first request, which uploads variant blobs.
- **The draft-to-garment blob hand-over** on photo-intake commit with GCS storage.
- **The full image-generation job against real Vertex:** `GenerateGarmentImageJob` and `GenerateDraftImageJob` were tested with stubbed HTTP; check 5 called the adapter directly.
- **Real-world safety filtering** for garment images; one benign prompt was used.
- **Real receipt photos** (blur, glare, faded paper), **real retailer PDFs**, and **HEIC from phones.**
- **Production authentication and storage:** no production bucket, no runtime identity, no credentials on Heroku. Heroku has no ADC, so keyless signing there would still need *some* credential to call `signBlob`. The options are a service-account key (the design doc's approach), keyless signing with another credential, or proxy mode (`rails_storage_proxy`, no signed URLs). **Undecided.**
- **Deployment:** Heroku, `bin/ai_smoke` on Heroku, and the GCP billing check (handoff checks 7 and 8, and the section 17 exit gate) are still open.

**Known issues:**
- **`bin/ai_smoke` is not expected to pass as it stands.** It runs every kind in `Ai::Kinds::ALL`, in order, and stops at the first failure:
  - its **first three kinds** (`outfit_explanation`, `receipt_structuring`, `search_rank`) call **Discovery Engine**, which has not been verified (the API's status is unknown, and `GOOGLE_CLOUD_PROJECT_NUMBER` is blank locally);
  - `avatar_portrait` uses `IMAGEN_MODEL`, which returns 404;
  - `outfit_preview_subject` uses `imagen-3.0-capability-001`, which also returned 404.
- **`Ai::Client::Vertex#generate_image_multimodal`** (Phase 4 outfit preview) does **not** check the image kill switch, although the fake adapter does.
- **Signed URLs aren't cached:** keyless signing adds one `signBlob` call (about 0.4 s) to every image redirect.
- **`gemini-2.5-flash-image` retires on March 15, 2027** (Vertex).
- **`input_chars` in `ai_calls`** counts base64 image data for vision calls, so it is not a measure of text size.
- **The development bucket is in `us-east1`,** while Vertex runs in `us-central1` and the design doc planned `us-central1` buckets. This is harmless for development.

---

## H. Handoff guidance

**What you can reuse:**
- `Ai::Client.current` and its contract (`generate_json`, `generate_text`, `generate_image`, …). The kill switch, quotas, `ai_calls` logging, typed errors and the fake adapter all come for free. Add new AI features as new `kind`s (also add them to `config/ai_pricing.yml` and `spec/fixtures/ai/`).
- `GARMENT_IMAGE_MODEL` and the Gemini image path in `generate_image`, for any text-to-image kind. Phase 4's avatar should move off `IMAGEN_MODEL` in the same way.
- `Ai::GoogleToken`, which uses a service-account key when set and ADC otherwise. This works unchanged for new Vertex calls.
- The `:google` storage service with keyless signing for local GCS testing, plus the development bucket and `misfitai-dev-storage` service account.
- The runner-script pattern for real-service checks: one call, variables set only for that process, and an `ensure` cleanup.

**Before building on Google Cloud:**
1. Get ADC working and your own grants: `roles/aiplatform.user`, bucket object access, and Token Creator on `misfitai-dev-storage` if you need signed URLs. Ask the project administrator; don't widen anyone else's roles.
2. Keep `AI_ADAPTER=fake` in `.env` and make real calls only from a single process.
3. **Phase 4:**
   - replace `IMAGEN_MODEL` for avatars;
   - replace the Imagen `generate_image_with_subject` strategy (`imagen-3.0-capability-001` is discontinued; the Gemini multimodal strategy is the remaining option, and `gemini-2.5-flash-image` accepts at most 3 input images);
   - add the kill-switch check to `generate_image_multimodal`;
   - fix `bin/ai_smoke`.
4. **Before deploying:**
   - decide production storage authentication (a key, keyless signing, or proxy mode);
   - create a production bucket and runtime identity;
   - set `GOOGLE_CLOUD_PROJECT`, `GCS_BUCKET` and the credentials on Heroku;
   - test browser redirects and variants on GCS;
   - check GCP Billing.
5. **Provisioning scripts:** `script/provision/gcp.sh` and `script/provision/heroku.sh` are **placeholders** that only print a message. Nothing in this repository provisions Google Cloud or Heroku automatically. `docs/runbook.md` lists the real development resources and labels the original Phase 1 plan (a `misfit-heroku` service account and a `us-central1` bucket) as never provisioned.

**Where to look:**
- **Integration test history and decisions:** [`docs/handoff/phase-2.md`](handoff/phase-2.md), sections 5, 7, 13 and 14.
- **Original design:** [`docs/ruby_rewrite_design_doc_v2.md`](ruby_rewrite_design_doc_v2.md), sections 3 (AI) and 9 (deployment and config).
- **Code:**
  - `app/services/ai/client.rb`, `app/services/ai/client/vertex.rb`, `app/services/ai/google_token.rb`;
  - `config/storage.yml`, `config/ai_pricing.yml`;
  - `app/jobs/wardrobe/generate_garment_image_job.rb`.
