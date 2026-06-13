# Manual Azure Portal Deployment Guide: AKS Hybrid Cloud Architecture

This guide provides step-by-step instructions for manually provisioning all required cloud infrastructure in the **Central India** (or nearest compatible) region using the Azure Portal UI. 

---

## Region Availability & Setup Verification
All requested resources are fully available in the **Central India** (Central India) region. We will group all resources under a single **Resource Group** in **Central India** to minimize network latency, avoid cross-region egress charges, and simplify access control.

---

## Step 1: Create a Resource Group
1. In the search bar at the top of the Azure Portal, search for **Resource groups**.
2. Click **+ Create**.
3. Configure the settings:
   * **Subscription**: Select your active subscription.
   * **Resource group**: Enter `rg-aeroinbox-prod`.
   * **Region**: Select **(Asia Pacific) Central India**.
4. Click **Review + create**, then click **Create**.

---

## Step 2: Create a Virtual Network (VNet)
To secure our AKS cluster, private databases, and Application Gateway:
1. Search for **Virtual networks** and click **+ Create**.
2. **Basics Tab**:
   * **Resource group**: Select `rg-aeroinbox-prod`.
   * **Name**: Enter `vnet-aeroinbox-prod`.
   * **Region**: Select **Central India**.
3. **IP Addresses Tab**:
   * Set IPv4 address space to `10.0.0.0/16`.
   * Click **+ Add subnet** to define the subnets:
     1. **Subnet name**: `snet-aks` | **Address range**: `10.0.0.0/20` (For AKS pods and nodes).
     2. **Subnet name**: `snet-appgw` | **Address range**: `10.0.16.0/24` (For Ingress Application Gateway WAF).
     3. **Subnet name**: `snet-db` | **Address range**: `10.0.17.0/24` (Delegated for PostgreSQL).
     4. **Subnet name**: `snet-endpoints` | **Address range**: `10.0.18.0/24` (For Private Endpoints).
4. Click **Review + create**, then click **Create**.

---

## Step 3: Create an Azure Container Registry (ACR)
1. Search for **Container registries** and click **+ Create**.
2. Configure the settings:
   * **Resource group**: `rg-aeroinbox-prod`.
   * **Registry name**: Enter a unique name (e.g., `acraeroinboxprod`).
   * **Location**: **Central India**.
   * **SKU**: Select **Standard** (or **Premium** if Private Endpoints are required).
3. Click **Review + create**, then click **Create**.

---

## Step 4: Create Azure Database for PostgreSQL (Flexible Server)
1. Search for **Azure Database for PostgreSQL flexible servers** and click **+ Create**.
2. **Basics Tab**:
   * **Resource group**: `rg-aeroinbox-prod`.
   * **Server name**: Enter a unique name (e.g., `pg-aeroinbox-prod`).
   * **Region**: **Central India**.
   * **Workload type**: Select **Development (B-series burstable)** to optimize costs (e.g., `Standard_B1ms`).
3. **Networking Tab**:
   * **Connectivity method**: Select **Private access (VNet Integration)**.
   * **Virtual network**: `vnet-aeroinbox-prod`.
   * **Subnet**: `snet-db` (allow Azure to delegate the subnet if requested).
4. **Security Tab**:
   * Enable **Microsoft Entra authentication only** (or **Active Directory and PostgreSQL authentication** if you want fallback access).
   * Set your own user account as the **Microsoft Entra Admin**.
5. Click **Review + create**, then click **Create**.

---

## Step 5: Create Azure Cache for Redis
1. Search for **Azure Cache for Redis** and click **+ Create**.
2. Configure the settings:
   * **Resource group**: `rg-aeroinbox-prod`.
   * **DNS name**: Enter a unique name (e.g., `redis-aeroinbox-prod`).
   * **Location**: **Central India**.
   * **Cache type**: Select **Standard C0** (250 MB) or **Basic C0** to optimize costs.
   * **Non-SSL port**: Keep disabled.
3. Click **Review + create**, then click **Create**.

---

## Step 6: Create an Azure Key Vault
1. Search for **Key vaults** and click **+ Create**.
2. **Basics Tab**:
   * **Resource group**: `rg-aeroinbox-prod`.
   * **Key vault name**: Enter a unique name (e.g., `kv-aeroinbox-prod`).
   * **Region**: **Central India**.
   * **Pricing tier**: **Standard**.
3. **Access Configuration Tab**:
   * **Permission model**: Select **Azure role-based access control (Azure RBAC)**.
4. Click **Review + create**, then click **Create**.

---

## Step 7: Create an Azure Service Bus Namespace & Queue
1. Search for **Service Bus** and click **+ Create**.
2. **Basics Tab**:
   * **Resource group**: `rg-aeroinbox-prod`.
   * **Namespace name**: Enter a unique name (e.g., `sb-aeroinbox-prod`).
   * **Location**: **Central India**.
   * **Pricing tier**: **Standard** (Standard tier is required to support queue-triggered autoscaling).
3. Click **Review + create**, then click **Create**.
4. Once deployment completes, navigate to the Service Bus Namespace, click **+ Queue**, name it `meeting-reminders`, and click **Create**.

---

## Step 8: Create the Azure Kubernetes Service (AKS) Cluster
This is our core compute cluster hosting our containerized microservices:
1. Search for **Kubernetes services** and click **+ Create** -> **Create a Kubernetes cluster**.
2. **Basics Tab**:
   * **Resource group**: `rg-aeroinbox-prod`.
   * **Kubernetes cluster name**: `aks-aeroinbox-prod`.
   * **Region**: **Central India**.
   * **Availability zones**: Select **None** (to optimize dev costs) or leave default for HA.
   * **API server availability**: **99.5%** (free tier).
3. **Node Pools Tab**:
   * Edit the default `agentpool` to use a cost-effective SKU like `Standard_B2s` or `Standard_D2s_v5`.
4. **Networking Tab**:
   * **Network configuration**: Select **Azure CNI (Node subnet)**.
   * **Virtual network**: `vnet-aeroinbox-prod`.
   * **Network subnet**: `snet-aks`.
   * **Kubernetes ingress provider**: Check **Application Routing** or **Web Application Routing** (this enables AGIC / App Gateway integration).
     * Set **Application Gateway name** to `appgw-aeroinbox-prod`.
     * Set **Subnet** to `snet-appgw`.
5. **Integrations Tab**:
   * **Container registry**: Select the registry you created in Step 3 (`acraeroinboxprod`). This automatically grants the cluster pulling permissions.
6. **Security Tab**:
   * **Enable Workload Identity**: **Checked (Enabled)**.
   * **Enable OIDC Issuer**: **Checked (Enabled)**.
7. Click **Review + create**, then click **Create**.

---

## Step 9: Create an Azure Function App (Optional)
> [!NOTE]
> This step is **optional**. If your subscription restricts serverless Function App creation, you can skip it. The `meeting-service` container is equipped with an integrated background polling loop that will automatically run inside the pod and handle the 30-minute reminder evaluations directly in the database.
> If you choose to configure the Function App:
1. Search for **Function App** and click **+ Create**.
2. **Basics Tab**:
   * **Resource group**: `rg-aeroinbox-prod`.
   * **Function App name**: Enter a unique name (e.g., `func-aeroinbox-reminders`).
   * **Runtime stack**: **Python**.
   * **Version**: **3.10** or **3.11**.
   * **Region**: **Central India**.
   * **Operating System**: **Linux**.
   * **Plan type**: **Consumption (Serverless)**.
3. Click **Review + create**, then click **Create**.

---

## Step 10: Create an Azure Static Web App (SWA)
For hosting the React SPA frontend client:
1. Search for **Static Web Apps** and click **+ Create**.
2. **Basics Tab**:
   * **Resource group**: `rg-aeroinbox-prod`.
   * **Name**: `swa-aeroinbox-prod`.
   * **Region**: Select **East Asia** or **Southeast Asia** (SWA functions as a global CDN, but metadata stays in the chosen region. East Asia / Southeast Asia are closest to India).
   * **Deployment details**: Select **GitHub** and authorize your account.
   * Select your **Repository** (`AI-Powered-Executive-Email-Assistant`) and branch (`aks`).
   * **Build Presets**: Select **Vite**.
   * **App location**: `/frontend`.
   * **Api location**: Leave blank.
   * **Output location**: `dist`.
3. Click **Review + create**, then click **Create**.

---

## Step 11: Configure Key Vault Secrets (UI)
Ensure your backend microservices can securely retrieve credentials without hardcoding:
1. Navigate to your created **Key Vault** (`kv-aeroinbox-prod`) in the portal.
2. Click on **Objects -> Secrets** in the left sidebar, and click **+ Generate/Import**.
3. Create the following secrets:
   * **`google-client-id`**: Your Google OAuth Web Client ID.
   * **`google-client-secret`**: Your Google OAuth Web Client Secret.
   * **`session-secret`**: A random 32-character string for signing cookie sessions.
   * **`postgres-password`**: The password used for PostgreSQL access (if using hybrid user/password auth).
   * **`gemini-api-key`**: Your Google Gemini API Key.
   * **`redis-password`**: Leave blank (if passwordless) or set your Redis access key.

---

## Step 12: Configure Entra ID Workload Identity & Roles (UI / CLI)
For passwordless auth to Key Vault and PostgreSQL, you must bind your Kubernetes Service Accounts to your Azure Managed Identities.

### 1. Assign Roles to Managed Identity:
1. Navigate to your **Key Vault** -> **Access control (IAM)** -> **Add role assignment**.
   * Role: **Key Vault Secrets User**.
   * Assign access to: **Managed Identity**.
   * Select your AKS Managed Identity (e.g., `aks-aeroinbox-prod-agentpool` or `id-aeroinbox-prod`).
2. Navigate to your **PostgreSQL Flexible Server** -> **Microsoft Entra Manager**.
   * Ensure your Managed Identity is registered as an authorized Entra database user account.

### 2. Federate Kubernetes Service Account:
To let AKS pods trade their Kubernetes tokens for Azure tokens, run these commands (or configure them under the Managed Identity's **Federated credentials** tab in the Portal):
```bash
# Get the OIDC Issuer URL from your AKS cluster
AKS_OIDC_ISSUER=$(az aks show --resource-group rg-aeroinbox-prod --name aks-aeroinbox-prod --query "oidcIssuerProfile.issuerUrl" -o tsv)

# Federate credentials for api-service-sa
az identity federated-credential create \
  --name "api-service-federation" \
  --identity-name "id-aeroinbox-prod" \
  --resource-group rg-aeroinbox-prod \
  --audience "api://AzureADTokenExchange" \
  --issuer "$AKS_OIDC_ISSUER" \
  --subject "system:serviceaccount:default:api-service-sa"

# Federate credentials for meeting-service-sa
az identity federated-credential create \
  --name "meeting-service-federation" \
  --identity-name "id-aeroinbox-prod" \
  --resource-group rg-aeroinbox-prod \
  --audience "api://AzureADTokenExchange" \
  --issuer "$AKS_OIDC_ISSUER" \
  --subject "system:serviceaccount:default:meeting-service-sa"
```

---

## Step 13: Build & Push Docker Images to ACR (CLI)
Compile your microservices on your local machine and push them to your Azure Container Registry:
1. Log in to your Azure account and the container registry:
   ```bash
   az login
   az acr login --name acraeroinboxprod
   ```
2. Navigate to each service folder in your repository and build the Docker images:
   ```bash
   # Build api-service
   docker build -t acraeroinboxprod.azurecr.io/api-service:latest ./services/api-service
   
   # Build gmail-service
   docker build -t acraeroinboxprod.azurecr.io/gmail-service:latest ./services/gmail-service
   
   # Build ai-service
   docker build -t acraeroinboxprod.azurecr.io/ai-service:latest ./services/ai-service
   
   # Build rule-engine
   docker build -t acraeroinboxprod.azurecr.io/rule-engine:latest ./services/rule-engine
   
   # Build meeting-service
   docker build -t acraeroinboxprod.azurecr.io/meeting-service:latest ./services/meeting-service
   ```
3. Push the compiled images to ACR:
   ```bash
   docker push acraeroinboxprod.azurecr.io/api-service:latest
   docker push acraeroinboxprod.azurecr.io/gmail-service:latest
   docker push acraeroinboxprod.azurecr.io/ai-service:latest
   docker push acraeroinboxprod.azurecr.io/rule-engine:latest
   docker push acraeroinboxprod.azurecr.io/meeting-service:latest
   ```

---

## Step 14: Connect and Deploy Manifests to AKS (CLI)
1. Get the access credentials for your newly created AKS cluster:
   ```bash
   az aks get-credentials --resource-group rg-aeroinbox-prod --name aks-aeroinbox-prod
   ```
2. Verify connection to the cluster:
   ```bash
   kubectl get nodes
   ```
3. Update the placeholders in [deployments.yaml](file:///c:/Users/ASUS/OneDrive/Desktop/Ai_Assistan_Email/k8s/deployments.yaml) (e.g., replacement values for `client-id` and database server strings).
4. Apply the Kubernetes configurations in the exact order:
   ```bash
   # 1. Apply deployments & service accounts
   kubectl apply -f k8s/deployments.yaml
   
   # 2. Apply discovery routing services
   kubectl apply -f k8s/services.yaml
   
   # 3. Apply ingress routing mapping (AGIC)
   kubectl apply -f k8s/ingress.yaml
   
   # 4. Apply network policies for pod isolation
   kubectl apply -f k8s/network-policies.yaml
   
   # 5. Apply Horizontal Pod Autoscaler (HPA) rules
   kubectl apply -f k8s/hpa.yaml
   ```

---

## Step 15: Deploy the Serverless Function App (Optional)
> [!NOTE]
> Skip this step if you chose to skip Step 9. If skipped, reminders will still function perfectly using the internal container-level polling scheduler fallback.
1. Make sure you have installed **Azure Functions Core Tools** on your system.
2. Initialize and deploy the function folder:
   ```bash
   cd serverless
   
   # Log in to Azure Function App CLI
   func azure functionapp publish func-aeroinbox-reminders --python
   ```
3. In the Azure Portal:
   * Go to **func-aeroinbox-reminders** -> **Configuration**.
   * Add a new application setting:
     * Name: `ServiceBusConnection` | Value: *[Your Service Bus Namespace primary connection string]*
     * Name: `API_GATEWAY_URL` | Value: *[Your public Application Gateway Ingress FQDN, e.g. https://api.aeroinbox.com]*
   * Save configurations.

---

## Step 16: Verify Deployment and Logs
To check if your application is successfully up and running in the cloud:
1. List all active pods:
   ```bash
   kubectl get pods -w
   ```
2. Fetch logs from the API Gateway to monitor synchronization queries and database cache registrations:
   ```bash
   kubectl logs deployment/api-service -f
   ```
3. Verify that calling the health check URL (`https://<your-app-gateway-ip>/health`) returns a `healthy` status.

---

## Step 17: External Integrations & Google OAuth Console Setup
Before you can log in, you must authorize your new cloud domains in the Google Cloud Console:

1. **Get your endpoints**:
   * **Frontend URL**: Retrieve the default domain of your Azure Static Web App (e.g. `https://blue-tree-05ccc3400.7.azurestaticapps.net`).
   * **Backend URL**: Retrieve the public IP or custom domain pointing to your Azure Application Gateway Ingress (e.g. `https://api.aeroinbox.com`).
2. **Configure Google Cloud Console**:
   * Go to [Google Cloud Console](https://console.cloud.google.com).
   * Navigate to **APIs & Services -> Credentials**.
   * Click the edit icon for your **OAuth 2.0 Client ID** used by the application.
   * **Authorized JavaScript origins**:
     * Add your local dev URL: `http://localhost:5173`.
     * Add your Static Web App domain: `https://<your-static-web-app-domain>`.
   * **Authorized redirect URIs**:
     * Add your local callback: `http://localhost/auth/callback`.
     * Add your production cloud redirect callback: `https://<your-app-gateway-domain>/auth/callback`.
       *(Note: Google OAuth requires redirect URIs to be secure HTTPS URLs; it will reject standard HTTP public IP addresses. Ensure you configure SSL on your Application Gateway).*
3. **Configure Frontend Environment Variable**:
   * In [frontend/.env.production](file:///c:/Users/ASUS/OneDrive/Desktop/Ai_Assistan_Email/frontend/.env.production), update `VITE_API_URL` to point to your new backend Application Gateway domain (e.g. `https://api.aeroinbox.com`).
   * Commit and push this change to trigger a Static Web App rebuild.

