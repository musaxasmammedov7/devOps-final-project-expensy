# Outputs для использования в других конфигурациях

output "resource_group_name" {
  value       = azurerm_resource_group.expensy.name
  description = "Name of the resource group"
}

output "key_vault_id" {
  value       = azurerm_key_vault.expensy.id
  description = "ID of the Key Vault"
}

output "key_vault_name" {
  value       = azurerm_key_vault.expensy.name
  description = "Name of the Key Vault"
}

output "key_vault_url" {
  value       = azurerm_key_vault.expensy.vault_uri
  description = "URL of the Key Vault"
}

output "service_principal_client_id" {
  value       = azuread_service_principal.expensy.client_id
  description = "Client ID of the Service Principal"
  sensitive   = true
}

output "service_principal_object_id" {
  value       = azuread_service_principal.expensy.object_id
  description = "Object ID of the Service Principal"
}

output "service_principal_client_secret" {
  value       = azuread_service_principal_password.expensy.value
  description = "Client Secret of the Service Principal"
  sensitive   = true
}

output "tenant_id" {
  value       = data.azurerm_client_config.current.tenant_id
  description = "Azure Tenant ID"
}

output "subscription_id" {
  value       = data.azurerm_client_config.current.subscription_id
  description = "Azure Subscription ID"
}

# Output для генерации kubernetes secret
output "kubernetes_secret_manifest" {
  value = <<-EOF
apiVersion: v1
kind: Secret
metadata:
  name: azure-sp-credentials
  namespace: external-secrets
type: Opaque
stringData:
  client-id: "${azuread_service_principal.expensy.client_id}"
  client-secret: "${azuread_service_principal_password.expensy.value}"
  tenant-id: "${data.azurerm_client_config.current.tenant_id}"
EOF
  description = "Kubernetes Secret manifest for external-secrets"
  sensitive   = true
}

# Output для ClusterSecretStore
output "cluster_secret_store_manifest" {
  value = <<-EOF
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: azure-keyvault-backend
spec:
  provider:
    azurekv:
      authType: ServicePrincipal
      vaultUrl: "${azurerm_key_vault.expensy.vault_uri}"
      tenantId: "${data.azurerm_client_config.current.tenant_id}"
      authSecretRef:
        clientId:
          name: azure-sp-credentials
          key: client-id
          namespace: external-secrets
        clientSecret:
          name: azure-sp-credentials
          key: client-secret
          namespace: external-secrets
EOF
  description = "Kubernetes ClusterSecretStore manifest"
}
