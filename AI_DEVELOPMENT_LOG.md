# AI Development Log - SWE455 Medical Lab Analyzer

|              |                                              |
| ------------ | -------------------------------------------- |
| **Students** | Budoor Basaleh, Aishah Algharib              |
| **Course**   | SWE455 - Cloud Applications Engineering      |
| **Term**     | 252 (Spring 2026)                            |
| **AI Tool**  | Claude Code (Claude Sonnet 4.6) by Anthropic |

---

## Prompt 1: GCP Deployment Setup

**User:**

```
Guide me with the commands to deploy the project to GCP.
I have gcloud, Terraform, Node.js, and Docker installed.
```

**AI Response:**

```
1. Enable required GCP APIs (Cloud Run, Firestore, Storage, Artifact Registry)
2. Create Artifact Registry repository for Docker images
3. Build Docker images for each service
4. Push images to Artifact Registry
5. Run terraform apply to provision infrastructure
6. Deploy services to Cloud Run
```

**Problems & Fixes:**

- `sed` not available in PowerShell → edited files directly
- Emoji characters broke PowerShell 5.1 parser → removed all emojis from scripts
- `npm ci --only=production` deprecated → changed to `npm ci --omit=dev`
- Missing `package-lock.json` → ran `npm install` in each service
- Terraform failed because images did not exist yet → fixed script order: build/push BEFORE terraform apply

---

## Prompt 2: Firebase Authentication

**User:**

```
Guide me through setting up Firebase for authentication.
Why are we using Firebase if this is a GCP project?
```

**AI Response:**

```
GCP does not have a built-in authentication service for end users.
Firebase Auth is Google's recommended solution — it is a Google product
that runs on Google infrastructure. It provides email/password login
and JWT tokens in minutes, which services use to verify user identity.
```

---

## Prompt 3: Debugging Frontend Issues

**User:**

```
Why is the history page showing Invalid Date and wrong status?
Why after analyzing does the Analyze button still show?
```

**AI Response:**

```
Issues found:
1. Frontend used report.uploadTimestamp but service returns report.uploadedAt
   Fix: corrected field name
2. Frontend compared status === "UPLOADED" but service stores "uploaded"
   Fix: used .toLowerCase()
3. Firestore .update() was silently failing to overwrite status field
   Fix: changed to .set({ merge: true })
4. Missing CORS headers — browsers block cross-origin requests by default
   Fix: added Access-Control-Allow-Origin: * middleware to all services
```

---

## Prompt 4: Pub/Sub Event-Driven Architecture

**User:**

```
I want to add Pub/Sub. When user enters values manually and clicks Analyze,
publish to Pub/Sub instead of calling analysis service directly.

```

**AI Response:**

```
Yes. Benefits:
- If analysis-service is down, messages queue and retry automatically
- Direct HTTP call = request lost on failure
- Pub/Sub decouples services — neither knows about the other directly
- Push subscription: Pub/Sub delivers HTTP POST to analysis-service automatically
- Prepares architecture for future AI/OCR features

Architecture change:
Before: Frontend → analysis-service directly (tight coupling)
After:  Frontend → report-service → Pub/Sub → analysis-service (loose coupling)
```

---

## Prompt 5: WebSocket Real-Time Notifications

**User:**

```
I want real-time notifications when analysis is done using WebSocket.
How can we do that in a scalable way?
```

**AI Response:**

```
WebSocket scaling problem:
Cloud Run runs multiple instances. User A connects to Instance 1,
but analysis result arrives at Instance 2. Instance 2 cannot reach
User A's socket. Notification is lost.

Solution — Firestore onSnapshot:
Every ws-service instance independently subscribes to Firestore.
When analysis-service writes status="analyzed", ALL instances are
notified simultaneously by Google's infrastructure. Only the instance
holding the user's WebSocket connection pushes "analysis-done" to client.

This is Google's recommended pattern for WebSocket on Cloud Run.
WebSocket connects directly to ws-service URL, bypassing API Gateway
(GCP API Gateway is HTTP only and does not support WebSocket).
```

**Problems & Fixes:**

- Passing Socket object via React Router navigate state caused serialization error
  Fix: used socketManager.js module to store socket reference outside React state
- WebSocket was opening on every page load
  Fix: open socket only when user clicks Analyze, close after receiving result
- Race condition: "subscribed" emitted before Firestore stream was ready
  Fix: moved socket.emit("subscribed") inside first onSnapshot callback
- WebSocket connection timeout blocking the analysis submission
  Fix: made WebSocket non-blocking — analysis proceeds even if WS times out

---

## Prompt 6: Architecture Review and CI/CD

**User:**

```
Check all files for issues or cloud principle violations.
```

**AI Response:**

```
Scalability confirmation:
- Cloud Run: 0 to 100 instances auto-scaling
- Pub/Sub: unlimited throughput, guaranteed delivery
- Firestore: unlimited scale
- ws-service: scales horizontally via Firestore onSnapshot (no shared state between instances)
- API Gateway: Google-managed, no scaling concern
```

**Issues Found & Fixed:**

- cloudbuild.yaml missing ws-service steps → added build, push, deploy, health check
- deploy.sh missing ws-service → added build, push, deploy, health check
- destroy.sh missing ws-service → added to services and images arrays
- frontend/.env.example missing VITE_WS_SERVICE_URL → added

---

## Prompt 7: Deploy Script Design for Separate Service Repos

**User:**

```
We have separate repos for each service. The deploy script was trying to
build Docker images locally but the service code is not in the infrastructure repo.
How should the deploy script work?
```

**AI Response:**

```
Since each service has its own repo and its own cloudbuild.yaml, the deploy
script should not build Docker images at all. The correct flow is:

1. Enable GCP APIs
2. Create Terraform state bucket
3. Terraform apply — provisions all infrastructure with placeholder images
4. Trigger Cloud Build for each service repo — Cloud Build builds and deploys real images
5. Health checks

Docker build and push belong in each service's cloudbuild.yaml, not in the
infrastructure deploy script.
```

**Problems & Fixes:**

- Deploy script had Docker build, push, and Cloud Run deploy steps hardcoded to `./services/` paths that did not exist in the infrastructure repo → removed all Docker steps
- Chicken-and-egg problem: Terraform needs images to create Cloud Run, but images only exist after Cloud Build runs → solved with placeholder image `us-docker.pkg.dev/cloudrun/container/hello:latest` and `lifecycle { ignore_changes = [template[0].containers[0].image] }`

---

## Prompt 8: Artifact Registry Must Be in Terraform

**User:**

```
The Artifact Registry repository is being created by the deploy script manually.
Should it be in Terraform instead?
```

**AI Response:**

```
Yes. The professor's requirement says every cloud component must be provisioned
via Terraform. The deploy script creating the Artifact Registry repository manually
is a violation. It should be a google_artifact_registry_repository resource in
Terraform so it is created, managed, and destroyed by Terraform automatically.
```

**Problems & Fixes:**

- `google_artifact_registry_repository` resource added to `terraform/main.tf`
- Artifact Registry creation removed from `deploy.ps1` and `deploy.sh`
- On first run after this change, the repository already existed from a previous manual run — imported it into Terraform state with `terraform import`

---

## Prompt 9: Cloud Build Triggers in Terraform

**User:**

```
We have 5 GitHub repos. Each needs a Cloud Build trigger so that pushing to
main automatically builds and deploys. These triggers must be in Terraform.
```

**AI Response:**

```
Use google_cloudbuild_trigger with a github block for each repo:

resource "google_cloudbuild_trigger" "report_service" {
  name = "medlab-report-service-trigger"
  github {
    owner = "medlab-analyzer-gcp"
    name  = "medlab-report-service"
    push { branch = "^main$" }
  }
  filename = "cloudbuild.yaml"
}
```

**Problems & Fixes:**

- `google_cloudbuild_trigger` with `github` block returned `INVALID_ARGUMENT` — tried different `location` values (`us-central1`, `global`, none) → all failed
- Tried `null_resource` with `local-exec` using bash → failed on Windows (no `/bin/bash`)
- Tried `null_resource` with PowerShell and `gcloud builds triggers create github` → same `INVALID_ARGUMENT` error from the GCP API directly
- Root cause identified from GCP Console: **org policy requires a user-managed service account on every Cloud Build trigger**
- Fix: created `google_service_account.cloudbuild_sa` (`medlab-cloudbuild`) in Terraform, granted it 5 IAM roles (`cloudbuild.builds.builder`, `run.admin`, `iam.serviceAccountUser`, `artifactregistry.writer`, `logging.logWriter`), added `service_account = google_service_account.cloudbuild_sa.id` to every trigger → all 5 triggers created successfully

---

## Prompt 10: Pub/Sub Push Subscription IAM

**User:**

```
Will the Pub/Sub push subscription work as-is? It pushes to analysis-service
but I am not sure if Pub/Sub has permission to call it.
```

**AI Response:**

```
No. When Pub/Sub pushes to a Cloud Run service, it uses a Google-managed
service account: service-{PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com
This account needs roles/run.invoker on the analysis-service Cloud Run resource.
Without this binding, every push will return 403 Forbidden and the message
will be retried indefinitely.
```

**Fix:**

Added to `terraform/pubsub.tf`:
```hcl
resource "google_cloud_run_v2_service_iam_member" "pubsub_invoker" {
  name   = google_cloud_run_v2_service.analysis_service.name
  role   = "roles/run.invoker"
  member = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}
```

---

## Prompt 11: Cloud Build Service Account Missing Permissions for Terraform

**User:**

```
The infrastructure Cloud Build trigger runs terraform apply on every push,
but it keeps failing with 403 permission errors on different resources.
```

**AI Response:**

```
When Cloud Build runs terraform apply, it runs as the medlab-cloudbuild
service account — not as your personal GCP account. Your personal account
has Owner permissions so local runs always work, but Cloud Build only has
the permissions you explicitly grant it. Terraform needs broad permissions
to manage IAM bindings, enable APIs, create Cloud Run services, manage
Pub/Sub, logging sinks, and API Gateway.
```

**Problems & Fixes:**

- First run: 403 on IAM bindings → added `roles/resourcemanager.projectIamAdmin`
- Second run: 403 on listing services → added `roles/serviceusage.serviceUsageAdmin`
- Third run: 403 on Pub/Sub IAM → added `roles/pubsub.admin`
- Fourth run: 403 on logging sink → added `roles/logging.admin`
- Pattern identified: chasing individual roles one by one is not practical
- Final fix: granted `roles/owner` to the Cloud Build service account — Terraform can now manage all resources without permission errors

---

## Prompt 12: Signed URL Generation Failing for File Downloads

**User:**

```
After deploying, the history page shows "Failed to get file URL" with a 500
error when trying to download a report. The services are healthy and running.
```

**AI Response:**

```
The root cause is a missing IAM permission. Cloud Run generates temporary
signed URLs for files stored in Cloud Storage. Signing a URL requires the
service account to call the Google IAM signBlob API, which requires the
roles/iam.serviceAccountTokenCreator role on itself. Without it, the signing
step fails and returns a 500 error to the client.
```

**Problems & Fixes:**

- report-service returned 500 on GET /reports/{id}/file-url → traced to signed URL generation failure
- Added `roles/iam.serviceAccountTokenCreator` to the report-service service account in Terraform → file downloads working

---

## Ethical Use Statement

We used Claude Code as:

- **Implementation assistant** for GCP, Terraform, and cloud configurations
- **Debugging partner** for identifying root causes of errors
- **Learning tool** — we asked conceptual questions to understand WHY before implementing

All architectural decisions were made by us.
