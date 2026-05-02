# ==============================================================================
# Terraform Provider Configuration
# ==============================================================================

terraform {
  backend "gcs" {
    # Bucket will be created by deploy script
    # Configuration is provided at init time via -backend-config
    bucket = "swe455-medlab-terraform-state"
    prefix = "medlab"
  }
}
