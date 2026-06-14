terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Remote state is wired at apply time (Phase 13), never in Phase 0. Example:
  # backend "azurerm" {
  #   resource_group_name  = "rg-quoteassist-tfstate"
  #   storage_account_name = "quoteassisttfstate"
  #   container_name       = "tfstate"
  #   key                  = "dev.tfstate"
  # }
}
