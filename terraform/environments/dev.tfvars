# ==============================================================================
# Development Environment Configuration
# ==============================================================================

project_id = "swe455-medlab"
region     = "us-central1"
environment = "dev"

# Cloud Run Configuration
cloud_run_max_instances = 5
allow_unauthenticated   = true  # For demo/testing purposes

# CORS Configuration
cors_origins = ["*"]

# Logging
log_level = "debug"
