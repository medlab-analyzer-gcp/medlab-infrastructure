#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Complete deployment script for Medical Lab Analyzer on GCP

.PARAMETER ProjectId
    Your GCP Project ID

.PARAMETER Region
    GCP region (default: us-central1)

.PARAMETER Environment
    Environment name (default: dev)

.EXAMPLE
    .\deploy.ps1 -ProjectId "swe455-medlab"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectId,

    [Parameter(Mandatory=$false)]
    [string]$Region = "us-central1",

    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev"
)

$ErrorActionPreference = "Continue"
$StateBucket = "$ProjectId-terraform-state"

# Logging helpers
function Log-Info    { param($msg) Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Log-Success { param($msg) Write-Host "[OK]    $msg" -ForegroundColor Green }
function Log-Warn    { param($msg) Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Log-Error   { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }
function Log-Step    { param($msg) Write-Host "`n--- $msg ---" -ForegroundColor Cyan }

Write-Host ""
Write-Host "  +--------------------------------------+" -ForegroundColor Cyan
Write-Host "  |   Medical Lab Analyzer Deployment   |" -ForegroundColor Cyan
Write-Host "  +--------------------------------------+" -ForegroundColor Cyan
Write-Host ""

Log-Info "Project ID:  $ProjectId"
Log-Info "Region:      $Region"
Log-Info "Environment: $Environment"
Write-Host ""

# Step 1: Set GCP Project
Log-Step "[1/6] Setting GCP project"
gcloud config set project $ProjectId
if ($LASTEXITCODE -ne 0) { Log-Error "Failed to set project"; exit 1 }
Log-Success "Project set to $ProjectId"

# Step 2: Enable Required APIs
Log-Step "[2/6] Enabling required GCP APIs"
Log-Warn "This may take 2-3 minutes..."

$apis = @(
    "run.googleapis.com",
    "storage.googleapis.com",
    "firestore.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "pubsub.googleapis.com",
    "apigateway.googleapis.com",
    "servicemanagement.googleapis.com",
    "servicecontrol.googleapis.com"
)

foreach ($api in $apis) {
    Write-Host "  Enabling $api..." -ForegroundColor Gray
    gcloud services enable $api --quiet
}

Log-Success "All APIs enabled"

# Step 3: Create Terraform State Bucket
Log-Step "[3/6] Creating Terraform state bucket"

$bucketCheck = gsutil ls -b "gs://$StateBucket" 2>&1
if ($LASTEXITCODE -eq 0) {
    Log-Info "Bucket already exists, skipping"
} else {
    gsutil mb -p $ProjectId -l $Region "gs://$StateBucket"
    gsutil versioning set on "gs://$StateBucket"
    if ($LASTEXITCODE -ne 0) { Log-Error "Failed to create state bucket"; exit 1 }
    Log-Success "State bucket created with versioning enabled"
}

# Step 7: Terraform Init
Log-Step "[4/6] Initializing Terraform"

Push-Location terraform
terraform init -backend-config="bucket=$StateBucket"
if ($LASTEXITCODE -ne 0) { Log-Error "terraform init failed"; Pop-Location; exit 1 }
Log-Success "Terraform initialized"

# Step 8: Terraform Apply
Log-Step "[5/6] Applying Terraform infrastructure"
Log-Warn "This may take 10-15 minutes due to API Gateway provisioning..."

terraform apply -var-file="environments/$Environment.tfvars" -auto-approve
if ($LASTEXITCODE -ne 0) { Log-Error "terraform apply failed"; Pop-Location; exit 1 }

$bucketName  = terraform output -raw reports_bucket_name
$reportUrl   = terraform output -raw report_service_url
$analysisUrl = terraform output -raw analysis_service_url
$wsUrl       = terraform output -raw ws_service_url
$gatewayUrl  = terraform output -raw api_gateway_url
Pop-Location

Log-Success "Infrastructure deployed"

# Step 6: Trigger Cloud Build for each service
Log-Step "[6/6] Triggering Cloud Build for services"
Log-Warn "This will build and deploy the real images (3-5 minutes)..."

gcloud builds triggers run medlab-report-service-trigger --branch=main --region=global
gcloud builds triggers run medlab-analysis-service-trigger --branch=main --region=global
gcloud builds triggers run medlab-ws-service-trigger --branch=main --region=global

Log-Success "All service builds triggered"
Log-Warn "Waiting for builds to complete..."
Start-Sleep -Seconds 300

# Step 10: Health Checks
Log-Step "Running health checks"

Start-Sleep -Seconds 15

try {
    $r = Invoke-WebRequest -Uri "$gatewayUrl/health" -UseBasicParsing
    if ($r.StatusCode -eq 200) { Log-Success "Report service is healthy" }
} catch {
    Log-Warn "Report service health check failed (may still be starting)"
}

try {
    $r = Invoke-WebRequest -Uri "$analysisUrl/health" -UseBasicParsing
    if ($r.StatusCode -eq 200) { Log-Success "Analysis service is healthy" }
} catch {
    Log-Warn "Analysis service health check failed (may still be starting)"
}

try {
    $r = Invoke-WebRequest -Uri "$wsUrl/health" -UseBasicParsing
    if ($r.StatusCode -eq 200) { Log-Success "WS service is healthy" }
} catch {
    Log-Warn "WS service health check failed (may still be starting)"
}

# Summary
Write-Host ""
Write-Host "  +--------------------------------------+" -ForegroundColor Green
Write-Host "  |        Deployment Complete!         |" -ForegroundColor Green
Write-Host "  +--------------------------------------+" -ForegroundColor Green
Write-Host ""
Write-Host "Service URLs:" -ForegroundColor Yellow
Write-Host "  API Gateway:      $gatewayUrl" -ForegroundColor Cyan
Write-Host "  WS Service:       $wsUrl" -ForegroundColor Cyan
Write-Host "  Report Service:   $reportUrl" -ForegroundColor Cyan
Write-Host "  Analysis Service: $analysisUrl" -ForegroundColor Cyan
Write-Host ""
Write-Host "Update frontend/.env with:" -ForegroundColor Yellow
Write-Host "  VITE_API_GATEWAY_URL=$gatewayUrl" -ForegroundColor Gray
Write-Host "  VITE_WS_SERVICE_URL=$wsUrl" -ForegroundColor Gray
Write-Host ""
Log-Success "Deployment completed successfully"
Write-Host ""
