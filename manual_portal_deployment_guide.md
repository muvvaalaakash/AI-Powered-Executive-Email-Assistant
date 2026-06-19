# AeroInbox Azure Portal UI Manual Deployment Guide

This guide provides step-by-step instructions to manually configure and deploy the AeroInbox infrastructure, secrets, routing, and frontend client using the **Azure Portal UI** and **Cloudflare**.

---

## 1. Azure Key Vault Settings & Secrets

### Configure Firewall Access
If public access is restricted on your Key Vault (`kv-aeroinbox-prod`), you must authorize your computer's IP address:
1. Go to **Key Vaults** in the Azure Portal and select **`kv-aeroinbox-prod`**.
2. Click **Networking** in the left menu under **Settings**.
3. Under the **Firewalls and virtual networks** tab:
   * Keep **Allow access from** set to **Selected networks**.
   * Under the **Firewall** section, check the box **Add your client IP address**.
   * Click **Save** at the bottom.

### Generate Secrets
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

## 2. PostgreSQL Flexible Server Custom Database

If you provisioned PostgreSQL Flexible Server using Terraform AVM, the server is created, but the empty target database (`aeroinbox`) must be created manually:
1. Navigate to **Azure Database for PostgreSQL flexible servers** in the portal.
2. Select your server (`pg-aeroinbox-prod`).
3. Click **Databases** on the left menu under **Settings**.
4. Click **+ Add** at the top.
5. Set the database name to **`aeroinbox`**.
6. Set charset to **`UTF8`** and collation to **`en_US.utf8`**, then click **Save**.

---

## 3. Workload Identity & Federated Credentials

AeroInbox microservices use passwordless Entra ID authentication to talk to resources. This requires associating the AKS service accounts with your Azure Managed Identity (`id-aeroinbox-prod`):

1. Go to **Managed Identities** in the portal and select **`id-aeroinbox-prod`**.
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

## 4. Cloudflare DNS Configuration

### A. Frontend (Static Web App: `aeroinbox.qzz.io`)
To route user traffic and verify domain ownership:
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
To route API gateway traffic to your AKS NGINX ingress:
1. In Cloudflare, add an **A** record:
   * **Type:** `A`
   * **Name:** `api`
   * **IPv4 Address:** `4.224.113.88` *(Public LoadBalancer IP)*
   * **Proxy status:** **Proxied** (orange cloud)
2. In the left navigation of Cloudflare, go to **SSL/TLS** -> set encryption mode to **Flexible** (or **Full** if backend uses HTTPS).

---

## 5. Build & Deploy React Frontend Client

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
