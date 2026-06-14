provider "azurerm" {
  features {}
}

# Production sizing: zone-redundant Postgres (read replica added at apply time,
# Phase 13). Applied only after UAT sign-off.
module "stack" {
  source                  = "../../modules/stack"
  env                     = "prod"
  location                = var.location
  postgres_password       = var.postgres_password
  postgres_zone_redundant = true
}
