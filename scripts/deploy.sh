#!/bin/bash

#===============================================================================
# Medical Lab Analyzer - Complete Deployment Script (Linux/Mac)
#===============================================================================
#
# Usage:
#   ./deploy.sh
#
# This script will prompt for required values and perform complete deployment
#
#===============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Logging helpers
log_info()    { echo -e "${CYAN}[INFO]${NC}  $1"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()    { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

# Configuration
REGION="${REGION:-us-central1}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
REPO_NAME="medlab-repo"

echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║   Medical Lab Analyzer Deployment    ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${NC}"

read -p "Enter your GCP Project ID: " PROJECT_ID
if [ -z "$PROJECT_ID" ]; then
    log_error "Project ID is required"
    exit 1
fi

STATE_BUCKET="$PROJECT_ID-terraform-state"

echo ""
log_info "Project ID:  $PROJECT_ID"
log_info "Region:      $REGION"
log_info "Environment: $ENVIRONMENT"
echo ""

#===============================================================================
# Step 1: Set GCP Project
#===============================================================================

log_step "[1/10] Setting GCP project"
gcloud config set project $PROJECT_ID
log_success "Project set to $PROJECT_ID"

#===============================================================================
# Step 2: Enable Required APIs
#===============================================================================

log_step "[2/10] Enabling required GCP APIs"
log_warn "This may take 2-3 minutes..."

apis=(
    "run.googleapis.com"
    "storage.googleapis.com"
    "firestore.googleapis.com"
    "artifactregistry.googleapis.com"
    "cloudbuild.googleapis.com"
    "logging.googleapis.com"
    "monitoring.googleapis.com"
    "iam.googleapis.com"
    "cloudresourcemanager.googleapis.com"
    "compute.googleapis.com"
)

for api in "${apis[@]}"; do
    echo -e "  ${GRAY}Enabling $api...${NC}"
    gcloud services enable $api --quiet
done

log_success "All APIs enabled"

#===============================================================================
# Step 3: Create Terraform State Bucket
#===============================================================================

log_step "[4/10] Creating Terraform state bucket"

if gsutil ls -b gs://$STATE_BUCKET &>/dev/null; then
    log_info "Bucket already exists, skipping"
else
    gsutil mb -p $PROJECT_ID -l $REGION gs://$STATE_BUCKET
    gsutil versioning set on gs://$STATE_BUCKET
    log_success "State bucket created with versioning enabled"
fi

#===============================================================================
# Step 5: Initialize Terraform
#===============================================================================

log_step "[5/10] Initializing Terraform"

cd terraform
terraform init -backend-config="bucket=$STATE_BUCKET"
log_success "Terraform initialized"

#===============================================================================
# Step 6: Apply Terraform Infrastructure
#===============================================================================

log_step "[6/10] Applying Terraform infrastructure"
log_warn "This may take 10-15 minutes due to API Gateway provisioning..."

terraform apply -var-file="environments/$ENVIRONMENT.tfvars" -auto-approve

BUCKET_NAME=$(terraform output -raw reports_bucket_name)

cd ..
log_success "Infrastructure deployed"

#===============================================================================
# Step 7: Build Docker Images
#===============================================================================

log_step "[7/10] Building Docker images"

echo -e "  ${GRAY}Building report-service...${NC}"
docker build -t $REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/report-service:latest ./services/report-service

echo -e "  ${GRAY}Building analysis-service...${NC}"
docker build -t $REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/analysis-service:latest ./services/analysis-service

echo -e "  ${GRAY}Building ws-service...${NC}"
docker build -t $REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/ws-service:latest ./services/ws-service

log_success "All Docker images built"

#===============================================================================
# Step 8: Push Images to Artifact Registry
#===============================================================================

log_step "[8/10] Pushing images to Artifact Registry"

gcloud auth configure-docker $REGION-docker.pkg.dev --quiet

docker push $REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/report-service:latest
docker push $REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/analysis-service:latest
docker push $REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/ws-service:latest

log_success "All images pushed"

#===============================================================================
# Step 9: Deploy to Cloud Run
#===============================================================================

log_step "[9/10] Deploying services to Cloud Run"

echo -e "  ${GRAY}Deploying report-service...${NC}"
gcloud run deploy medlab-analyzer-report-service \
    --image=$REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/report-service:latest \
    --region=$REGION \
    --platform=managed \
    --allow-unauthenticated \
    --set-env-vars="NODE_ENV=$ENVIRONMENT,PROJECT_ID=$PROJECT_ID,BUCKET_NAME=$BUCKET_NAME,LOG_LEVEL=info"

echo -e "  ${GRAY}Deploying analysis-service...${NC}"
gcloud run deploy medlab-analyzer-analysis-service \
    --image=$REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/analysis-service:latest \
    --region=$REGION \
    --platform=managed \
    --allow-unauthenticated \
    --set-env-vars="NODE_ENV=$ENVIRONMENT,PROJECT_ID=$PROJECT_ID,BUCKET_NAME=$BUCKET_NAME,LOG_LEVEL=info"

echo -e "  ${GRAY}Deploying ws-service...${NC}"
gcloud run deploy medlab-analyzer-ws-service \
    --image=$REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/ws-service:latest \
    --region=$REGION \
    --platform=managed \
    --allow-unauthenticated \
    --timeout=3600 \
    --set-env-vars="NODE_ENV=$ENVIRONMENT,PROJECT_ID=$PROJECT_ID,LOG_LEVEL=info"

log_success "All services deployed to Cloud Run"

#===============================================================================
# Step 10: Health Checks
#===============================================================================

log_step "[10/10] Running health checks"

REPORT_URL=$(gcloud run services describe medlab-analyzer-report-service --region=$REGION --format='value(status.url)')
ANALYSIS_URL=$(gcloud run services describe medlab-analyzer-analysis-service --region=$REGION --format='value(status.url)')
WS_URL=$(gcloud run services describe medlab-analyzer-ws-service --region=$REGION --format='value(status.url)')

if curl -sf $REPORT_URL/health &>/dev/null; then
    log_success "Report service is healthy"
else
    log_warn "Report service health check failed (may still be starting)"
fi

if curl -sf $ANALYSIS_URL/health &>/dev/null; then
    log_success "Analysis service is healthy"
else
    log_warn "Analysis service health check failed (may still be starting)"
fi

if curl -sf $WS_URL/health &>/dev/null; then
    log_success "WS service is healthy"
else
    log_warn "WS service health check failed (may still be starting)"
fi

#===============================================================================
# Deployment Summary
#===============================================================================

echo ""
echo -e "${GREEN}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║        Deployment Complete!          ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${YELLOW}Service URLs:${NC}"
echo -e "  Report Service:   ${CYAN}$REPORT_URL${NC}"
echo -e "  Analysis Service: ${CYAN}$ANALYSIS_URL${NC}"
echo -e "  WS Service:       ${CYAN}$WS_URL${NC}"
echo ""
echo -e "${YELLOW}Update frontend/.env with:${NC}"
echo -e "  VITE_API_GATEWAY_URL=<from terraform output api_gateway_url>"
echo -e "  VITE_WS_SERVICE_URL=$WS_URL"
echo ""
echo -e "${YELLOW}Quick Test Commands:${NC}"
echo -e "  curl $REPORT_URL/health"
echo -e "  curl $ANALYSIS_URL/health"
echo -e "  curl $WS_URL/health"
echo ""
echo -e "${YELLOW}View Logs:${NC}"
echo -e "  gcloud run services logs read medlab-analyzer-report-service --region=$REGION --limit=50"
echo ""
log_success "Deployment completed successfully"
echo ""
