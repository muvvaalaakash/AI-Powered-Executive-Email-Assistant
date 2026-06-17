#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# AeroInbox Azure Infrastructure Provisioning CLI Script
# ==============================================================================
# This script provisions Resource Group, VNet, Managed Identity, Key Vault,
# Azure Container Registry (ACR), Redis Cache, PostgreSQL Flexible Server,
# Service Bus Queue, AKS with AGIC Ingress, and federates Service Accounts.
# ==============================================================================

# --- Configuration (Modify as needed) ---
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-}"
RESOURCE_GROUP="rg-aeroinbox-prod"
LOCATION="centralindia"
VNET_NAME="vnet-aeroinbox-prod"
ACR_NAME="acraeroinboxprod"             # globally unique, alphanumeric only
POSTGRES_NAME="pg-aeroinbox-prod"       # globally unique, lowercase, hyphenated
REDIS_NAME="redis-aeroinbox-prod"       # globally unique
KEYVAULT_NAME="kv-aeroinbox-prod"       # globally unique, 3-24 characters
SERVICE_BUS_NAME="sb-aeroinbox-prod"     # globally unique
AKS_NAME="aks-aeroinbox-prod"
SWA_NAME="swa-aeroinbox-prod"
IDENTITY_NAME="id-aeroinbox-prod"

POSTGRES_PASSWORD="YourSecurePassword123!"

echo "======================================================================"
echo "AeroInbox Cloud Infrastructure CLI Provisioner"
echo "======================================================================"

if [ -z "$SUBSCRIPTION_ID" ]; then
  echo "Error: SUBSCRIPTION_ID is not set. Please set it before running, e.g.:"
  echo "  export SUBSCRIPTION_ID=\"xxxx-xxxx-xxxx-xxxx\""
  exit 1
fi

echo "Setting subscription context: $SUBSCRIPTION_ID..."
az account set --subscription "$SUBSCRIPTION_ID"

echo "1. Creating Resource Group: $RESOURCE_GROUP in $LOCATION..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

echo "2. Provisioning Network Topology..."
echo "Creating VNet: $VNET_NAME and Subnet snet-aks..."
az network vnet create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" \
  --address-prefixes 10.0.0.0/16 \
  --subnet-name snet-aks \
  --subnet-prefixes 10.0.0.0/20

echo "Creating Subnet: snet-appgw..."
az network vnet subnet create \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name snet-appgw \
  --address-prefixes 10.0.16.0/24

echo "Creating Subnet: snet-db (delegated for PostgreSQL)..."
az network vnet subnet create \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name snet-db \
  --address-prefixes 10.0.17.0/24 \
  --delegations "Microsoft.DBforPostgreSQL/flexibleServers"

echo "Creating Subnet: snet-endpoints..."
az network vnet subnet create \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name snet-endpoints \
  --address-prefixes 10.0.18.0/24

echo "3. Creating User-Assigned Managed Identity: $IDENTITY_NAME..."
az identity create --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP"
IDENTITY_PRINCIPAL_ID=$(az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" --query principalId -o tsv)
IDENTITY_CLIENT_ID=$(az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" --query clientId -o tsv)

echo "4. Creating Key Vault: $KEYVAULT_NAME with RBAC..."
az keyvault create \
  --name "$KEYVAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --enable-rbac-authorization true

KEYVAULT_ID=$(az keyvault show --name "$KEYVAULT_NAME" --query id -o tsv)

echo "Assigning Key Vault Secrets User role to Managed Identity..."
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee "$IDENTITY_PRINCIPAL_ID" \
  --scope "$KEYVAULT_ID"

echo "Seeding placeholder secrets to Key Vault..."
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "google-client-id" --value "PLACEHOLDER_GOOGLE_CLIENT_ID"
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "google-client-secret" --value "PLACEHOLDER_GOOGLE_CLIENT_SECRET"
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "session-secret" --value "PLACEHOLDER_SESSION_SECRET_32_CHAR_STRING"
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "postgres-password" --value "$POSTGRES_PASSWORD"
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "gemini-api-key" --value "PLACEHOLDER_GEMINI_API_KEY"
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "azure-openai-key" --value "PLACEHOLDER_AZURE_OPENAI_KEY"
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name "redis-password" --value ""

echo "5. Creating Container Registry (ACR): $ACR_NAME..."
az acr create --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" --sku Standard

echo "6. Creating Cache for Redis (Basic C0)..."
az redis create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$REDIS_NAME" \
  --location "$LOCATION" \
  --sku Basic \
  --vm-size c0 \
  --enable-non-ssl-port false

echo "7. Creating PostgreSQL Flexible Server..."
DB_SUBNET_ID=$(az network vnet subnet show --resource-group "$RESOURCE_GROUP" --vnet-name "$VNET_NAME" --name snet-db --query id -o tsv)

az postgres flexible-server create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$POSTGRES_NAME" \
  --location "$LOCATION" \
  --vnet "$VNET_NAME" \
  --subnet "$DB_SUBNET_ID" \
  --admin-user dbadmin \
  --admin-password "$POSTGRES_PASSWORD" \
  --sku-name Standard_B1ms \
  --tier Burstable \
  --public-access None

echo "Enabling Entra ID Auth on PostgreSQL server..."
az postgres flexible-server update \
  --resource-group "$RESOURCE_GROUP" \
  --name "$POSTGRES_NAME" \
  --microsoft-entra-auth Enabled

echo "Registering Managed Identity as PostgreSQL AD Admin..."
az postgres flexible-server microsoft-entra-admin create \
  --resource-group "$RESOURCE_GROUP" \
  --server-name "$POSTGRES_NAME" \
  --display-name "$IDENTITY_NAME" \
  --object-id "$IDENTITY_PRINCIPAL_ID" \
  --type ServicePrincipal

echo "Creating 'aeroinbox' PostgreSQL database..."
az postgres flexible-server db create \
  --resource-group "$RESOURCE_GROUP" \
  --server-name "$POSTGRES_NAME" \
  --database-name aeroinbox

echo "8. Creating Service Bus Queue Namespace & Queue..."
az servicebus namespace create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$SERVICE_BUS_NAME" \
  --location "$LOCATION" \
  --sku Standard

az servicebus queue create \
  --resource-group "$RESOURCE_GROUP" \
  --namespace-name "$SERVICE_BUS_NAME" \
  --name meeting-reminders

echo "9. Provisioning Azure Kubernetes Service (AKS) with Ingress AGIC..."
AKS_SUBNET_ID=$(az network vnet subnet show --resource-group "$RESOURCE_GROUP" --vnet-name "$VNET_NAME" --name snet-aks --query id -o tsv)
APPGW_SUBNET_ID=$(az network vnet subnet show --resource-group "$RESOURCE_GROUP" --vnet-name "$VNET_NAME" --name snet-appgw --query id -o tsv)

az aks create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_NAME" \
  --node-count 1 \
  --node-vm-size Standard_B2s \
  --network-plugin azure \
  --vnet-subnet-id "$AKS_SUBNET_ID" \
  --attach-acr "$ACR_NAME" \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --enable-addons ingress-appgw \
  --appgw-name "appgw-aeroinbox-prod" \
  --appgw-subnet-id "$APPGW_SUBNET_ID"

echo "Establishing OIDC Federated Credentials for Workload Identity..."
AKS_OIDC_ISSUER=$(az aks show --resource-group "$RESOURCE_GROUP" --name "$AKS_NAME" --query "oidcIssuerProfile.issuerUrl" -o tsv)

az identity federated-credential create \
  --name "api-service-federation" \
  --identity-name "$IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --audience "api://AzureADTokenExchange" \
  --issuer "$AKS_OIDC_ISSUER" \
  --subject "system:serviceaccount:default:api-service-sa"

az identity federated-credential create \
  --name "meeting-service-federation" \
  --identity-name "$IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --audience "api://AzureADTokenExchange" \
  --issuer "$AKS_OIDC_ISSUER" \
  --subject "system:serviceaccount:default:meeting-service-sa"

echo "10. Creating Static Web App (SWA) resource..."
echo "Note: SWA requires GitHub validation. Provide details if prompted."
az staticwebapp create \
  --name "$SWA_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location eastasia \
  --source "https://github.com/muvvaalaakash/AI-Powered-Executive-Email-Assistant" \
  --branch aks \
  --app-location "/frontend" \
  --output-location "dist" \
  --login-with-github

echo "Initiating Custom Domain Bindings on SWA..."
az staticwebapp custom-domain create \
  --name "$SWA_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --hostname aeroinbox.qzz.io \
  --validation-method TXT

echo "======================================================================"
echo "PROVISIONING COMPLETE!"
echo "Managed Identity Client ID: $IDENTITY_CLIENT_ID"
echo "Workload Identity OIDC Issuer: $AKS_OIDC_ISSUER"
echo "----------------------------------------------------------------------"
echo "Instructions:"
echo "1. Configure TXT record for SWA Custom Domain ownership verification."
echo "2. Deploy microservice builds to ACR ($ACR_NAME.azurecr.io)."
echo "3. Run 'az aks get-credentials -g $RESOURCE_GROUP -n $AKS_NAME' and apply manifests."
echo "======================================================================"
