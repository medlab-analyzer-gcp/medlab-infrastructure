# ==============================================================================
# Cloud Build Triggers
# Factor 5: Build/Release/Run - Automated CI/CD pipeline
# Each repo has its own trigger — push to main = auto build and deploy
# ==============================================================================

locals {
  triggers = {
    "medlab-infrastructure-trigger"   = "medlab-infrastructure"
    "medlab-report-service-trigger"   = "medlab-report-service"
    "medlab-analysis-service-trigger" = "medlab-analysis-service"
    "medlab-ws-service-trigger"       = "medlab-ws-service"
    "medlab-frontend-trigger"         = "medlab-frontend"
  }
}

resource "null_resource" "cloudbuild_triggers" {
  for_each = local.triggers

  triggers = {
    project_id = var.project_id
    name       = each.key
    repo       = each.value
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      $exists = gcloud builds triggers describe ${each.key} --region=global --project=${var.project_id} 2>&1
      if ($LASTEXITCODE -ne 0) {
        gcloud builds triggers create github `
          --name=${each.key} `
          --repo-name=${each.value} `
          --repo-owner=medlab-analyzer-gcp `
          --branch-pattern="^main$" `
          --build-config=cloudbuild.yaml `
          --region=global `
          --project=${var.project_id}
      } else {
        Write-Host "${each.key} already exists, skipping"
      }
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["PowerShell", "-Command"]
    command     = "gcloud builds triggers delete ${each.key} --region=global --project=${self.triggers.project_id} --quiet 2>&1 | Out-Null"
  }
}
