# Infrastructure (Terraform)

Azure infrastructure for QuoteAssist, authored as code.

> **Phase 0 discipline:** this Terraform is *authored and reviewed as PRs now,
> but applied only in Phase 13* — after UAT sign-off. No cloud resources are
> provisioned and no spend begins before then. CI runs `fmt` + `validate` only
> (`.github/workflows/infra-plan.yml`); there is **no `apply`** in CI.

## Layout

```
infrastructure/
├── modules/
│   ├── resource_group/     # azurerm_resource_group
│   ├── postgres/           # Flexible Server + db + pgvector/citext/pgcrypto allow-list
│   ├── redis/              # Azure Cache for Redis (TLS-only)
│   ├── key_vault/          # Key Vault (RBAC auth, purge protection)
│   ├── container_app/      # generic Container App (platform + ai-service)
│   └── stack/              # composes the above into one environment
└── envs/
    ├── dev/                # root module → module "stack" (env = dev)
    ├── staging/            # env = staging
    └── prod/               # env = prod, zone-redundant Postgres
```

Each `envs/<env>` is a thin root module that calls `modules/stack` with
environment-specific sizing. Provider target: **azurerm `~> 4.0`**, Terraform
`>= 1.6`.

## Local usage

```sh
cd infrastructure/envs/dev
terraform fmt -recursive          # format before committing (CI checks this)
terraform init -backend=false     # no remote state needed to validate
terraform validate
```

Remote state (`backend "azurerm"`) and real credentials are wired at apply time
in Phase 13; the backend block is commented in each env's `terraform.tf`.

> The skeleton was authored without a local Terraform toolchain. Run
> `terraform fmt -recursive` and `terraform validate` once before the first infra
> PR to settle any provider-schema or formatting nits, and pin exact provider
> versions in a committed `.terraform.lock.hcl`.

## Mapping to §8.4 (Solution Architecture)

| Module          | Azure service                       | Purpose                          |
| --------------- | ----------------------------------- | -------------------------------- |
| `postgres`      | PostgreSQL Flexible Server          | Primary DB + pgvector + Oban     |
| `redis`         | Azure Cache for Redis               | Extraction/pricing cache         |
| `key_vault`     | Key Vault                           | Secrets via Managed Identity     |
| `container_app` | Container Apps                      | platform + ai-service runtimes   |
| `stack`         | + Log Analytics, Container App Env  | one composed environment         |
