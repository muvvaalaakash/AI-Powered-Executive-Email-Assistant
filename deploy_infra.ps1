# ==============================================================================
# AeroInbox Azure Infrastructure Provisioning PowerShell Script
# ==============================================================================
# This script provisions Resource Group, VNet, Managed Identity, Key Vault,
# Azure Container Registry (ACR), Redis Cache, PostgreSQL Flexible Server,
# Service Bus Queue, AKS with AGIC Ingress, and federates Service Accounts.
# ==============================================================================

# --- Configuration (Modify as needed) ---
$SubscriptionId = $env:SUBSCRIPTION_ID
$ResourceGroup = "rg-aeroinbox-prod"
$Location = "centralindia"
$VNetName = "vnet-aeroinbox-prod"
$AcrName = "acraeroinboxprod"             # globally unique, alphanumeric only
$PostgresName = "pg-aeroinbox-prod"       # globally unique, lowercase, hyphenated
$RedisName = "redis-aeroinbox-prod"       # globally unique
$KeyVaultName = "kv-aeroinbox-prod"       # globally unique, 3-24 characters
$ServiceBusName = "sb-aeroinbox-prod"     # globally unique
$AksName = "aks-aeroinbox-prod"
$SwaName = "swa-aeroinbox-prod"
$IdentityName = "id-aeroinbox-prod"

$PostgresPassword = "YourSecurePassword123!"

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "AeroInbox Cloud Infrastructure CLI Provisioner (PowerShell)" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

if ([string]::IsNullOrEmpty($SubscriptionId)) {
    Write-Host "Error: SUBSCRIPTION_ID environment variable is not set." -ForegroundColor Red
    Write-Host "Please set it before running, e.g.:" -ForegroundColor Yellow
    Write-Host "  `$env:SUBSCRIPTION_ID = 'xxxx-xxxx-xxxx-xxxx'" -ForegroundColor Yellow
    Exit
}

Write-Host "Setting subscription context: $SubscriptionId..." -ForegroundColor Green
az account set --subscription $SubscriptionId

Write-Host "1. Creating Resource Group: $ResourceGroup in $Location..." -ForegroundColor Green
az group create --name $ResourceGroup --location $Location

Write-Host "2. Provisioning Network Topology..." -ForegroundColor Green
Write-Host "Creating VNet: $VNetName and Subnet snet-aks..." -ForegroundColor Yellow
az network vnet create `
  --resource-group $ResourceGroup `
  --name $VNetName `
  --address-prefixes 10.0.0.0/16 `
  --subnet-name snet-aks `
  --subnet-prefixes 10.0.0.0/20

Write-Host "Creating Subnet: snet-appgw..." -ForegroundColor Yellow
az network vnet subnet create `
  --resource-group $ResourceGroup `
  --vnet-name $VNetName `
  --name snet-appgw `
  --address-prefixes 10.0.16.0/24

Write-Host "Creating Subnet: snet-db (delegated for PostgreSQL)..." -ForegroundColor Yellow
az network vnet subnet create `
  --resource-group $ResourceGroup `
  --vnet-name $VNetName `
  --name snet-db `
  --address-prefixes 10.0.17.0/24 `
  --delegations "Microsoft.DBforPostgreSQL/flexibleServers"

Write-Host "Creating Subnet: snet-endpoints..." -ForegroundColor Yellow
az network vnet subnet create `
  --resource-group $ResourceGroup `
  --vnet-name $VNetName `
  --name snet-endpoints `
  --address-prefixes 10.0.18.0/24

Write-Host "3. Creating User-Assigned Managed Identity: $IdentityName..." -ForegroundColor Green
az identity create --name $IdentityName --resource-group $ResourceGroup
$IdentityPrincipalId = az identity show --name $IdentityName --resource-group $ResourceGroup --query principalId -o tsv
$IdentityClientId = az identity show --name $IdentityName --resource-group $ResourceGroup --query clientId -o tsv

Write-Host "4. Creating Key Vault: $KeyVaultName with RBAC..." -ForegroundColor Green
az keyvault create `
  --name $KeyVaultName `
  --resource-group $ResourceGroup `
  --location $Location `
  --enable-rbac-authorization true

$KeyVaultId = az keyvault show --name $KeyVaultName --query id -o tsv

Write-Host "Assigning Key Vault Secrets User role to Managed Identity..." -ForegroundColor Yellow
az role assignment create `
  --role "Key Vault Secrets User" `
  --assignee $IdentityPrincipalId `
  --scope $KeyVaultId

Write-Host "Assigning Key Vault Secrets Officer role to current user context..." -ForegroundColor Yellow
$CurrentUserObjectId = az ad signed-in-user show --query id -o tsv
az role assignment create `
  --role "Key Vault Secrets Officer" `
  --assignee $CurrentUserObjectId `
  --scope $KeyVaultId

Write-Host "Sleeping 15 seconds to allow RBAC assignment propagation..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

Write-Host "Seeding placeholder secrets to Key Vault..." -ForegroundColor Yellow
az keyvault secret set --vault-name $KeyVaultName --name "google-client-id" --value "PLACEHOLDER_GOOGLE_CLIENT_ID"
az keyvault secret set --vault-name $KeyVaultName --name "google-client-secret" --value "PLACEHOLDER_GOOGLE_CLIENT_SECRET"
az keyvault secret set --vault-name $KeyVaultName --name "session-secret" --value "PLACEHOLDER_SESSION_SECRET_32_CHAR_STRING"
az keyvault secret set --vault-name $KeyVaultName --name "postgres-password" --value $PostgresPassword
az keyvault secret set --vault-name $KeyVaultName --name "gemini-api-key" --value "PLACEHOLDER_GEMINI_API_KEY"
az keyvault secret set --vault-name $KeyVaultName --name "azure-openai-key" --value "PLACEHOLDER_AZURE_OPENAI_KEY"
az keyvault secret set --vault-name $KeyVaultName --name "redis-password" --value "none"

Write-Host "5. Creating Container Registry (ACR): $AcrName..." -ForegroundColor Green
az acr create --resource-group $ResourceGroup --name $AcrName --sku Standard

Write-Host "6. Skipping Azure Cache for Redis (using local container sidecar)..." -ForegroundColor Green
# az redis create `
#   --resource-group $ResourceGroup `
#   --name $RedisName `
#   --location $Location `
#   --sku Basic `
#   --vm-size c0 `
#   --enable-non-ssl-port

Write-Host "7. Creating PostgreSQL Flexible Server (Public Access with Firewall Control)..." -ForegroundColor Green

az postgres flexible-server create `
  --resource-group $ResourceGroup `
  --name $PostgresName `
  --location $Location `
  --admin-user dbadmin `
  --admin-password $PostgresPassword `
  --sku-name Standard_B1ms `
  --tier Burstable `
  --public-access Enabled `
  --yes

Write-Host "Creating firewall rule to allow Azure internal connection (AllowAllAzureIPs)..." -ForegroundColor Yellow
az postgres flexible-server firewall-rule create `
  --resource-group $ResourceGroup `
  --name $PostgresName `
  --rule-name AllowAllAzureIPs `
  --start-ip-address 0.0.0.0 `
  --end-ip-address 0.0.0.0

Write-Host "Enabling Entra ID Auth on PostgreSQL server..." -ForegroundColor Yellow
az postgres flexible-server update `
  --resource-group $ResourceGroup `
  --name $PostgresName `
  --microsoft-entra-auth Enabled

Write-Host "Registering Managed Identity as PostgreSQL AD Admin..." -ForegroundColor Yellow
az postgres flexible-server microsoft-entra-admin create `
  --resource-group $ResourceGroup `
  --server-name $PostgresName `
  --display-name $IdentityName `
  --object-id $IdentityPrincipalId `
  --type ServicePrincipal

Write-Host "Creating 'aeroinbox' PostgreSQL database..." -ForegroundColor Yellow
az postgres flexible-server db create `
  --resource-group $ResourceGroup `
  --server-name $PostgresName `
  --name aeroinbox

Write-Host "8. Creating Service Bus Queue Namespace & Queue..." -ForegroundColor Green
az servicebus namespace create `
  --resource-group $ResourceGroup `
  --name $ServiceBusName `
  --location $Location `
  --sku Standard

az servicebus queue create `
  --resource-group $ResourceGroup `
  --namespace-name $ServiceBusName `
  --name meeting-reminders

Write-Host "9. Provisioning Azure Kubernetes Service (AKS) with Ingress AGIC..." -ForegroundColor Green
$AksSubnetId = az network vnet subnet show --resource-group $ResourceGroup --vnet-name $VNetName --name snet-aks --query id -o tsv
$AppgwSubnetId = az network vnet subnet show --resource-group $ResourceGroup --vnet-name $VNetName --name snet-appgw --query id -o tsv

az aks create `
  --resource-group $ResourceGroup `
  --name $AksName `
  --node-count 1 `
  --node-vm-size Standard_B2s_v2 `
  --network-plugin azure `
  --vnet-subnet-id $AksSubnetId `
  --service-cidr 10.240.0.0/16 `
  --dns-service-ip 10.240.0.10 `
  --attach-acr $AcrName `
  --enable-oidc-issuer `
  --enable-workload-identity `
  --enable-addons ingress-appgw `
  --appgw-name "appgw-aeroinbox-prod" `
  --appgw-subnet-id $AppgwSubnetId

Write-Host "Establishing OIDC Federated Credentials for Workload Identity..." -ForegroundColor Yellow
$AksOidcIssuer = az aks show --resource-group $ResourceGroup --name $AksName --query "oidcIssuerProfile.issuerUrl" -o tsv

az identity federated-credential create `
  --name "api-service-federation" `
  --identity-name $IdentityName `
  --resource-group $ResourceGroup `
  --audience "api://AzureADTokenExchange" `
  --issuer $AksOidcIssuer `
  --subject "system:serviceaccount:default:api-service-sa"

az identity federated-credential create `
  --name "meeting-service-federation" `
  --identity-name $IdentityName `
  --resource-group $ResourceGroup `
  --audience "api://AzureADTokenExchange" `
  --issuer $AksOidcIssuer `
  --subject "system:serviceaccount:default:meeting-service-sa"

Write-Host "10. Creating Static Web App (SWA) resource..." -ForegroundColor Green
az staticwebapp create `
  --name $SwaName `
  --resource-group $ResourceGroup `
  --location eastasia `
  --source "https://github.com/muvvaalaakash/AI-Powered-Executive-Email-Assistant" `
  --branch aks `
  --app-location "/frontend" `
  --output-location "dist" `
  --login-with-github

Write-Host "Initiating Custom Domain Bindings on SWA..." -ForegroundColor Yellow
az staticwebapp hostname set `
  --name $SwaName `
  --resource-group $ResourceGroup `
  --hostname aeroinbox.qzz.io `
  --validation-method dns-txt-token

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "PROVISIONING COMPLETE!" -ForegroundColor Green
Write-Host "Managed Identity Client ID: $IdentityClientId" -ForegroundColor Green
Write-Host "Workload Identity OIDC Issuer: $AksOidcIssuer" -ForegroundColor Green
Write-Host "----------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Instructions:" -ForegroundColor Yellow
Write-Host "1. Configure TXT record for SWA Custom Domain ownership verification." -ForegroundColor Yellow
Write-Host "2. Deploy microservice builds to ACR ($AcrName.azurecr.io)." -ForegroundColor Yellow
Write-Host "3. Run 'az aks get-credentials -g $ResourceGroup -n $AksName' and apply manifests." -ForegroundColor Yellow
Write-Host "======================================================================" -ForegroundColor Cyan
