provider "azurerm" {
  features {}
}

module "stack" {
  source                  = "../../modules/stack"
  env                     = "staging"
  location                = var.location
  postgres_password       = var.postgres_password
  postgres_zone_redundant = false
}
