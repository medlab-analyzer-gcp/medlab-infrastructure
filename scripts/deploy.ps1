#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deployment script for Medical Lab Analyzer on GCP

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
$RepoName = "medlab-repo"
$StateBucket = "$ProjectId-terraform-state"

Write-Host "Medical Lab Analyzer Deployment"
Write-Host "Project ID:  $ProjectId"
Write-Host "Region:      $Region"
Write-Host "Environment: $Environment"

# Step 1: Set GCP Project
Write-Host "Setting GCP project..."
gcloud config set project $ProjectId
if ($LASTEXITCODE -ne 0) { Write-Host "Failed to set project"; exit 1 }

# Step 2: Enable Required APIs
Write-Host "Enabling required GCP APIs..."

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
    gcloud services enable $api --quiet
}

# Step 3: Create Artifact Registry Repository
Write-Host "Creating Artifact Registry repository..."

$repoCheck = gcloud artifacts repositories describe $RepoName --location=$Region 2>&1
if ($LASTEXITCODE -ne 0) {
    gcloud artifacts repositories create $RepoName `
        --repository-format=docker `
        --location=$Region `
        --description="Medical Lab Analyzer container images"
    if ($LASTEXITCODE -ne 0) { Write-Host "Failed to create Artifact Registry"; exit 1 }
}

# Step 4: Build Docker Images
Write-Host "Building Docker images..."

gcloud auth configure-docker "$Region-docker.pkg.dev" --quiet

docker build -t "$Region-docker.pkg.dev/$ProjectId/$RepoName/report-service:latest" ./services/report-service
if ($LASTEXITCODE -ne 0) { Write-Host "Failed to build report-service"; exit 1 }

docker build -t "$Region-docker.pkg.dev/$ProjectId/$RepoName/analysis-service:latest" ./services/analysis-service
if ($LASTEXITCODE -ne 0) { Write-Host "Failed to build analysis-service"; exit 1 }

docker build -t "$Region-docker.pkg.dev/$ProjectId/$RepoName/ws-service:latest" ./services/ws-service
if ($LASTEXITCODE -ne 0) { Write-Host "Failed to build ws-service"; exit 1 }

# Step 5: Push Images to Artifact Registry
Write-Host "Pushing images to Artifact Registry..."

docker push "$Region-docker.pkg.dev/$ProjectId/$RepoName/report-service:latest"
if ($LASTEXITCODE -ne 0) { Write-Host "Failed to push report-service"; exit 1 }

docker push "$Region-docker.pkg.dev/$ProjectId/$RepoName/analysis-service:latest"
if ($LASTEXITCODE -ne 0) { Write-Host "Failed to push analysis-service"; exit 1 }

docker push "$Region-docker.pkg.dev/$ProjectId/$RepoName/ws-service:latest"
if ($LASTEXITCODE -ne 0) { Write-Host "Failed to push ws-service"; exit 1 }

# Step 6: Create Terraform State Bucket
Write-Host "Creating Terraform state bucket..."

$bucketCheck = gsutil ls -b "gs://$StateBucket" 2>&1
if ($LASTEXITCODE -ne 0) {
    gsutil mb -p $ProjectId -l $Region "gs://$StateBucket"
    gsutil versioning set on "gs://$StateBucket"
    if ($LASTEXITCODE -ne 0) { Write-Host "Failed to create state bucket"; exit 1 }
}

# Step 7: Terraform Init
Write-Host "Initializing Terraform..."

Push-Location terraform
terraform init -backend-config="bucket=$StateBucket"
if ($LASTEXITCODE -ne 0) { Write-Host "Failed: terraform init"; Pop-Location; exit 1 }

# Step 8: Terraform Apply
Write-Host "Applying Terraform infrastructure..."
terraform apply -var-file="environments/$Environment.tfvars" -auto-approve
if ($LASTEXITCODE -ne 0) { Write-Host "Failed: terraform apply"; Pop-Location; exit 1 }

$bucketName  = terraform output -raw reports_bucket_name
$reportUrl   = terraform output -raw report_service_url
$analysisUrl = terraform output -raw analysis_service_url
$wsUrl       = terraform output -raw ws_service_url
$gatewayUrl  = terraform output -raw api_gateway_url
Pop-Location

# Step 9: Health Checks
Write-Host "Running health checks..."

Start-Sleep -Seconds 15

try {
    $r = Invoke-WebRequest -Uri "$gatewayUrl/health" -UseBasicParsing
    if ($r.StatusCode -eq 200) { Write-Host "Report service is healthy" }
} catch {
    Write-Host "Report service health check failed"
}

try {
    $r = Invoke-WebRequest -Uri "$analysisUrl/health" -UseBasicParsing
    if ($r.StatusCode -eq 200) { Write-Host "Analysis service is healthy" }
} catch {
    Write-Host "Analysis service health check failed"
}

try {
    $r = Invoke-WebRequest -Uri "$wsUrl/health" -UseBasicParsing
    if ($r.StatusCode -eq 200) { Write-Host "WS service is healthy" }
} catch {
    Write-Host "WS service health check failed"
}

Write-Host "Deployment complete"
Write-Host "API Gateway:      $gatewayUrl"
Write-Host "WS Service:       $wsUrl"
Write-Host "Report Service:   $reportUrl"
Write-Host "Analysis Service: $analysisUrl"
Write-Host "Update frontend/.env with VITE_API_GATEWAY_URL=$gatewayUrl and VITE_WS_SERVICE_URL=$wsUrl"
