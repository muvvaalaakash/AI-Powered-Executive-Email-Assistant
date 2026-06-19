# AeroInbox Infrastructure Deployment Guide (Azure Verified Modules)

This directory contains the production-ready Terraform configuration for provisioning the AeroInbox cloud resources using official **Azure Verified Modules (AVM)** in a flat root model.

---

## Step 1: Bootstrap State Storage Account

Before running `terraform init`, you must create the Azure Storage Account and Blob Container that will host the Terraform state file. Follow either the **Azure CLI** or **Azure Portal (UI)** instructions below:

### Option A: Using Azure CLI (Recommended)

1. Open your terminal and log in:
   ```bash
   az login
   ```
2. Run the following commands to create the Resource Group, Storage Account, and Blob Container:
   ```bash
   # 1. Create a dedicated Resource Group for state storage
   az group create --name rg-aeroinbox-tfstate --location centralindia

   # 2. Create the Storage Account (must be globally unique)
   az storage account create \
     --name staeroinboxtfstate \
     --resource-group rg-aeroinbox-tfstate \
     --location centralindia \
     --sku Standard_LRS \
     --allow-blob-public-access false

   # 3. Create the Blob Container
   az storage container create \
     --name tfstate \
     --account-name staeroinboxtfstate \
     --auth-mode login
   ```

---

### Option B: Using the Azure Portal (UI)

1. **Create the Resource Group**:
   * Navigate to the [Azure Portal](https://portal.azure.com).
   * Search for **Resource groups** and click **Create**.
   * Select your Subscription.
   * Enter `rg-aeroinbox-tfstate` as the Name.
   * Choose `Central India` as the Region.
   * Click **Review + create**, then click **Create**.

2. **Create the Storage Account**:
   * Search for **Storage accounts** and click **Create**.
   * Under **Project details**, select Subscription and the Resource Group `rg-aeroinbox-tfstate`.
   * Under **Instance details**, enter `staeroinboxtfstate` as the Storage account name.
   * Select `Central India` as the Region.
   * Set Performance to **Standard** and Redundancy to **Locally-redundant storage (LRS)**.
   * Under **Advanced**, ensure **Allow enabling public access on individual containers** is **unchecked**.
   * Click **Review + create**, then click **Create**. Wait for deployment to complete.

3. **Create the Blob Container**:
   * Navigate to your newly created Storage Account (`staeroinboxtfstate`).
   * In the left-hand menu, under **Data storage**, click **Containers**.
   * Click **+ Container**.
   * Set Name to `tfstate`.
   * Set Anonymous access level to **Private (no anonymous access)**.
   * Click **Create**.

---

## Step 2: Initialize & Deploy Infrastructure

Once the storage account is ready, navigate to the `infrastructure-avm` directory on your local machine and run the deployment steps:

1. **Initialize Terraform**:
   * Connects Terraform to the remote storage account container.
   ```bash
   cd c:\Users\ASUS\OneDrive\Desktop\Ai_Assistan_Email\infrastructure-avm
   terraform init
   ```

2. **Validate Configuration**:
   * Confirms the syntax and verified module schemas are 100% correct.
   ```bash
   terraform validate
   ```

3. **Run Plan (Dry Run)**:
   * Displays the list of all 11 resources that will be provisioned.
   ```bash
   terraform plan
   ```

4. **Apply Deployment**:
   * Executes the creation of resources in your subscription.
   ```bash
   terraform apply
   ```

---

## Workload Identity Integration

This Terraform configuration automatically provisions the **OIDC Federated Credentials** for your Kubernetes Service Accounts (`api-service-sa` and `meeting-service-sa` in the `default` namespace). This enables your microservice pods to fetch secrets passwordlessly from Azure Key Vault and authenticate with PostgreSQL.

### Action Required Post-Deployment:
After running `terraform apply`, you will receive the Managed Identity's client ID in the Terraform outputs as `managed_identity_client_id`. You **must** update the `azure.workload.identity/client-id` annotation in your [deployments.yaml](file:///c:/Users/ASUS/OneDrive/Desktop/Ai_Assistan_Email/k8s/deployments.yaml#L7-L15) file:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-service-sa # Do the same for meeting-service-sa
  namespace: default
  annotations:
    azure.workload.identity/client-id: "<INSERT_OUTPUT_managed_identity_client_id>"
```

---

## Deployed Resources Map

| Service | Resource Name | Region | Description |
| :--- | :--- | :--- | :--- |
| **Resource Group** | `rg-aeroinbox-prod` | Central India | Holds all application resources |
| **VNet** | `vnet-aeroinbox-prod` | Central India | Contains 4 delegated and private subnets |
| **Managed Identity** | `id-aeroinbox-prod` | Central India | Production User-Assigned Identity |
| **Key Vault** | `kv-aeroinbox-prod` | Central India | Secure secrets vault with RBAC |
| **Container Registry** | `acraeroinboxprod` | Central India | Private Docker registry (Standard SKU) |
| **PostgreSQL DB** | `pg-aeroinbox-prod` | Central India | Flexible delegated Private Server (Pg 15) |
| **Redis Cache** | `redis-aeroinbox-prod` | Central India | Basic tier session token storage |
| **Service Bus** | `sb-aeroinbox-prod` | Central India | Holds the `meeting-reminders` queue |
| **AKS Cluster** | `aks-aeroinbox-prod` | Central India | Standard Kubernetes cluster with Container Insights |
| **Static Web App** | `swa-aeroinbox-prod` | East Asia | Frontend client static website host |
| **Application Gateway IP** | `pip-appgw-aeroinbox-prod` | Central India | Public IP for ingress routing |
