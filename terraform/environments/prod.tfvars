# ==============================================================================
# Production Environment Configuration
# ==============================================================================

project_id = "your-gcp-project-id-prod"  # CHANGE THIS!
region     = "us-central1"
environment = "prod"

# Cloud Run Configuration
cloud_run_max_instances = 100
allow_unauthenticated   = false  # Require authentication in prod

# CORS Configuration
cors_origins = ["https://yourdomain.com"]

# Logging
log_level = "info"
