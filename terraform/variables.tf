# ==============================================================================
# Input Variables for Terraform Configuration
# ==============================================================================

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "cloud_run_max_instances" {
  description = "Maximum number of Cloud Run instances"
  type        = number
  default     = 10
}

variable "allow_unauthenticated" {
  description = "Allow unauthenticated access to Cloud Run services (for demo)"
  type        = bool
  default     = false
}

variable "cors_origins" {
  description = "CORS allowed origins for Cloud Storage"
  type        = list(string)
  default     = ["*"]
}

variable "log_level" {
  description = "Logging level (debug, info, warn, error)"
  type        = string
  default     = "info"
}
