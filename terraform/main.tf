# ==============================================================================
# GCP Project Configuration
# ==============================================================================

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

# GCP Provider Configuration
provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# ==============================================================================
# Enable Required GCP APIs
# ==============================================================================

locals {
  required_apis = [
    "run.googleapis.com",              # Cloud Run
    "storage.googleapis.com",          # Cloud Storage
    "firestore.googleapis.com",        # Firestore
    "artifactregistry.googleapis.com", # Artifact Registry
    "cloudbuild.googleapis.com",       # Cloud Build
    "logging.googleapis.com",          # Cloud Logging
    "monitoring.googleapis.com",       # Cloud Monitoring
    "iam.googleapis.com",              # IAM
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "compute.googleapis.com",
    "pubsub.googleapis.com"            # Pub/Sub
  ]
}

resource "google_project_service" "required_apis" {
  for_each = toset(local.required_apis)
  
  project = var.project_id
  service = each.value
  
  disable_on_destroy = false
}

# ==============================================================================
# Artifact Registry Repository
# ==============================================================================

resource "google_artifact_registry_repository" "medlab_repo" {
  provider      = google
  project       = var.project_id
  location      = var.region
  repository_id = "medlab-repo"
  format        = "DOCKER"
  description   = "Medical Lab Analyzer container images"

  depends_on = [google_project_service.required_apis]
}

# ==============================================================================
# Cloud Storage Bucket for Reports
# ==============================================================================

resource "google_storage_bucket" "reports_bucket" {
  name          = "${var.project_id}-reports"
  location      = var.region
  force_destroy = true # For demo purposes - allows destroy even if not empty
  
  uniform_bucket_level_access = true
  
  versioning {
    enabled = true
  }
  
  lifecycle_rule {
    condition {
      age = 90 # days
    }
    action {
      type = "Delete"
    }
  }
  
  cors {
    origin          = var.cors_origins
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
  
  depends_on = [google_project_service.required_apis]
}

# ==============================================================================
# Cloud Storage Bucket for Logs
# ==============================================================================

resource "google_storage_bucket" "logs_bucket" {
  name          = "${var.project_id}-logs"
  location      = var.region
  force_destroy = true
  
  uniform_bucket_level_access = true
  
  lifecycle_rule {
    condition {
      age = 30 # Keep logs for 30 days
    }
    action {
      type = "Delete"
    }
  }
  
  depends_on = [google_project_service.required_apis]
}

# ==============================================================================
# Firestore Database
# ==============================================================================

resource "google_firestore_database" "medlab_database" {
  project     = var.project_id
  name        = "(default)"
  location_id = "nam5" # North America multi-region
  type        = "FIRESTORE_NATIVE"
  
  depends_on = [google_project_service.required_apis]
}

# ==============================================================================
# Service Accounts
# ==============================================================================

# Service Account for Report Service
resource "google_service_account" "report_service_sa" {
  account_id   = "medlab-report-service"
  display_name = "MedLab Report Service"
  description  = "Service account for Report Management Service"
  
  depends_on = [google_project_service.required_apis]
}

# Service Account for Analysis Service
resource "google_service_account" "analysis_service_sa" {
  account_id   = "medlab-analysis-service"
  display_name = "MedLab Analysis Service"
  description  = "Service account for Analysis Service"
  
  depends_on = [google_project_service.required_apis]
}

# ==============================================================================
# IAM Bindings
# ==============================================================================

# Grant Report Service access to Cloud Storage
resource "google_storage_bucket_iam_member" "report_service_storage_admin" {
  bucket = google_storage_bucket.reports_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.report_service_sa.email}"
}

# Grant Report Service access to Firestore
resource "google_project_iam_member" "report_service_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.report_service_sa.email}"
}

# Grant Analysis Service access to Firestore
resource "google_project_iam_member" "analysis_service_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.analysis_service_sa.email}"
}

# Grant Analysis Service read access to Cloud Storage
resource "google_storage_bucket_iam_member" "analysis_service_storage_viewer" {
  bucket = google_storage_bucket.reports_bucket.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.analysis_service_sa.email}"
}

# ==============================================================================
# Cloud Run Services
# ==============================================================================

# Report Management Service
resource "google_cloud_run_v2_service" "report_service" {
  name     = "medlab-analyzer-report-service"
  location = var.region
  
  template {
    service_account = google_service_account.report_service_sa.email
    
    scaling {
      min_instance_count = 0  # Scale to zero
      max_instance_count = var.cloud_run_max_instances
    }
    
    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/medlab-repo/report-service:latest"
      
      ports {
        container_port = 8080
      }
      
      env {
        name  = "NODE_ENV"
        value = var.environment
      }
      
      env {
        name  = "PROJECT_ID"
        value = var.project_id
      }
      
      env {
        name  = "BUCKET_NAME"
        value = google_storage_bucket.reports_bucket.name
      }
      
      env {
        name  = "LOG_LEVEL"
        value = var.log_level
      }
      
      resources {
        limits = {
          cpu    = "1000m"
          memory = "512Mi"
        }
        cpu_idle = true
      }
      
      startup_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        initial_delay_seconds = 3
        timeout_seconds       = 1
        period_seconds        = 3
        failure_threshold     = 3
      }
      
      liveness_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        initial_delay_seconds = 10
        timeout_seconds       = 1
        period_seconds        = 10
        failure_threshold     = 3
      }
    }
  }
  
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
  
  depends_on = [
    google_project_service.required_apis,
    google_storage_bucket.reports_bucket,
    google_firestore_database.medlab_database
  ]
}

# Analysis Service
resource "google_cloud_run_v2_service" "analysis_service" {
  name     = "medlab-analyzer-analysis-service"
  location = var.region
  
  template {
    service_account = google_service_account.analysis_service_sa.email
    
    scaling {
      min_instance_count = 0
      max_instance_count = var.cloud_run_max_instances
    }
    
    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/medlab-repo/analysis-service:latest"
      
      ports {
        container_port = 8080
      }
      
      env {
        name  = "NODE_ENV"
        value = var.environment
      }
      
      env {
        name  = "PROJECT_ID"
        value = var.project_id
      }
      
      env {
        name  = "BUCKET_NAME"
        value = google_storage_bucket.reports_bucket.name
      }
      
      env {
        name  = "LOG_LEVEL"
        value = var.log_level
      }
      
      resources {
        limits = {
          cpu    = "1000m"
          memory = "512Mi"
        }
        cpu_idle = true
      }
      
      startup_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        initial_delay_seconds = 3
        timeout_seconds       = 1
        period_seconds        = 3
        failure_threshold     = 3
      }
      
      liveness_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        initial_delay_seconds = 10
        timeout_seconds       = 1
        period_seconds        = 10
        failure_threshold     = 3
      }
    }
  }
  
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
  
  depends_on = [
    google_project_service.required_apis,
    google_storage_bucket.reports_bucket,
    google_firestore_database.medlab_database
  ]
}

# ==============================================================================
# IAM Policy for Cloud Run (Public/Private Access)
# ==============================================================================

# Allow public access if configured (for demo)
resource "google_cloud_run_v2_service_iam_member" "report_service_public" {
  count = var.allow_unauthenticated ? 1 : 0
  
  project  = google_cloud_run_v2_service.report_service.project
  location = google_cloud_run_v2_service.report_service.location
  name     = google_cloud_run_v2_service.report_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "analysis_service_public" {
  count = var.allow_unauthenticated ? 1 : 0
  
  project  = google_cloud_run_v2_service.analysis_service.project
  location = google_cloud_run_v2_service.analysis_service.location
  name     = google_cloud_run_v2_service.analysis_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ==============================================================================
# Logging Sink (Factor 11: Logs)
# ==============================================================================

resource "google_logging_project_sink" "cloud_run_logs" {
  name        = "medlab-cloud-run-logs"
  destination = "storage.googleapis.com/${google_storage_bucket.logs_bucket.name}"
  
  filter = <<-EOT
    resource.type="cloud_run_revision"
    resource.labels.service_name=~"medlab-analyzer-.*"
  EOT
  
  unique_writer_identity = true
}

# Grant the log sink write permissions to the bucket
resource "google_storage_bucket_iam_member" "log_sink_writer" {
  bucket = google_storage_bucket.logs_bucket.name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.cloud_run_logs.writer_identity
}

# ==============================================================================
# Firestore Indexes (for Query Performance)
# ==============================================================================

resource "google_firestore_index" "reports_by_user" {
  project    = var.project_id
  collection = "reports"
  
  fields {
    field_path = "userId"
    order      = "ASCENDING"
  }
  
  fields {
    field_path = "createdAt"
    order      = "DESCENDING"
  }
  
  depends_on = [google_firestore_database.medlab_database]
}

resource "google_firestore_index" "analysis_by_report" {
  project    = var.project_id
  collection = "analyses"
  
  fields {
    field_path = "reportId"
    order      = "ASCENDING"
  }
  
  fields {
    field_path = "analyzedAt"
    order      = "DESCENDING"
  }
  
  depends_on = [google_firestore_database.medlab_database]
}
