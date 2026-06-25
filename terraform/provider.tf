terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }

  # Раскомментируй для remote state в Azure Storage
  # backend "azurerm" {
  #   resource_group_name  = "expensy-rg"
  #   storage_account_name = "expensystate"
  #   container_name       = "tfstate"
  #   key                  = "prod.terraform.tfstate"
  # }
}

provider "azurerm" {
  features {
    key_vault {
      # Разрешаем удаление Key Vault при destroy
      purge_soft_delete_on_destroy = true
    }
  }
}

provider "azuread" {
}
