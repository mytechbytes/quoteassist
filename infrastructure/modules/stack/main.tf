variable "env" {
  type = string
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "name_prefix" {
  type    = string
  default = "quoteassist"
}

variable "postgres_password" {
  type      = string
  sensitive = true
}

variable "platform_image" {
  type    = string
  default = "mcr.microsoft.com/k8se/quickstart:latest"
}

variable "ai_service_image" {
  type    = string
  default = "mcr.microsoft.com/k8se/quickstart:latest"
}

variable "postgres_zone_redundant" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}

data "azurerm_client_config" "current" {}

locals {
  base = "${var.name_prefix}-${var.env}"
  tags = merge(var.tags, {
    application = "quoteassist"
    environment = var.env
    managed_by  = "terraform"
  })
}

module "resource_group" {
  source   = "../resource_group"
  name     = "rg-${local.base}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${local.base}"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_container_app_environment" "this" {
  name                       = "cae-${local.base}"
  resource_group_name        = module.resource_group.name
  location                   = module.resource_group.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  tags                       = local.tags
}

module "key_vault" {
  source              = "../key_vault"
  name                = "kv-${replace(local.base, "-", "")}"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  tags                = local.tags
}

module "postgres" {
  source                 = "../postgres"
  name                   = "psql-${local.base}"
  resource_group_name    = module.resource_group.name
  location               = module.resource_group.location
  administrator_password = var.postgres_password
  zone_redundant         = var.postgres_zone_redundant
  tags                   = local.tags
}

module "redis" {
  source              = "../redis"
  name                = "redis-${local.base}"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  tags                = local.tags
}

module "ai_service" {
  source              = "../container_app"
  name                = "ca-ai-${var.env}"
  resource_group_name = module.resource_group.name
  environment_id      = azurerm_container_app_environment.this.id
  image               = var.ai_service_image
  target_port         = 8000
  tags                = local.tags
}

module "platform" {
  source              = "../container_app"
  name                = "ca-platform-${var.env}"
  resource_group_name = module.resource_group.name
  environment_id      = azurerm_container_app_environment.this.id
  image               = var.platform_image
  target_port         = 4000
  env = {
    PHX_HOST        = "${local.base}.example.com"
    REDIS_URL       = "rediss://${module.redis.hostname}:6380"
    AI_SERVICE_URL  = "https://${module.ai_service.fqdn}"
    KEY_VAULT_URI   = module.key_vault.vault_uri
    DATABASE_FQDN   = module.postgres.fqdn
    PHX_SERVER      = "true"
  }
  tags = local.tags
}

output "platform_fqdn" {
  value = module.platform.fqdn
}

output "ai_service_fqdn" {
  value = module.ai_service.fqdn
}

output "resource_group" {
  value = module.resource_group.name
}
