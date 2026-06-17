# Automated Azure CLI Deployment Guide: AKS Hybrid Cloud Architecture

This guide provides step-by-step instructions and script commands to automate the provisioning of all required cloud infrastructure for the **AeroInbox** email assistant using the **Azure CLI (`az`)**.

All resources are deployed in the **Central India** (`centralindia`) region (except the Static Web App, which is deployed to `eastasia` for regional coverage).

---

## 1. Preparation & Environment Variables

Open your terminal (Bash, Zsh, or WSL are recommended. For Windows PowerShell, adapt variables to `$env:VAR` syntax) and run the following command to log in:

```bash
az login
```

Set the environment variables to configure naming conventions and parameters:

```bash
export SubscriptionId="<your-subscription-id>"
export ResourceGroup="rg-aeroinbox-prod"
export Location="centralindia"
export VNetName="vnet-aeroinbox-prod"
export AcrName="acraeroinboxprod"             # Must be globally unique, alphanumeric only
export PostgresName="pg-aeroinbox-prod"       # Must be globally unique, lowercase alphanumeric & hyphens
export RedisName="redis-aeroinbox-prod"       # Must be globally unique
export KeyVaultName="kv-aeroinbox-prod"       # Must be globally unique, 3-24 chars
export ServiceBusName="sb-aeroinbox-prod"     # Must be globally unique
export AksName="aks-aeroinbox-prod"
export SwaName="swa-aeroinbox-prod"
export UserIdentityName="id-aeroinbox-prod"

# Set Subscription Context
az account set --subscription "$SubscriptionId"
```

---

## 2. Resource Group & Virtual Network (VNet)

### Step 2.1: Create Resource Group
```bash
az group create --name "$ResourceGroup" --location "$Location"
```

### Step 2.2: Create VNet and Subnets
Create the VNet and the initial subnet for AKS nodes/pods:
```bash
az network vnet create \
  --resource-group "$ResourceGroup" \
  --name "$VNetName" \
  --address-prefixes 10.0.0.0/16 \
  --subnet-name snet-aks \
  --subnet-prefixes 10.0.0.0/20
```

Create the subnet for Application Gateway WAF:
```bash
az network vnet subnet create \
  --resource-group "$ResourceGroup" \
  --vnet-name "$VNetName" \
  --name snet-appgw \
  --address-prefixes 10.0.16.0/24
```

Create the delegated subnet for PostgreSQL Flexible Server:
```bash
az network vnet subnet create \
  --resource-group "$ResourceGroup" \
  --vnet-name "$VNetName" \
  --name snet-db \
  --address-prefixes 10.0.17.0/24 \
  --delegations "Microsoft.DBforPostgreSQL/flexibleServers"
```

Create the subnet for Private Endpoints:
```bash
az network vnet subnet create \
  --resource-group "$ResourceGroup" \
  --vnet-name "$VNetName" \
  --name snet-endpoints \
  --address-prefixes 10.0.18.0/24
```

---

## 3. Managed Identity & Key Vault

### Step 3.1: Create User-Assigned Managed Identity
This identity is used by AKS workloads to authenticate securely to Key Vault and PostgreSQL.
```bash
az identity create --name "$UserIdentityName" --resource-group "$ResourceGroup"
```

### Step 3.2: Create Azure Key Vault
```bash
az keyvault create \
  --name "$KeyVaultName" \
  --resource-group "$ResourceGroup" \
  --location "$Location" \
  --enable-rbac-authorization true
```

### Step 3.3: Assign Key Vault Secrets User Role
Grant the user-assigned identity read permission to the Key Vault:
```bash
# Get resource ID of Key Vault and client/principal IDs of Managed Identity
KeyVaultId=$(az keyvault show --name "$KeyVaultName" --query id -o tsv)
IdentityPrincipalId=$(az identity show --name "$UserIdentityName" --resource-group "$ResourceGroup" --query principalId -o tsv)

# Assign Key Vault Secrets User role to Managed Identity
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee "$IdentityPrincipalId" \
  --scope "$KeyVaultId"
```

### Step 3.4: Seed Vault Secrets
Generate placeholder values or substitute them with your real credentials:
```bash
az keyvault secret set --vault-name "$KeyVaultName" --name "google-client-id" --value "YOUR_GOOGLE_CLIENT_ID"
az keyvault secret set --vault-name "$KeyVaultName" --name "google-client-secret" --value "YOUR_GOOGLE_CLIENT_SECRET"
az keyvault secret set --vault-name "$KeyVaultName" --name "session-secret" --value "YOUR_SESSION_SECRET_32_CHAR_STRING"
az keyvault secret set --vault-name "$KeyVaultName" --name "postgres-password" --value "YOUR_SECURE_POSTGRES_PASSWORD"
az keyvault secret set --vault-name "$KeyVaultName" --name "gemini-api-key" --value "YOUR_GEMINI_API_KEY"
az keyvault secret set --vault-name "$KeyVaultName" --name "azure-openai-key" --value "YOUR_AZURE_OPENAI_API_KEY"
az keyvault secret set --vault-name "$KeyVaultName" --name "redis-password" --value ""
```

---

## 4. Container Registry (ACR) & Cache for Redis

### Step 4.1: Create Container Registry
```bash
az acr create --resource-group "$ResourceGroup" --name "$AcrName" --sku Standard
```

### Step 4.2: Skip Azure Cache for Redis (Using Local Pod Sidecars)
Azure Cache for Redis is skipped here because we run a local Redis container sidecar directly within the `api-service` Kubernetes pod (bound to `127.0.0.1:6379`) to manage user session boundaries efficiently. This avoids PaaS costs and subscription policy limitations. No CLI command is required for Redis provisioning.

---

## 5. PostgreSQL Database Flexible Server

Create the server with public access and configure a firewall rule to allow secure internal connections from AKS pods. Enable Entra ID authentication and map the Managed Identity.

### Step 5.1: Create PostgreSQL Server (Public Access with Firewall Control)
```bash
az postgres flexible-server create \
  --resource-group "$ResourceGroup" \
  --name "$PostgresName" \
  --location "$Location" \
  --admin-user dbadmin \
  --admin-password "YOUR_SECURE_POSTGRES_PASSWORD" \
  --sku-name Standard_B1ms \
  --tier Burstable \
  --public-access Enabled
```

### Step 5.2: Create Firewall Rule to Allow AKS Connections
Allow AKS and internal resources to connect to the database server:
```bash
az postgres flexible-server firewall-rule create \
  --resource-group "$ResourceGroup" \
  --name "$PostgresName" \
  --rule-name AllowAllAzureIPs \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0
```

### Step 5.3: Enable Entra ID Auth and Set Identity Admin
```bash
# Enable Entra ID authentication
az postgres flexible-server update \
  --resource-group "$ResourceGroup" \
  --name "$PostgresName" \
  --microsoft-entra-auth Enabled

# Set our User-Assigned Managed Identity as Entra Admin
az postgres flexible-server microsoft-entra-admin create \
  --resource-group "$ResourceGroup" \
  --server-name "$PostgresName" \
  --display-name "$UserIdentityName" \
  --object-id "$IdentityPrincipalId" \
  --type ServicePrincipal
```

### Step 5.4: Create Database Resource
```bash
az postgres flexible-server db create \
  --resource-group "$ResourceGroup" \
  --server-name "$PostgresName" \
  --database-name aeroinbox
```

---

## 6. Service Bus Namespace & Queue

```bash
# Create Service Bus Namespace
az servicebus namespace create \
  --resource-group "$ResourceGroup" \
  --name "$ServiceBusName" \
  --location "$Location" \
  --sku Standard

# Create Meeting Reminders Queue
az servicebus queue create \
  --resource-group "$ResourceGroup" \
  --namespace-name "$ServiceBusName" \
  --name meeting-reminders
```

---

## 7. Azure Kubernetes Service (AKS) Cluster

### Step 7.1: Create AKS Cluster
Create the cluster using Azure CNI, enabling Workload Identity, OIDC Issuer, and App Routing ingress (which automatically provisions Application Gateway WAF).
```bash
# Retrieve subnet IDs
AksSubnetId=$(az network vnet subnet show --resource-group "$ResourceGroup" --vnet-name "$VNetName" --name snet-aks --query id -o tsv)
AppgwSubnetId=$(az network vnet subnet show --resource-group "$ResourceGroup" --vnet-name "$VNetName" --name snet-appgw --query id -o tsv)

az aks create \
  --resource-group "$ResourceGroup" \
  --name "$AksName" \
  --node-count 1 \
  --node-vm-size Standard_B2s \
  --network-plugin azure \
  --vnet-subnet-id "$AksSubnetId" \
  --attach-acr "$AcrName" \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --enable-addons ingress-appgw \
  --appgw-name "appgw-aeroinbox-prod" \
  --appgw-subnet-id "$AppgwSubnetId"
```

### Step 7.2: Federate Kubernetes Service Accounts
Tie the Kubernetes Service Accounts to the Azure Managed Identity so the pods can fetch Entra tokens without passwords:
```bash
# Retrieve OIDC Issuer URL
AksOidcIssuer=$(az aks show --resource-group "$ResourceGroup" --name "$AksName" --query "oidcIssuerProfile.issuerUrl" -o tsv)

# Federate credential for api-service-sa
az identity federated-credential create \
  --name "api-service-federation" \
  --identity-name "$UserIdentityName" \
  --resource-group "$ResourceGroup" \
  --audience "api://AzureADTokenExchange" \
  --issuer "$AksOidcIssuer" \
  --subject "system:serviceaccount:default:api-service-sa"

# Federate credential for meeting-service-sa
az identity federated-credential create \
  --name "meeting-service-federation" \
  --identity-name "$UserIdentityName" \
  --resource-group "$ResourceGroup" \
  --audience "api://AzureADTokenExchange" \
  --issuer "$AksOidcIssuer" \
  --subject "system:serviceaccount:default:meeting-service-sa"
```

---

## 8. Static Web App (SWA) & Custom Domains

### Step 8.1: Create Static Web App
Replace `<github-token>` and `<github-repo-url>` with your personal tokens and repo.
```bash
az staticwebapp create \
  --name "$SwaName" \
  --resource-group "$ResourceGroup" \
  --location eastasia \
  --source "https://github.com/muvvaalaakash/AI-Powered-Executive-Email-Assistant" \
  --branch aks \
  --app-location "/frontend" \
  --output-location "dist" \
  --login-with-github
```

### Step 8.2: Set Up Custom Domain (Cloudflare / External DNS)
```bash
az staticwebapp hostname set \
  --name "$SwaName" \
  --resource-group "$ResourceGroup" \
  --hostname aeroinbox.qzz.io \
  --validation-method dns-txt-token
```
*Take the generated TXT token code and place it as a `TXT` record on Cloudflare DNS mapping host `@` to the TXT value.*

---

## 9. Build, Push, & Kubernetes Deployments

Run these CLI steps to log in, compile container images locally, push them to ACR, connect to AKS, and apply manifests.

```bash
# Log in to ACR
az acr login --name "$AcrName"

# Build and Push Microservice Images (Run from Repository Root)
docker build -t "${AcrName}.azurecr.io/api-service:latest" ./services/api-service
docker build -t "${AcrName}.azurecr.io/gmail-service:latest" ./services/gmail-service
docker build -t "${AcrName}.azurecr.io/ai-service:latest" ./services/ai-service
docker build -t "${AcrName}.azurecr.io/rule-engine:latest" ./services/rule-engine
docker build -t "${AcrName}.azurecr.io/meeting-service:latest" ./services/meeting-service

docker push "${AcrName}.azurecr.io/api-service:latest"
docker push "${AcrName}.azurecr.io/gmail-service:latest"
docker push "${AcrName}.azurecr.io/ai-service:latest"
docker push "${AcrName}.azurecr.io/rule-engine:latest"
docker push "${AcrName}.azurecr.io/meeting-service:latest"

# Get credentials for AKS
az aks get-credentials --resource-group "$ResourceGroup" --name "$AksName"

# Create Service Bus credentials secret inside AKS (Required by meeting-service)
SbConnectionString=$(az servicebus namespace authorization-rule keys list \
  --resource-group "$ResourceGroup" \
  --namespace-name "$ServiceBusName" \
  --name RootManageSharedAccessKey \
  --query primaryConnectionString -o tsv)

kubectl create secret generic meeting-service-secrets \
  --from-literal=SERVICE_BUS_CONNECTION_STRING="$SbConnectionString"

# Apply manifest files
kubectl apply -f k8s/deployments.yaml
kubectl apply -f k8s/services.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/network-policies.yaml
kubectl apply -f k8s/hpa.yaml
```
