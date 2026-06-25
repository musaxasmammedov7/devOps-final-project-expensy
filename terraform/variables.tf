variable "azure_subscription_id" {
  description = "Azure Subscription ID"
  type        = string
  sensitive   = true
}

variable "azure_tenant_id" {
  description = "Azure Tenant ID"
  type        = string
  sensitive   = true
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "expensy-rg"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "westeurope"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be 'dev', 'staging', or 'prod'."
  }
}

variable "key_vault_name" {
  description = "Name of the Key Vault"
  type        = string
  default     = "expensy-vault-kv"
  validation {
    condition     = can(regex("^[a-z0-9-]{3,24}$", var.key_vault_name))
    error_message = "Key Vault name must be 3-24 characters, lowercase letters, numbers, and hyphens only."
  }
}

variable "service_principal_name" {
  description = "Name of the Service Principal"
  type        = string
  default     = "expensy-sp"
}

variable "key_vault_soft_delete_retention_days" {
  description = "Number of days to retain soft deleted Key Vault"
  type        = number
  default     = 7
}

variable "key_vault_sku" {
  description = "SKU of the Key Vault"
  type        = string
  default     = "standard"
  validation {
    condition     = contains(["standard", "premium"], var.key_vault_sku)
    error_message = "Key Vault SKU must be 'standard' or 'premium'."
  }
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Project     = "Expensy"
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}

variable "key_vault_access_bypass" {
  description = "Bypass rules for Key Vault network"
  type        = string
  default     = "AzureServices"
}
