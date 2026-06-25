# Terraform Expensy - Azure Infrastructure

Этот директорий содержит Terraform конфигурацию для полной автоматизации создания:
- Azure Resource Group
- Azure Service Principal
- Azure Key Vault
- Правила доступа (RBAC)

**🚀 Все управляется через GitHub Actions пайплайн!**

## Структура файлов

- `provider.tf` - Конфигурация провайдеров (Azure RM и Azure AD)
- `variables.tf` - Переменные (настраиваемые параметры)
- `main.tf` - Основная конфигурация ресурсов
- `outputs.tf` - Outputs для использования в других местах
- `terraform.tfvars.example` - Пример файла переменных

## Как использовать?

### Опция 1: Через GitHub Actions (рекомендуется)

1. Настрой GitHub Secrets (см. [GITHUB_ACTIONS_TERRAFORM.md](../GITHUB_ACTIONS_TERRAFORM.md))
2. Создай Pull Request с изменениями в `terraform/`
3. Пайплайн автоматически:
   - ✅ Валидирует конфигурацию
   - 📊 Создает план
   - 📝 Комментирует результаты в PR
4. После merge в main:
   - 🚀 Автоматически применяет изменения
   - 📝 Генерирует K8s манифесты
   - 📤 Коммитит обновленные файлы

### Опция 2: Локально

Если хочешь работать локально:

## 📚 Команды Terraform (локально)

```bash
cd terraform/

# Инициализировать (скачать провайдеры)
terraform init

# Форматирование
terraform fmt -recursive

# Валидация
terraform validate

# План (посмотреть что изменится)
terraform plan

# Применить изменения
terraform apply

# Посмотреть outputs
terraform output

# Удалить всё
terraform destroy
```

## Файлы для gitignore

Убедитесь, что в `.gitignore` добавлены:

```
# Terraform
terraform/.terraform/
terraform/.terraform.lock.hcl
terraform/terraform.tfstate*
terraform/terraform.tfvars
terraform/.tfvars

# Kubernetes secrets
gitops/external-secrets/azure-sp-secret.yaml
```

## Применение манифестов в кластер

После того как GitHub Actions пайплайн создал K8s манифесты:

```bash
# 1. Создайте namespace (если его нет)
kubectl create namespace external-secrets

# 2. Примените Secret (вручную, так как это критичный ресурс)
kubectl apply -f ../gitops/external-secrets/azure-sp-secret.yaml

# 3. Примените ClusterSecretStore (синхронизируется через ArgoCD)
kubectl apply -f ../gitops/external-secrets/cluster-secret-store.yaml

# 4. Проверьте
kubectl get secret -n external-secrets
kubectl get clustersecretstore
```

## 🔄 GitHub Actions Пайплайн

Полная документация по настройке GitHub Actions: [GITHUB_ACTIONS_TERRAFORM.md](../GITHUB_ACTIONS_TERRAFORM.md)

## Команды Terraform

```bash
# План (что будет создано)
terraform plan

# Применить изменения
terraform apply

# Уничтожить всё
terraform destroy

# Посмотреть outputs
terraform output

# Вывести конкретный output (без кавычек)
terraform output -raw service_principal_client_id
```

## Outputs

После `terraform apply` доступны outputs:

```bash
terraform output resource_group_name
terraform output key_vault_name
terraform output key_vault_url
terraform output service_principal_client_id
terraform output tenant_id
terraform output subscription_id
```

## Обновление существующих ресурсов

Если вам нужно изменить параметры:

1. Отредактируйте `terraform.tfvars.example`
2. Создайте Pull Request с изменениями
3. GitHub Actions пайплайн покажет plan
4. После merge → пайплайн автоматически применит изменения

## Удаление всех ресурсов

Через GitHub Actions:

```bash
# 1. Отредактируй главный файл чтобы добавить destroy флаг
# 2. Создай PR с этим изменением
# 3. После merge → пайплайн применит destroy
```

Локально:

```bash
terraform destroy
```

⚠️ Это удалит:
- Resource Group
- Key Vault
- Service Principal
- Все связанные ресурсы

## Troubleshooting

### Ошибка: "The subscription X is not registered"

```bash
az account set --subscription YOUR_SUBSCRIPTION_ID
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.AD
```

### Ошибка при доступе к Key Vault

Убедитесь, что у вас есть права на управление Key Vault в Azure:
```bash
az role assignment list --query "[].principalName" -o tsv
```

### Пересоздание всех ресурсов

```bash
terraform destroy
terraform apply
./apply-and-sync.sh
```

## Дополнительно

- Документация: https://registry.terraform.io/providers/hashicorp/azurerm
- Azure AD Provider: https://registry.terraform.io/providers/hashicorp/azuread
