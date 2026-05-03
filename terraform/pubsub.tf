# ==============================================================================
# Pub/Sub — Event Bus between report-service and analysis-service
# ==============================================================================

# Topic: analysis-requests
resource "google_pubsub_topic" "analysis_requests" {
  name    = "analysis-requests"
  project = var.project_id

  depends_on = [google_project_service.required_apis]
}

# Push Subscription: Pub/Sub pushes to analysis-service
resource "google_pubsub_subscription" "analysis_worker" {
  name    = "analysis-worker"
  topic   = google_pubsub_topic.analysis_requests.name
  project = var.project_id

  push_config {
    push_endpoint = "${google_cloud_run_v2_service.analysis_service.uri}/pubsub/push"
  }

  ack_deadline_seconds = 60

  retry_policy {
    minimum_backoff = "5s"
    maximum_backoff = "300s"
  }

  depends_on = [
    google_pubsub_topic.analysis_requests,
    google_cloud_run_v2_service.analysis_service,
  ]
}

# IAM: report-service can publish to topic
resource "google_pubsub_topic_iam_member" "report_service_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.analysis_requests.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.report_service_sa.email}"
}

# IAM: allow Pub/Sub to invoke analysis-service (required for push subscriptions)
resource "google_cloud_run_v2_service_iam_member" "pubsub_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.analysis_service.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

data "google_project" "project" {
  project_id = var.project_id
}

# ==============================================================================
# WS Service — WebSocket + Firestore real-time
# ==============================================================================

# Service Account for WS service
resource "google_service_account" "ws_service_sa" {
  account_id   = "medlab-ws-service"
  display_name = "Service Account for WebSocket Service"
  project      = var.project_id
}

# IAM: WS service can read Firestore
resource "google_project_iam_member" "ws_service_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.ws_service_sa.email}"
}

# WS Service Cloud Run
resource "google_cloud_run_v2_service" "ws_service" {
  name     = "medlab-analyzer-ws-service"
  location = var.region

  template {
    service_account = google_service_account.ws_service_sa.email

    scaling {
      min_instance_count = 0
      max_instance_count = var.cloud_run_max_instances
    }

    # WebSocket needs longer timeout (60 minutes max)
    timeout = "3600s"

    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello:latest"

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
        name  = "LOG_LEVEL"
        value = var.log_level
      }

      resources {
        limits = {
          cpu    = "1000m"
          memory = "512Mi"
        }
        cpu_idle = false
      }

      startup_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        initial_delay_seconds = 5
        timeout_seconds       = 3
        period_seconds        = 5
        failure_threshold     = 3
      }
    }
  }

  ingress = "INGRESS_TRAFFIC_ALL"

  lifecycle {
    ignore_changes = [template[0].containers[0].image]
  }

  depends_on = [
    google_project_service.required_apis,
    google_service_account.ws_service_sa,
  ]
}

# Allow unauthenticated access to WS service
resource "google_cloud_run_v2_service_iam_member" "ws_service_public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.ws_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
