resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location
  tags     = var.tags
}

# 1. Network: Azure Verified Module
module "vnet" {
  source    = "Azure/avm-res-network-virtualnetwork/azurerm"
  version   = "0.17.1"
  parent_id = azurerm_resource_group.main.id
  location  = var.location
  name      = "vnet-${var.project_name}-${var.environment}"
  address_space       = ["10.0.0.0/16"]

  subnets = {
    snet-aks = {
      name             = "snet-aks"
      address_prefixes = ["10.0.0.0/20"]
    }
    snet-appgw = {
      name             = "snet-appgw"
      address_prefixes = ["10.0.16.0/24"]
    }
    snet-db = {
      name             = "snet-db"
      address_prefixes = ["10.0.17.0/24"]
      delegations = [{
        name = "pg-delegation"
        service_delegation = {
          name = "Microsoft.DBforPostgreSQL/flexibleServers"
        }
      }]
    }
    snet-endpoints = {
      name             = "snet-endpoints"
      address_prefixes = ["10.0.18.0/24"]
    }
  }
  tags = var.tags
}

# 2. Managed Identity: Azure Verified Module
module "managed_identity" {
  source              = "Azure/avm-res-managedidentity-userassignedidentity/azurerm"
  version             = "0.5.0"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  name                = "id-${var.project_name}-${var.environment}"
  tags                = var.tags
}

# 3. Key Vault: Azure Verified Module
module "keyvault" {
  source              = "Azure/avm-res-keyvault-vault/azurerm"
  version             = "0.9.1"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  name                = "kv-${var.project_name}-${var.environment}"
  tenant_id           = var.tenant_id

  role_assignments = {
    secrets_user = {
      principal_id               = module.managed_identity.resource.principal_id
      role_definition_id_or_name = "Key Vault Secrets User"
    }
  }
  tags = var.tags
}

# 4. Container Registry: Azure Verified Module
module "acr" {
  source                  = "Azure/avm-res-containerregistry-registry/azurerm"
  version                 = "0.5.1"
  resource_group_name     = azurerm_resource_group.main.name
  location                = var.location
  name                    = "acr${var.project_name}${var.environment}"
  sku                     = "Standard"
  admin_enabled           = true
  zone_redundancy_enabled = false
  tags                    = var.tags
}

# 5. PostgreSQL Flexible Server: Azure Verified Module
# 5a. Private DNS Zone for PostgreSQL Flexible Server
resource "azurerm_private_dns_zone" "postgresql" {
  name                = "${var.project_name}-postgres-dns.private.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

# Link Private DNS Zone to the VNet
resource "azurerm_private_dns_zone_virtual_network_link" "postgresql" {
  name                  = "link-postgres-dns-to-vnet"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.postgresql.name
  virtual_network_id    = module.vnet.resource_id
  registration_enabled  = false
  tags                  = var.tags
}

# 5. PostgreSQL Flexible Server: Azure Verified Module
module "postgresql" {
  source              = "Azure/avm-res-dbforpostgresql-flexibleserver/azurerm"
  version             = "0.2.2"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  name                = "pg-${var.project_name}-${var.environment}"
  sku_name            = "B_Standard_B1ms"
  storage_mb          = 32768
  server_version      = "15"

  delegated_subnet_id = module.vnet.subnets["snet-db"].resource_id
  private_dns_zone_id = azurerm_private_dns_zone.postgresql.id

  authentication = {
    active_directory_auth_enabled = true
    password_auth_enabled         = false
    tenant_id                     = var.tenant_id
  }

  high_availability = null

  ad_administrator = {
    admin = {
      tenant_id      = var.tenant_id
      object_id      = module.managed_identity.resource.principal_id
      principal_name = "id-${var.project_name}-${var.environment}"
      principal_type = "ServicePrincipal"
    }
  }
  tags = var.tags

  managed_identities = {
    user_assigned_resource_ids = [module.managed_identity.resource_id]
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.postgresql
  ]
}


# 6. Redis: Azure Managed Redis
resource "azurerm_managed_redis" "redis" {
  name                = "redis-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku_name            = "Balanced_B0"
  tags                = var.tags

  default_database {
  }
}

# 7. Service Bus Namespace: Azure Verified Module
module "servicebus" {
  source              = "Azure/avm-res-servicebus-namespace/azurerm"
  version             = "0.4.0"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  name                = "sb-${var.project_name}-${var.environment}"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_servicebus_queue" "reminders" {
  name         = "meeting-reminders"
  namespace_id = module.servicebus.resource.id
}

# 8. Log Analytics Workspace: Core logging resource
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# 9. AKS Cluster: Azure Verified Module (with OMS agent Container Insights enabled)
module "aks" {
  source    = "Azure/avm-res-containerservice-managedcluster/azurerm"
  version   = "0.6.1"
  parent_id = azurerm_resource_group.main.id
  location  = var.location
  name      = "aks-${var.project_name}-${var.environment}"

  dns_prefix          = "aks-${var.project_name}-${var.environment}"
  
  # Enable OIDC and Workload Identity
  oidc_issuer_profile = {
    enabled = true
  }
  security_profile = {
    workload_identity = {
      enabled = true
    }
  }

  default_agent_pool = {
    name           = "agentpool"
    vm_size        = "Standard_B2s_v2"
    count_of       = 2
    vnet_subnet_id = module.vnet.subnets["snet-aks"].resource_id
  }

  network_profile = {
    service_cidr   = "172.16.0.0/16"
    dns_service_ip = "172.16.0.10"
  }

  # Ingress Web Application Routing
  ingress_profile = {
    web_app_routing = {
      enabled               = true
      dns_zone_resource_ids = []
    }
  }

  # Native built-in Monitoring and Observability (Container Insights OMS Agent)
  addon_profile_oms_agent = {
    enabled = true
    config = {
      log_analytics_workspace_resource_id = azurerm_log_analytics_workspace.main.id
      use_aad_auth                        = true
    }
  }

  addon_profile_key_vault_secrets_provider = {
    enabled = true
  }

  workload_auto_scaler_profile = {
    keda = {
      enabled = true
    }
  }

  tags = var.tags
}

# 9a. Role Assignment: Grant AKS Kubelet identity permission to pull from ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = module.aks.kubelet_identity.objectId
  role_definition_name             = "AcrPull"
  scope                            = module.acr.resource.id
  skip_service_principal_aad_check = true
}

# 10. Static Web App: Core frontend client CDN hosting
resource "azurerm_static_web_app" "main" {
  name                = "swa-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = "eastasia"
  sku_tier            = "Free"
  sku_size            = "Free"
  tags                = var.tags
}

# 11. Application Gateway Public IP
resource "azurerm_public_ip" "appgw" {
  name                = "pip-appgw-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# 12. Federated Identity Credentials for Workload Identity
resource "azurerm_federated_identity_credential" "api_service" {
  name                = "api-service-federation"
  resource_group_name = azurerm_resource_group.main.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.aks.oidc_issuer_profile_issuer_url
  parent_id           = module.managed_identity.resource_id
  subject             = "system:serviceaccount:aeroinbox:api-service-sa"
}

resource "azurerm_federated_identity_credential" "meeting_service" {
  name                = "meeting-service-federation"
  resource_group_name = azurerm_resource_group.main.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.aks.oidc_issuer_profile_issuer_url
  parent_id           = module.managed_identity.resource_id
  subject             = "system:serviceaccount:aeroinbox:meeting-service-sa"
}
