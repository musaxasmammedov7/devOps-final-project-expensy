terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "expensy" {
  name     = var.resource_group_name
  location = var.location

  tags = merge(
    var.tags,
    {
      CreatedAt = timestamp()
    }
  )
}

# Service Principal для экстернальных секретов
resource "azuread_service_principal" "expensy" {
  client_id = azuread_application.expensy.client_id

  tags = ["expensy", "external-secrets"]
}

# Azure AD Application (для Service Principal)
resource "azuread_application" "expensy" {
  display_name = var.service_principal_name

  tags = ["expensy"]
}

# Client Secret для Service Principal (действителен 10 лет)
resource "azuread_service_principal_password" "expensy" {
  service_principal_id = azuread_service_principal.expensy.id
  end_date_relative   = "87600h" # 10 лет
}

# Key Vault
resource "azurerm_key_vault" "expensy" {
  name                        = var.key_vault_name
  location                    = azurerm_resource_group.expensy.location
  resource_group_name         = azurerm_resource_group.expensy.name
  enabled_for_disk_encryption = true
  enabled_for_deployment      = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = var.key_vault_sku

  soft_delete_retention_days  = var.key_vault_soft_delete_retention_days
  purge_protection_enabled    = false

  tags = var.tags
}

# Network rules для Key Vault
resource "azurerm_key_vault_network_acl" "expensy" {
  key_vault_id       = azurerm_key_vault.expensy.id
  bypass             = [var.key_vault_access_bypass]
  default_action     = "Allow"
}

# Access Policy для Service Principal на Key Vault
resource "azurerm_key_vault_access_policy" "service_principal" {
  key_vault_id       = azurerm_key_vault.expensy.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = azuread_service_principal.expensy.object_id

  key_permissions = [
    "Get",
    "List",
  ]

  secret_permissions = [
    "Get",
    "List",
  ]

  certificate_permissions = [
    "Get",
    "List",
  ]
}

# Access Policy для текущего пользователя (для управления через Terraform)
resource "azurerm_key_vault_access_policy" "current_user" {
  key_vault_id = azurerm_key_vault.expensy.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Create",
    "Delete",
    "Get",
    "List",
    "Purge",
    "Recover",
    "Update",
  ]

  secret_permissions = [
    "Backup",
    "Delete",
    "Get",
    "List",
    "Purge",
    "Recover",
    "Restore",
    "Set",
  ]

  certificate_permissions = [
    "Create",
    "Delete",
    "Get",
    "List",
    "Purge",
    "Update",
  ]
}

# Example: Сохранение Service Principal credentials в Key Vault
resource "azurerm_key_vault_secret" "client_id" {
  name         = "expensy-client-id"
  value        = azuread_service_principal.expensy.client_id
  key_vault_id = azurerm_key_vault.expensy.id

  tags = var.tags
}

resource "azurerm_key_vault_secret" "client_secret" {
  name         = "expensy-client-secret"
  value        = azuread_service_principal_password.expensy.value
  key_vault_id = azurerm_key_vault.expensy.id

  tags = var.tags
}

resource "azurerm_key_vault_secret" "tenant_id" {
  name         = "expensy-tenant-id"
  value        = data.azurerm_client_config.current.tenant_id
  key_vault_id = azurerm_key_vault.expensy.id

  tags = var.tags
}
