#!/bin/bash

#===============================================================================
# Medical Lab Analyzer - Complete Teardown Script (Linux/Mac)
#===============================================================================
#
# Usage:
#   ./destroy.sh
#
# This script will destroy all GCP resources
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

echo -e "${RED}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║    Medical Lab Analyzer Teardown     ║"
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
echo -e "${RED}  ⚠️  WARNING: This will permanently destroy ALL resources!${NC}"
echo ""

read -p "Type 'yes' to continue: " confirmation
if [ "$confirmation" != "yes" ]; then
    log_warn "Aborted by user."
    exit 0
fi

echo ""

#===============================================================================
# Step 1: Set GCP Project
#===============================================================================

log_step "[1/6] Setting GCP project"
gcloud config set project $PROJECT_ID
log_success "Project set to $PROJECT_ID"

#===============================================================================
# Step 2: Delete Cloud Run Services
#===============================================================================

log_step "[2/6] Deleting Cloud Run services"

services=(
    "medlab-analyzer-report-service"
    "medlab-analyzer-analysis-service"
    "medlab-analyzer-ws-service"
)

for service in "${services[@]}"; do
    echo -e "  ${GRAY}Deleting $service...${NC}"
    gcloud run services delete $service --region=$REGION --quiet 2>/dev/null || true
done

log_success "Cloud Run services deleted"

#===============================================================================
# Step 3: Delete Container Images
#===============================================================================

log_step "[3/6] Deleting container images"

images=("report-service" "analysis-service" "ws-service")

for image in "${images[@]}"; do
    echo -e "  ${GRAY}Deleting $image...${NC}"
    gcloud artifacts docker images delete \
        $REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/${image}:latest \
        --quiet 2>/dev/null || true
done

log_success "Container images deleted"

#===============================================================================
# Step 4: Delete Artifact Registry Repository
#===============================================================================

log_step "[4/6] Deleting Artifact Registry repository"

gcloud artifacts repositories delete $REPO_NAME --location=$REGION --quiet 2>/dev/null || true

log_success "Artifact Registry repository deleted"

#===============================================================================
# Step 5: Empty and Delete Cloud Storage Buckets
#===============================================================================

log_step "[5/6] Deleting Cloud Storage buckets"

REPORTS_BUCKET="$PROJECT_ID-reports"
LOGS_BUCKET="$PROJECT_ID-logs"

for bucket in $REPORTS_BUCKET $LOGS_BUCKET; do
    echo -e "  ${GRAY}Deleting gs://$bucket...${NC}"
    gsutil -m rm -r gs://$bucket/** 2>/dev/null || true
    gsutil rb gs://$bucket 2>/dev/null || true
done

log_success "Storage buckets deleted"
log_warn "Firestore data must be cleared manually via GCP Console if needed"

#===============================================================================
# Step 6: Destroy Terraform Infrastructure
#===============================================================================

log_step "[6/6] Destroying Terraform infrastructure"

cd terraform

terraform init -backend-config="bucket=$STATE_BUCKET" 2>/dev/null
terraform destroy -var-file="environments/$ENVIRONMENT.tfvars" -auto-approve

cd ..

log_success "Terraform infrastructure destroyed"

#===============================================================================
# Teardown Summary
#===============================================================================

echo ""
echo -e "${GREEN}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║         Teardown Complete!           ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${NC}"
echo "  All resources have been deleted."
echo ""
echo -e "${YELLOW}To redeploy, run:${NC}"
echo "  ./scripts/deploy.sh"
echo ""
