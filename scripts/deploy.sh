#!/bin/bash

#===============================================================================
# Medical Lab Analyzer - Complete Deployment Script (Linux/Mac)
#===============================================================================
#
# Usage:
#   ./deploy.sh
#
#===============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m'

# Logging helpers
log_info()    { echo -e "${CYAN}[INFO]${NC}  $1"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()    { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

# Configuration
REGION="${REGION:-us-central1}"
ENVIRONMENT="${ENVIRONMENT:-dev}"

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

log_step "[1/6] Setting GCP project"
gcloud config set project $PROJECT_ID
log_success "Project set to $PROJECT_ID"

#===============================================================================
# Step 2: Enable Required APIs
#===============================================================================

log_step "[2/6] Enabling required GCP APIs"
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
    "pubsub.googleapis.com"
    "apigateway.googleapis.com"
    "servicemanagement.googleapis.com"
    "servicecontrol.googleapis.com"
)

for api in "${apis[@]}"; do
    echo -e "  ${GRAY}Enabling $api...${NC}"
    gcloud services enable $api --quiet
done

log_success "All APIs enabled"

#===============================================================================
# Step 3: Create Terraform State Bucket
#===============================================================================

log_step "[3/6] Creating Terraform state bucket"

if gsutil ls -b gs://$STATE_BUCKET &>/dev/null; then
    log_info "Bucket already exists, skipping"
else
    gsutil mb -p $PROJECT_ID -l $REGION gs://$STATE_BUCKET
    gsutil versioning set on gs://$STATE_BUCKET
    log_success "State bucket created with versioning enabled"
fi

#===============================================================================
# Step 4: Initialize Terraform
#===============================================================================

log_step "[4/6] Initializing Terraform"

cd terraform
terraform init -backend-config="bucket=$STATE_BUCKET"
log_success "Terraform initialized"

#===============================================================================
# Step 5: Apply Terraform Infrastructure
#===============================================================================

log_step "[5/6] Applying Terraform infrastructure"
log_warn "This may take 10-15 minutes due to API Gateway provisioning..."

terraform apply -var-file="environments/$ENVIRONMENT.tfvars" -auto-approve

REPORT_URL=$(terraform output -raw report_service_url)
ANALYSIS_URL=$(terraform output -raw analysis_service_url)
WS_URL=$(terraform output -raw ws_service_url)
GATEWAY_URL=$(terraform output -raw api_gateway_url)

cd ..
log_success "Infrastructure deployed"

#===============================================================================
# Step 6: Trigger Cloud Build for each service
#===============================================================================

log_step "[6/6] Triggering Cloud Build for services"
log_warn "This will build and deploy the real images (3-5 minutes)..."

gcloud builds triggers run medlab-report-service-trigger --branch=main --region=global
gcloud builds triggers run medlab-analysis-service-trigger --branch=main --region=global
gcloud builds triggers run medlab-ws-service-trigger --branch=main --region=global

log_success "All service builds triggered"
log_warn "Waiting for builds to complete..."
sleep 300

#===============================================================================
# Health Checks
#===============================================================================

log_step "Running health checks"

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
echo -e "  API Gateway:      ${CYAN}$GATEWAY_URL${NC}"
echo -e "  Report Service:   ${CYAN}$REPORT_URL${NC}"
echo -e "  Analysis Service: ${CYAN}$ANALYSIS_URL${NC}"
echo -e "  WS Service:       ${CYAN}$WS_URL${NC}"
echo ""
echo -e "${YELLOW}Update frontend/.env with:${NC}"
echo -e "  VITE_API_GATEWAY_URL=$GATEWAY_URL"
echo -e "  VITE_WS_SERVICE_URL=$WS_URL"
echo ""
echo -e "${YELLOW}Quick Test Commands:${NC}"
echo -e "  curl $REPORT_URL/health"
echo -e "  curl $ANALYSIS_URL/health"
echo -e "  curl $WS_URL/health"
echo ""
log_success "Deployment completed successfully"
echo ""
