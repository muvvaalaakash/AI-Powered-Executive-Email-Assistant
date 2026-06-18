variable "project_name" {
  type        = string
  description = "The name of the project (e.g. aeroinbox)"
  default     = "aeroinbox"
}

variable "environment" {
  type        = string
  description = "The deployment environment (e.g. prod, dev, staging)"
  default     = "prod"
}

variable "location" {
  type        = string
  description = "The primary Azure region for resource provisioning"
  default     = "Central India"
}

variable "tenant_id" {
  type        = string
  description = "The Tenant ID of the Microsoft Entra directory"
}

variable "subscription_id" {
  type        = string
  description = "The Subscription ID of the active Azure subscription"
}

variable "tags" {
  type        = map(string)
  description = "Common tags applied to all provisioned resources"
  default = {
    Project     = "AeroInbox"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
