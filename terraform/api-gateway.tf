# ==============================================================================
# API Gateway - Single Entry Point for All Services
# ==============================================================================

# Enable required APIs for API Gateway
resource "google_project_service" "apigateway_api" {
  project            = var.project_id
  service            = "apigateway.googleapis.com"
  disable_on_destroy = false
  depends_on         = [google_project_service.required_apis]
}

resource "google_project_service" "servicemanagement_api" {
  project            = var.project_id
  service            = "servicemanagement.googleapis.com"
  disable_on_destroy = false
  depends_on         = [google_project_service.required_apis]
}

resource "google_project_service" "servicecontrol_api" {
  project            = var.project_id
  service            = "servicecontrol.googleapis.com"
  disable_on_destroy = false
  depends_on         = [google_project_service.required_apis]
}

# API resource (the API definition)
resource "google_api_gateway_api" "medlab_api" {
  provider = google-beta
  api_id   = "medlab-analyzer-api"
  project  = var.project_id

  depends_on = [
    google_project_service.apigateway_api,
    google_project_service.servicemanagement_api,
    google_project_service.servicecontrol_api,
  ]
}

# API Config (OpenAPI spec + backend routing)
resource "google_api_gateway_api_config" "medlab_config" {
  provider             = google-beta
  api                  = google_api_gateway_api.medlab_api.api_id
  api_config_id_prefix = "medlab-config-"
  project              = var.project_id

  openapi_documents {
    document {
      path = "spec.yaml"
      contents = base64encode(templatefile("${path.module}/api-spec.yaml", {
        report_service_url   = google_cloud_run_v2_service.report_service.uri
        analysis_service_url = google_cloud_run_v2_service.analysis_service.uri
      }))
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    google_api_gateway_api.medlab_api,
    google_cloud_run_v2_service.report_service,
    google_cloud_run_v2_service.analysis_service,
  ]
}

# Gateway (the actual public endpoint)
resource "google_api_gateway_gateway" "medlab_gateway" {
  provider   = google-beta
  api_config = google_api_gateway_api_config.medlab_config.id
  gateway_id = "medlab-gateway"
  project    = var.project_id
  region     = var.region

  depends_on = [google_api_gateway_api_config.medlab_config]
}
