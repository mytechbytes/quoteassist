variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "administrator_login" {
  type    = string
  default = "qa_admin"
}

variable "administrator_password" {
  type      = string
  sensitive = true
}

variable "sku_name" {
  type    = string
  default = "B_Standard_B1ms"
}

variable "storage_mb" {
  type    = number
  default = 32768
}

variable "zone_redundant" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}

# Primary Postgres Flexible Server. pgvector + citext + pgcrypto are allow-listed
# via the azure.extensions server parameter (enabled per-database by migrations).
resource "azurerm_postgresql_flexible_server" "this" {
  name                          = var.name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = "16"
  administrator_login           = var.administrator_login
  administrator_password        = var.administrator_password
  sku_name                      = var.sku_name
  storage_mb                    = var.storage_mb
  public_network_access_enabled = false
  high_availability {
    mode = var.zone_redundant ? "ZoneRedundant" : "SameZone"
  }
  tags = var.tags
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = "quote_assist"
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = "VECTOR,CITEXT,PGCRYPTO"
}

output "server_id" {
  value = azurerm_postgresql_flexible_server.this.id
}

output "fqdn" {
  value = azurerm_postgresql_flexible_server.this.fqdn
}
