output "resource_group_name" {
  value       = azurerm_resource_group.main.name
  description = "The name of the provisioned Resource Group"
}

output "vnet_name" {
  value       = module.vnet.name
  description = "The name of the Virtual Network"
}

output "vnet_subnets" {
  value       = module.vnet.subnets
  description = "Detailed list of subnets created inside the Virtual Network"
}

output "managed_identity_id" {
  value       = module.managed_identity.resource.id
  description = "The Resource ID of the User-Assigned Managed Identity"
}

output "managed_identity_client_id" {
  value       = module.managed_identity.resource.client_id
  description = "The Client ID of the User-Assigned Managed Identity"
}

output "managed_identity_principal_id" {
  value       = module.managed_identity.resource.principal_id
  description = "The Principal/Object ID of the User-Assigned Managed Identity"
}

output "acr_login_server" {
  value       = module.acr.resource.login_server
  description = "The login server URI of the Container Registry"
}

output "key_vault_uri" {
  value       = module.keyvault.uri
  description = "The vault URI of the Azure Key Vault"
}

output "postgres_server_fqdn" {
  value       = module.postgresql.fqdn
  description = "The Fully Qualified Domain Name of the PostgreSQL server"
}

output "redis_hostname" {
  value       = module.redis.resource.hostname
  description = "The hostname of the Azure Cache for Redis server"
  sensitive   = true
}

output "service_bus_namespace_id" {
  value       = module.servicebus.resource.id
  description = "The Resource ID of the Service Bus Namespace"
  sensitive   = true
}

output "aks_cluster_name" {
  value       = module.aks.name
  description = "The name of the AKS managed cluster"
}

output "aks_oidc_issuer_url" {
  value       = module.aks.oidc_issuer_profile_issuer_url
  description = "The OIDC Issuer URL of the AKS cluster"
}

output "swa_default_hostname" {
  value       = azurerm_static_web_app.main.default_host_name
  description = "The default URL of the Static Web App"
}

output "appgw_public_ip_address" {
  value       = azurerm_public_ip.appgw.ip_address
  description = "The public IP address of the Application Gateway"
}
