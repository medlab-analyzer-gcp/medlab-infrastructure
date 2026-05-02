#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Teardown script for Medical Lab Analyzer on GCP

.PARAMETER ProjectId
    Your GCP Project ID

.PARAMETER Region
    GCP region (default: us-central1)

.PARAMETER Environment
    Environment name (default: dev)

.PARAMETER Force
    Skip confirmation prompt

.EXAMPLE
    .\destroy.ps1 -ProjectId "my-project-id"
    .\destroy.ps1 -ProjectId "my-project-id" -Force
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectId,

    [Parameter(Mandatory=$false)]
    [string]$Region = "us-central1",

    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev",

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

$ErrorActionPreference = "Continue"
$RepoName = "medlab-repo"
$StateBucket = "$ProjectId-terraform-state"

Write-Host "Medical Lab Analyzer Teardown"
Write-Host "Project ID:  $ProjectId"
Write-Host "Region:      $Region"
Write-Host "Environment: $Environment"
Write-Host "WARNING: This will destroy ALL resources!"

if (-not $Force) {
    $confirmation = Read-Host "Type 'yes' to continue"
    if ($confirmation -ne "yes") {
        Write-Host "Aborted."
        exit 0
    }
}

# Step 1: Set GCP Project
Write-Host "Setting GCP project..."
gcloud config set project $ProjectId

# Step 2: Delete Cloud Run Services
Write-Host "Deleting Cloud Run services..."

$services = @(
    "medlab-analyzer-report-service",
    "medlab-analyzer-analysis-service",
    "medlab-analyzer-ws-service"
)

foreach ($service in $services) {
    gcloud run services delete $service --region=$Region --quiet 2>&1 | Out-Null
}

# Step 3: Delete Container Images
Write-Host "Deleting container images..."

$images = @("report-service", "analysis-service", "ws-service")

foreach ($image in $images) {
    gcloud artifacts docker images delete `
        $Region-docker.pkg.dev/$ProjectId/$RepoName/${image}:latest `
        --quiet 2>&1 | Out-Null
}

# Step 4: Delete Artifact Registry Repository
Write-Host "Deleting Artifact Registry repository..."

gcloud artifacts repositories delete $RepoName --location=$Region --quiet 2>&1 | Out-Null

# Step 5: Empty and Delete Cloud Storage Buckets
Write-Host "Deleting Cloud Storage buckets..."

$reportsBucket = "$ProjectId-reports"
$logsBucket = "$ProjectId-logs"

foreach ($bucket in @($reportsBucket, $logsBucket)) {
    gsutil -m rm -r gs://$bucket/** 2>&1 | Out-Null
    gsutil rb gs://$bucket 2>&1 | Out-Null
}

Write-Host "Note: Firestore data should be manually cleared via Console if needed"

# Step 6: Destroy Terraform Infrastructure
Write-Host "Destroying Terraform infrastructure..."

Push-Location terraform

terraform init -backend-config="bucket=$StateBucket" 2>&1 | Out-Null
terraform destroy -var-file="environments/$Environment.tfvars" -auto-approve

Pop-Location

Write-Host "Teardown complete"
Write-Host "To redeploy, run: .\scripts\deploy.ps1 -ProjectId '$ProjectId'"
