# AeroInbox End-to-End Azure Deployment Guide

This guide provides the complete step-by-step flow to deploy AeroInbox from scratch. It covers creating the remote state storage account, running Terraform, configuring Key Vault secrets, setting up databases/workload identities, and setting up DNS routing and the frontend client.

---

## Step 1: Create the Remote State Storage Account (via Azure Portal)

Before running Terraform, you must create a Storage Account to store the Terraform state file (`backend.tf`):

### A. Create the Resource Group
1. Open the [Azure Portal](https://portal.azure.com).
2. Search for **Resource groups** and click **+ Create**.
3. Set the details:
   * **Subscription:** Select your subscription.
   * **Resource group:** `rg-aeroinbox-tfstate`
   * **Region:** `Central India` *(or your preferred region)*.
4. Click **Review + create** -> **Create**.

### B. Create the Storage Account
1. Search for **Storage accounts** and click **+ Create**.
2. Set the details:
   * **Resource Group:** Select `rg-aeroinbox-tfstate`.
   * **Storage account name:** `staeroinboxtfstate` *(must be lowercase, unique, alphanumeric only)*.
   * **Region:** Same as your resource group.
   * **Performance:** `Standard`
   * **Redundancy:** `Locally-redundant storage (LRS)` *(recommended for cost savings)*.
3. Click **Review + create** -> **Create**.

### C. Create the Blob Container
1. Navigate to the newly created storage account (`staeroinboxtfstate`).
2. Under the **Data storage** section on the left menu, click **Containers**.
3. Click **+ Container** at the top.
4. Set the name to **`tfstate`**.
5. Keep public access level as **Private (no anonymous access)**.
6. Click **Create**.

---

## Step 2: Provision Infrastructure using Terraform

Once the backend storage is ready, provision the resources:
1. Open your terminal (e.g., PowerShell) and navigate to the `infrastructure-avm/` directory.
2. Initialize Terraform to fetch modules and hook up the backend state:
   ```powershell
   terraform init
   ```
3. Generate a plan to verify the resources:
   ```powershell
   terraform plan -out=tfplan
   ```
4. Apply the configuration to deploy the VNet, AKS, Postgres, Redis, and Key Vault:
   ```powershell
   terraform apply tfplan
   ```

---

## Step 3: Configure Azure Key Vault Settings & Secrets

Since Key Vault starts with strict network security policies, you must authorize your client IP and add the necessary secrets.

### A. Configure Firewall Access
1. Search for **Key Vaults** in the portal and select **`kv-aeroinbox-prod`**.
2. Click **Networking** in the left menu under **Settings**.
3. Under the **Firewalls and virtual networks** tab:
   * Select **Selected networks**.
   * Under the **Firewall** section, check the box **Add your client IP address**.
   * Click **Save** at the bottom.

### B. Generate Secrets
1. Go to the **Secrets** tab under **Objects** on the left menu.
2. Click **+ Generate/Import**.
3. Create each of the following secrets with **Upload options** set to **Manual**:

| Secret Name | Purpose | Value to Paste |
| :--- | :--- | :--- |
| **`service-bus-connection-string`** | Queue connection string | `Endpoint=sb://sb-aeroinbox-prod.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=<YOUR_SERVICE_BUS_SHARED_ACCESS_KEY>` |
| **`google-client-id`** | Google OAuth client ID | `<YOUR_GOOGLE_CLIENT_ID>` |
| **`google-client-secret`** | Google OAuth client secret | `<YOUR_GOOGLE_CLIENT_SECRET>` |
| **`azure-openai-key`** | Azure OpenAI API Key | `<YOUR_AZURE_OPENAI_KEY>` |
| **`session-secret`** | API Gateway cookie signing key | `<YOUR_SESSION_SECRET_GUID>` |

---

## Step 4: Create the PostgreSQL Flexible Server Database

1. Navigate to **Azure Database for PostgreSQL flexible servers** in the portal.
2. Select your server (`pg-aeroinbox-prod`).
3. Click **Databases** on the left menu under **Settings**.
4. Click **+ Add** at the top.
5. Set the database name to **`aeroinbox`**.
6. Set charset to **`UTF8`** and collation to **`en_US.utf8`**, then click **Save**.

---

## Step 5: Configure Federated Credentials (Workload Identity)

Associate AKS Service Accounts with your Managed Identity (`id-aeroinbox-prod`):

1. Navigate to **Managed Identities** in the portal and select **`id-aeroinbox-prod`**.
2. Click **Federated credentials** under **Settings** on the left menu.
3. Click **+ Add** at the top.
4. Fill in the credentials for the API Service:
   * **Federated credential scenario:** `Kubernetes accessing Azure resources`
   * **Credential name:** `api-service-federation`
   * **Subject identifier:** `system:serviceaccount:aeroinbox:api-service-sa`
   * **Issuer URL:** *(Paste your AKS cluster OIDC Issuer URL)*
5. Repeat the steps to add the credential for the Meeting Service:
   * **Credential name:** `meeting-service-federation`
   * **Subject identifier:** `system:serviceaccount:aeroinbox:meeting-service-sa`
   * **Issuer URL:** *(Paste your AKS cluster OIDC Issuer URL)*
6. Click **Save**.

---

## Step 6: Configure Cloudflare DNS

### A. Frontend (Static Web App: `aeroinbox.qzz.io`)
1. Log in to **Cloudflare** and navigate to your domain DNS settings.
2. Add a **CNAME** record:
   * **Type:** `CNAME`
   * **Name:** `@` *(or `aeroinbox.qzz.io`)*
   * **Target:** `ambitious-rock-087fd9f00.7.azurestaticapps.net`
   * **Proxy status:** **DNS Only** (gray cloud) for verification.
3. Add a **TXT** record:
   * **Type:** `TXT`
   * **Name:** `@` *(or `aeroinbox.qzz.io`)*
   * **Content (Value):** `_lh43odcyxlnb4eryieq5rojjdy8e9ap`
4. Once added, go to **Static Web Apps** in the Azure Portal -> **Custom domains** -> click **Validate** to complete validation. You can now enable the orange cloud proxy in Cloudflare if desired.

### B. Backend (API Ingress: `api.aeroinbox.qzz.io`)
1. In Cloudflare, add an **A** record:
   * **Type:** `A`
   * **Name:** `api`
   * **IPv4 Address:** `4.224.113.88` *(Public LoadBalancer IP)*
   * **Proxy status:** **Proxied** (orange cloud)
2. In the left navigation of Cloudflare, go to **SSL/TLS** -> set encryption mode to **Flexible** (or **Full** if backend uses HTTPS).

---

## Step 7: Build & Deploy React Frontend Client

To deploy your updated frontend React app:
1. Open PowerShell and navigate to your `frontend/` directory.
2. Run the build script to generate static assets:
   ```powershell
   npm.cmd run build
   ```
3. Deploy the compiled files in the `dist` folder to Azure using the SWA CLI:
   ```powershell
   npx.cmd @azure/static-web-apps-cli deploy ./dist --deployment-token "72bb8ac6b467fe25553d53fab30f7ce08ce5719a87a6b237cf24be8bb5294ed607-1d6fc668-3e99-4164-a0eb-bca93594a47f0001518087fd9f00" --env production
   ```
