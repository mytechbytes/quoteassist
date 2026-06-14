variable "location" {
  type    = string
  default = "westeurope"
}

variable "postgres_password" {
  type      = string
  sensitive = true
  default   = "set-me-in-tfvars-or-key-vault"
}
