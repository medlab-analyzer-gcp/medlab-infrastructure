# ==============================================================================
# Cloud Build Triggers
# Factor 5: Build/Release/Run - Automated CI/CD pipeline
# Each repo has its own trigger — push to main = auto build and deploy
# ==============================================================================

# Infrastructure trigger — runs terraform apply on push
resource "google_cloudbuild_trigger" "infrastructure" {
  name        = "medlab-infrastructure-trigger"
  description = "Runs terraform apply when infrastructure repo is updated"
  location    = var.region

  github {
    owner = "medlab-analyzer-gcp"
    name  = "medlab-infrastructure"
    push {
      branch = "^main$"
    }
  }

  filename = "cloudbuild.yaml"
}

# Report service trigger — builds and deploys report-service on push
resource "google_cloudbuild_trigger" "report_service" {
  name        = "medlab-report-service-trigger"
  description = "Builds and deploys report-service when code is pushed"
  location    = var.region

  github {
    owner = "medlab-analyzer-gcp"
    name  = "medlab-report-service"
    push {
      branch = "^main$"
    }
  }

  filename = "cloudbuild.yaml"
}

# Analysis service trigger — builds and deploys analysis-service on push
resource "google_cloudbuild_trigger" "analysis_service" {
  name        = "medlab-analysis-service-trigger"
  description = "Builds and deploys analysis-service when code is pushed"
  location    = var.region

  github {
    owner = "medlab-analyzer-gcp"
    name  = "medlab-analysis-service"
    push {
      branch = "^main$"
    }
  }

  filename = "cloudbuild.yaml"
}

# WS service trigger — builds and deploys ws-service on push
resource "google_cloudbuild_trigger" "ws_service" {
  name        = "medlab-ws-service-trigger"
  description = "Builds and deploys ws-service when code is pushed"
  location    = var.region

  github {
    owner = "medlab-analyzer-gcp"
    name  = "medlab-ws-service"
    push {
      branch = "^main$"
    }
  }

  filename = "cloudbuild.yaml"
}

# Frontend trigger — placeholder, frontend runs locally
resource "google_cloudbuild_trigger" "frontend" {
  name        = "medlab-frontend-trigger"
  description = "Triggered when frontend code is pushed"
  location    = var.region

  github {
    owner = "medlab-analyzer-gcp"
    name  = "medlab-frontend"
    push {
      branch = "^main$"
    }
  }

  filename = "cloudbuild.yaml"
}
