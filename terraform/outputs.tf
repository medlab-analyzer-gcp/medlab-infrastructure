# ==============================================================================
# Terraform Outputs
# ==============================================================================

output "report_service_url" {
  description = "URL of the Report Management Service"
  value       = google_cloud_run_v2_service.report_service.uri
}

output "analysis_service_url" {
  description = "URL of the Analysis Service"
  value       = google_cloud_run_v2_service.analysis_service.uri
}

output "reports_bucket_name" {
  description = "Name of the Cloud Storage bucket for reports"
  value       = google_storage_bucket.reports_bucket.name
}

output "logs_bucket_name" {
  description = "Name of the Cloud Storage bucket for logs"
  value       = google_storage_bucket.logs_bucket.name
}

output "firestore_database" {
  description = "Firestore database information"
  value       = google_firestore_database.medlab_database.name
}

output "report_service_sa_email" {
  description = "Email of the Report Service service account"
  value       = google_service_account.report_service_sa.email
}

output "analysis_service_sa_email" {
  description = "Email of the Analysis Service service account"
  value       = google_service_account.analysis_service_sa.email
}

output "project_id" {
  description = "The GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "The GCP region"
  value       = var.region
}

output "environment" {
  description = "The environment name"
  value       = var.environment
}

output "api_gateway_url" {
  description = "URL of the API Gateway - single entry point for all services"
  value       = "https://${google_api_gateway_gateway.medlab_gateway.default_hostname}"
}

output "ws_service_url" {
  description = "URL of the WebSocket Service"
  value       = google_cloud_run_v2_service.ws_service.uri
}

output "pubsub_topic" {
  description = "Pub/Sub topic name"
  value       = google_pubsub_topic.analysis_requests.name
}
