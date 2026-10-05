#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# One-time bootstrap: creates the storage account that holds Terraform
# remote state for all environments. Run this ONCE, manually, before the
# GitHub Actions workflows are used for the first time. Terraform itself
# cannot create its own backend (chicken-and-egg), so this is plain az cli.
# ---------------------------------------------------------------------------
set -euo pipefail

LOCATION="uaenorth"
RG_NAME="rg-tfstate-uaen-01"
SA_NAME="sttfstateuaen0123"   # must be globally unique, lowercase, <=24 chars
CONTAINER_NAME="tfstate"

echo "Logging in (uses your current az cli session / az login)..."
az account show >/dev/null

echo "Creating resource group: $RG_NAME"
az group create --name "$RG_NAME" --location "$LOCATION" >/dev/null

echo "Creating storage account: $SA_NAME"
az storage account create \
  --name "$SA_NAME" \
  --resource-group "$RG_NAME" \
  --location "$LOCATION" \
  --sku Standard_ZRS \
  --kind StorageV2 \
  --https-only true \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false >/dev/null

echo "Enabling blob versioning and soft delete (protects state history)"
az storage account blob-service-properties update \
  --account-name "$SA_NAME" \
  --resource-group "$RG_NAME" \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 30 >/dev/null

echo "Creating blob container: $CONTAINER_NAME"
az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$SA_NAME" \
  --auth-mode login >/dev/null

echo ""
echo "Done. Backend values to use in each environment's main.tf:"
echo "  uaen  = \"$RG_NAME\""
echo "  storage_account_name = \"$SA_NAME\""
echo "  container_name        = \"$CONTAINER_NAME\""
echo "  key                    = \"<environment>.terraform.tfstate\""
