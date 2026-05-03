# ==============================================================================
# Cloud Build Triggers
# Factor 5: Build/Release/Run - Automated CI/CD pipeline
# Each repo has its own trigger — push to main = auto build and deploy
# ==============================================================================

# Service account for Cloud Build triggers (required by org policy)
resource "google_service_account" "cloudbuild_sa" {
  account_id   = "medlab-cloudbuild"
  display_name = "Cloud Build Service Account"
  project      = var.project_id
}

# Grant Cloud Build SA necessary permissions
resource "google_project_iam_member" "cloudbuild_builder" {
  project = var.project_id
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${google_service_account.cloudbuild_sa.email}"
}

resource "google_project_iam_member" "cloudbuild_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.cloudbuild_sa.email}"
}

resource "google_project_iam_member" "cloudbuild_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cloudbuild_sa.email}"
}

resource "google_project_iam_member" "cloudbuild_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cloudbuild_sa.email}"
}

resource "google_project_iam_member" "cloudbuild_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloudbuild_sa.email}"
}

resource "google_project_iam_member" "cloudbuild_editor" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.cloudbuild_sa.email}"
}

resource "google_project_iam_member" "cloudbuild_iam_admin" {
  project = var.project_id
  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${google_service_account.cloudbuild_sa.email}"
}

resource "google_project_iam_member" "cloudbuild_service_usage" {
  project = var.project_id
  role    = "roles/serviceusage.serviceUsageAdmin"
  member  = "serviceAccount:${google_service_account.cloudbuild_sa.email}"
}

# Infrastructure trigger — runs terraform apply on push
resource "google_cloudbuild_trigger" "infrastructure" {
  name            = "medlab-infrastructure-trigger"
  project         = var.project_id
  service_account = google_service_account.cloudbuild_sa.id

  github {
    owner = "medlab-analyzer-gcp"
    name  = "medlab-infrastructure"
    push {
      branch = "^main$"
    }
  }

  filename = "cloudbuild.yaml"
}

# Report service trigger
resource "google_cloudbuild_trigger" "report_service" {
  name            = "medlab-report-service-trigger"
  project         = var.project_id
  service_account = google_service_account.cloudbuild_sa.id

  github {
    owner = "medlab-analyzer-gcp"
    name  = "medlab-report-service"
    push {
      branch = "^main$"
    }
  }

  filename = "cloudbuild.yaml"
}

# Analysis service trigger
resource "google_cloudbuild_trigger" "analysis_service" {
  name            = "medlab-analysis-service-trigger"
  project         = var.project_id
  service_account = google_service_account.cloudbuild_sa.id

  github {
    owner = "medlab-analyzer-gcp"
    name  = "medlab-analysis-service"
    push {
      branch = "^main$"
    }
  }

  filename = "cloudbuild.yaml"
}

# WS service trigger
resource "google_cloudbuild_trigger" "ws_service" {
  name            = "medlab-ws-service-trigger"
  project         = var.project_id
  service_account = google_service_account.cloudbuild_sa.id

  github {
    owner = "medlab-analyzer-gcp"
    name  = "medlab-ws-service"
    push {
      branch = "^main$"
    }
  }

  filename = "cloudbuild.yaml"
}

# Frontend trigger
resource "google_cloudbuild_trigger" "frontend" {
  name            = "medlab-frontend-trigger"
  project         = var.project_id
  service_account = google_service_account.cloudbuild_sa.id

  github {
    owner = "medlab-analyzer-gcp"
    name  = "medlab-frontend"
    push {
      branch = "^main$"
    }
  }

  filename = "cloudbuild.yaml"
}
