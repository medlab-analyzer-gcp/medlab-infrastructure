#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Complete teardown script for Medical Lab Analyzer on GCP

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

# Logging helpers
function Log-Info    { param($msg) Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Log-Success { param($msg) Write-Host "[OK]    $msg" -ForegroundColor Green }
function Log-Warn    { param($msg) Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Log-Error   { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }
function Log-Step    { param($msg) Write-Host "`n--- $msg ---" -ForegroundColor Cyan }

Write-Host ""
Write-Host "  +--------------------------------------+" -ForegroundColor Red
Write-Host "  |    Medical Lab Analyzer Teardown    |" -ForegroundColor Red
Write-Host "  +--------------------------------------+" -ForegroundColor Red
Write-Host ""

Log-Info "Project ID:  $ProjectId"
Log-Info "Region:      $Region"
Log-Info "Environment: $Environment"
Write-Host ""
Write-Host "  WARNING: This will permanently destroy ALL resources!" -ForegroundColor Red
Write-Host ""

if (-not $Force) {
    $confirmation = Read-Host "Type 'yes' to continue"
    if ($confirmation -ne "yes") {
        Log-Warn "Aborted by user."
        exit 0
    }
}

# Step 1: Set GCP Project
Log-Step "[1/6] Setting GCP project"
gcloud config set project $ProjectId
Log-Success "Project set to $ProjectId"

# Step 2: Delete Cloud Run Services
Log-Step "[2/6] Deleting Cloud Run services"

$services = @(
    "medlab-analyzer-report-service",
    "medlab-analyzer-analysis-service",
    "medlab-analyzer-ws-service"
)

foreach ($service in $services) {
    Write-Host "  Deleting $service..." -ForegroundColor Gray
    gcloud run services delete $service --region=$Region --quiet 2>&1 | Out-Null
}

Log-Success "Cloud Run services deleted"

# Step 3: Delete Container Images
Log-Step "[3/6] Deleting container images"

$images = @("report-service", "analysis-service", "ws-service")

foreach ($image in $images) {
    Write-Host "  Deleting $image..." -ForegroundColor Gray
    gcloud artifacts docker images delete `
        $Region-docker.pkg.dev/$ProjectId/$RepoName/${image}:latest `
        --quiet 2>&1 | Out-Null
}

Log-Success "Container images deleted"

# Step 4: Delete Artifact Registry Repository
Log-Step "[4/6] Deleting Artifact Registry repository"

gcloud artifacts repositories delete $RepoName --location=$Region --quiet 2>&1 | Out-Null

Log-Success "Artifact Registry repository deleted"

# Step 5: Empty and Delete Cloud Storage Buckets
Log-Step "[5/6] Deleting Cloud Storage buckets"

$reportsBucket = "$ProjectId-reports"
$logsBucket = "$ProjectId-logs"

foreach ($bucket in @($reportsBucket, $logsBucket)) {
    Write-Host "  Deleting gs://$bucket..." -ForegroundColor Gray
    gsutil -m rm -r gs://$bucket/** 2>&1 | Out-Null
    gsutil rb gs://$bucket 2>&1 | Out-Null
}

Log-Success "Storage buckets deleted"
Log-Warn "Firestore data must be cleared manually via GCP Console if needed"

# Step 6: Destroy Terraform Infrastructure
Log-Step "[6/6] Destroying Terraform infrastructure"

Push-Location terraform

terraform init -backend-config="bucket=$StateBucket" 2>&1 | Out-Null
terraform destroy -var-file="environments/$Environment.tfvars" -auto-approve

Pop-Location

Log-Success "Terraform infrastructure destroyed"

# Summary
Write-Host ""
Write-Host "  +--------------------------------------+" -ForegroundColor Green
Write-Host "  |         Teardown Complete!          |" -ForegroundColor Green
Write-Host "  +--------------------------------------+" -ForegroundColor Green
Write-Host ""
Write-Host "  All resources have been deleted." -ForegroundColor White
Write-Host ""
Write-Host "To redeploy, run:" -ForegroundColor Yellow
Write-Host "  .\scripts\deploy.ps1 -ProjectId '$ProjectId'" -ForegroundColor Gray
Write-Host ""
