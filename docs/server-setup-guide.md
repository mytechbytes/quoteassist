# QuoteAssist CI/CD on Oracle Cloud Infrastructure — Complete Setup Guide

**Stack:** Elixir 1.18+ · OTP 29 · Phoenix 1.8 (platform) · Python 3.14 / FastAPI
(ai-service) · PostgreSQL 18 **+ pgvector** · Redis 8 · Docker · Jenkins · Caddy ·
Oracle Cloud Infrastructure (OCI). Latest-stable images throughout.

**Architecture:**
- **Jenkins Server** — Oracle Linux 9, ARM64 — builds, tests, pushes images.
- **Production Server** — Ubuntu 24.04, ARM64 — runs the stack via Docker Compose.
- **Registry** — OCI Container Registry (OCIR), Mumbai region.
- **Branches** — `develop` → staging (auto deploy), `main` → production (manual
  approval).

**What deploys:** two app images from this monorepo —
- `quoteassist` (Elixir/Phoenix — web UI + API; **public**, behind Caddy)
- `quoteassist-ai` (Python/FastAPI — extraction; **internal only**, no public route)

plus `postgres` (pgvector) and `redis`. The platform reaches the AI service over the
internal Docker network at `http://ai-service:8000`.

> Adapted from the proven MangoCMS Phoenix-on-OCI setup. The OCI-specific gotchas
> (federated-user 403, `credsStore` breakage, domain-qualified IAM policy, trixie
> runtime, `eval` vs `rpc`, approved-sender propagation, port 587/STARTTLS) carry
> over unchanged — they are environment truths, not app-specific.

---

## Part 1 — Prerequisites

### OCI Resources
- Two ARM64 Ampere A1 compute instances (free-tier eligible).
- An OCIR namespace (noted `<OCI_NAMESPACE>`).
- VCN Security List ingress open for 22, 80, 443.

### DNS
Point an A record per public app domain to the production server IP **before**
starting Caddy (Let's Encrypt validates over HTTP on port 80). The AI service is
internal — it needs **no** DNS.

```
quoteassist.mytechbytes.in      → 161.118.161.178
stg.quoteassist.mytechbytes.in  → 161.118.161.178
```

---

## Part 2 — OCI Setup

### 2.1 Create a Dedicated CI/CD Service Account

> **Critical:** Do NOT use a personal federated (Gmail/IDCS) account for CI/CD. In
> tenancies with Identity Domains, federated users fail OCIR push with 403 despite
> correct policies — login succeeds but the authorization check silently fails.
> Always create a dedicated **local** IAM user.

OCI Console → Identity & Security → Identity → Domains → Default → Users →
**Create User**
- First/Last: `jenkins` / `ci`; Username: `jenkins-ci`
- **Uncheck** "Use Oracle Identity Cloud Service to manage this user" (makes it local)

Add to **Administrators** group, then **Generate Auth Token** (Users → `jenkins-ci`
→ Auth Tokens). Copy it immediately — shown once.

### 2.2 IAM Policy for OCIR

> **Critical:** policies must use the domain-qualified group format
> `'DomainName'/'GroupName'`; plain `Allow group Administrators` does not cover
> Identity Domain users and yields 403 on push.

Identity & Security → Policies → **Create Policy** (compartment: **root**):
```
Allow group 'Default'/'Administrators' to manage repos in tenancy
Allow group 'Default'/'Administrators' to manage all-resources in tenancy
```

### 2.3 Create OCIR Repositories

OCIR does not auto-create repos on first push. Create each (Developer Services →
Container Registry → Create Repository), all in the **same compartment**:

| Repository                 | Access  | Purpose                          |
|----------------------------|---------|----------------------------------|
| `quoteassist`              | Private | Elixir/Phoenix app image         |
| `quoteassist-ai`           | Private | Python/FastAPI AI service image  |
| `mytechbytes-elixir-ci`    | Private | Shared Elixir CI runner image    |

> `mytechbytes-elixir-ci` is **shared across all your Elixir apps** (MangoCMS,
> QuoteAssist, MangoGST…). It has **one owner** — a single repo (or the MangoCMS
> repo) holds the Dockerfile and builds/pushes the image. Every other app pipeline
> only **pulls** the tag `mytechbytes-elixir-ci:1.20.1-otp-29` — they do not carry a copy
> of the CI Dockerfile (that's how you avoid drift: change the toolchain once in
> the owner, rebuild, and all apps pick it up on their next run).

---

## Part 3 — Jenkins Server Setup (Oracle Linux, ARM64)

SSH as `opc`. (Steps identical to any Phoenix-on-OCI box.)

### 3.1–3.5 Base
```bash
sudo dnf update -y
sudo dnf install -y java-17-openjdk git
# Jenkins
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
sudo dnf install -y jenkins && sudo systemctl enable --now jenkins
sudo cat /var/lib/jenkins/initialAdminPassword
# Docker
sudo dnf install -y dnf-utils
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker jenkins && sudo systemctl restart jenkins
```

### 3.6 Buildx for ARM64
```bash
docker run --privileged --rm tonistiigi/binfmt --install all
docker buildx ls
```

### 3.7 Configure Docker for OCIR

> **Do not install docker-credential-pass / any GPG credential helper.** It causes
> silent decryption failures in Jenkins pipeline shells — `docker login` works but
> `docker push` fails with 403. Plain Docker config is correct for CI.

```bash
sudo -u jenkins mkdir -p /var/lib/jenkins/.docker
sudo -u jenkins bash -c 'echo "{}" > /var/lib/jenkins/.docker/config.json'
sudo -u jenkins docker login ap-mumbai-1.ocir.io -u <OCI_NAMESPACE>/jenkins-ci   # paste auth token
sudo cat /var/lib/jenkins/.docker/config.json   # must show "auth", no "credsStore"
```
If `"credsStore": "pass"` appears:
```bash
sudo rm -f /usr/bin/docker-credential-pass /usr/local/bin/docker-credential-pass
sudo -u jenkins bash -c 'echo "{}" > /var/lib/jenkins/.docker/config.json'   # then re-login
```

### 3.8 Jenkins Credentials

| ID                       | Type                          | Value |
|--------------------------|-------------------------------|-------|
| `github-ssh-key`         | SSH Username + private key     | GitHub deploy key |
| `ocir-credentials`       | Username + password            | `<OCI_NAMESPACE>/jenkins-ci` + auth token |
| `production-server-ssh`  | SSH Username + private key     | prod server `ubuntu` key |

### 3.9 Plugins
Pipeline: Multibranch · Git · GitHub · Email Extension · Timestamper · SSH Agent.

### 3.10 Create Multibranch Pipeline Job
New Item → `quote-assist` → **Multibranch Pipeline**:
1. Branch Sources → Git → repo URL `git@github.com:<org>/quote-assist.git`, creds
   `github-ssh-key`.
2. Discover branches: All branches. Build by `Jenkinsfile` (at repo root).
3. Scan triggers: periodic 1 min, **or** add a GitHub push webhook to
   `http://<JENKINS_IP>:8080/github-webhook/`.

---

## Part 4 — Production Server Setup (Ubuntu, ARM64)

SSH as `ubuntu`.

### 4.1–4.3 Base + Docker + OCIR login
```bash
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable --now docker && sudo usermod -aG docker ubuntu && newgrp docker

mkdir -p ~/.docker && echo "{}" > ~/.docker/config.json
docker login ap-mumbai-1.ocir.io -u <OCI_NAMESPACE>/jenkins-ci   # paste auth token; same credsStore rule applies
```

### 4.4 Application Directories
```bash
mkdir -p /home/ubuntu/apps/data/{postgres,redis}
mkdir -p /home/ubuntu/apps-stg/data/{postgres,redis}
```

### 4.5 Production `.env`
```bash
cat > /home/ubuntu/apps/.env << 'EOF'
OCI_NAMESPACE=<your-oci-namespace>

# --- Datastores ---
POSTGRES_USER=postgres
POSTGRES_PASSWORD=<strong-password>
POSTGRES_DB=quote_assist_prod
REDIS_PASSWORD=<strong-password>

# --- Image tags (set by the pipeline; defaults below) ---
PLATFORM_IMAGE_TAG=prd-latest
AI_IMAGE_TAG=prd-latest

# --- Platform (Elixir) ---
SECRET_KEY_BASE=<64-char-random: openssl rand -hex 64>
# API JWT — set JWKS (RS256/Entra) OR a shared HS256 secret
JWT_JWKS_URL=
JWT_ISSUER=
JWT_AUDIENCE=
JWT_SECRET=<random or blank if using JWKS>

# --- AI service (Python) ---
AI_DEFAULT_MODEL=claude-haiku
ANTHROPIC_API_KEY=
AZURE_OPENAI_ENDPOINT=
AZURE_OPENAI_API_KEY=
EOF
chmod 600 /home/ubuntu/apps/.env
```

### 4.6 Staging `.env`
Same as 4.5 with `POSTGRES_DB=quote_assist_stg`, `PLATFORM_IMAGE_TAG=stg-latest`,
`AI_IMAGE_TAG=stg-latest`, and its own secrets.

### 4.7 Production `docker-compose.yml`
```bash
cat > /home/ubuntu/apps/docker-compose.yml << 'EOF'
networks:
  frontend-net: { driver: bridge }
  backend-net:  { driver: bridge }

volumes:
  postgres-data:
    driver: local
    driver_opts: { type: none, o: bind, device: /home/ubuntu/apps/data/postgres }
  redis-data:
    driver: local
    driver_opts: { type: none, o: bind, device: /home/ubuntu/apps/data/redis }
  caddy_data:
  caddy_config:

services:
  caddy:
    image: caddy:2-alpine
    container_name: caddy
    restart: unless-stopped
    ports: ["80:80", "443:443", "443:443/udp"]
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    networks: [frontend-net]
    depends_on: [platform]

  postgres:
    image: pgvector/pgvector:pg18        # pgvector + citext + pgcrypto available
    container_name: postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      PGDATA: /var/lib/postgresql/data   # postgres:18 needs this when mounting .../data
    volumes: [postgres-data:/var/lib/postgresql/data]
    networks: [backend-net]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD} --appendonly yes
    volumes: [redis-data:/data]
    networks: [backend-net]
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  ai-service:                            # internal only — no Caddy route
    image: ap-mumbai-1.ocir.io/${OCI_NAMESPACE}/quote-assist-ai:${AI_IMAGE_TAG}
    container_name: ai-service
    restart: unless-stopped
    environment:
      AI_DEFAULT_MODEL: ${AI_DEFAULT_MODEL}
      ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY}
      AZURE_OPENAI_ENDPOINT: ${AZURE_OPENAI_ENDPOINT}
      AZURE_OPENAI_API_KEY: ${AZURE_OPENAI_API_KEY}
    networks: [backend-net]
    depends_on:
      postgres: { condition: service_healthy }

  platform:
    image: ap-mumbai-1.ocir.io/${OCI_NAMESPACE}/quote-assist-platform:${PLATFORM_IMAGE_TAG}
    container_name: platform
    restart: unless-stopped
    environment:
      DATABASE_URL: ecto://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres/${POSTGRES_DB}
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
      PHX_HOST: quoteassist.mytechbytes.in
      PHX_SERVER: "true"
      PORT: 4000
      POOL_SIZE: 10
      REDIS_URL: redis://:${REDIS_PASSWORD}@redis:6379/0
      AI_SERVICE_URL: http://ai-service:8000
      JWT_JWKS_URL: ${JWT_JWKS_URL}
      JWT_ISSUER: ${JWT_ISSUER}
      JWT_AUDIENCE: ${JWT_AUDIENCE}
      JWT_SECRET: ${JWT_SECRET}
    networks: [frontend-net, backend-net]
    depends_on:
      postgres: { condition: service_healthy }
      redis:    { condition: service_healthy }
      ai-service: { condition: service_started }
EOF
```

### 4.8 Staging `docker-compose.yml`
Same shape under `/home/ubuntu/apps-stg/` with container names suffixed `-stg`
(`platform-stg`, `ai-service-stg`, `postgres-stg`, `redis-stg`), `POOL_SIZE: 5`,
`PHX_HOST: stg.quoteassist.mytechbytes.in`, bind-mounts under `apps-stg/data`, and
the Caddy `reverse_proxy` pointing at `platform-stg:4000`.

### 4.9 Caddyfile (platform only — AI service stays internal)
```bash
cat > /home/ubuntu/apps/Caddyfile << 'EOF'
quoteassist.mytechbytes.in {
    reverse_proxy platform:4000
}
stg.quoteassist.mytechbytes.in {
    reverse_proxy platform-stg:4000
}
EOF
```

> **Critical:** Caddy must share `frontend-net` with the `platform` container, or
> all requests 502.

### 4.10 Start Services + Create Databases
```bash
cd /home/ubuntu/apps
docker compose up -d postgres
sleep 5
docker compose exec postgres createdb -U postgres quote_assist_prod
docker compose up -d
docker compose logs -f caddy            # watch TLS issuance
```
The required extensions (`vector`, `citext`, `pgcrypto`) are created by the first
**migration** — no manual `CREATE EXTENSION` needed (run migrations in Part 6.5).

### 4.11 Verify
```bash
curl -s https://quoteassist.mytechbytes.in/health
# → {"status":"ok","service":"platform","version":"0.1.0"}

curl -s https://quoteassist.mytechbytes.in/health/ready
# → {"status":"ready","checks":{"database":"ok"}}
```

---

## Part 5 — Application Repository Setup

Files live in the monorepo. The platform release files are under `projects/platform/`.

### 5.1 Key files (already in this repo)

- **`projects/platform/Dockerfile`** — multi-stage Elixir release (builder →
  assets → release → runtime), built from the official `elixir:1.20.1-otp-29`
  (Debian **trixie**) with a matching `debian:trixie-slim` runtime (`glibc`/OpenSSL
  must match); `libsctp1` silences the Erlang SCTP boot warning; runs as non-root
  `appuser` (UID/GID 1000).
- **Shared CI runner** (`mytechbytes-elixir-ci`) — **not** in this repo. It's owned
  by a single repo and this pipeline only pulls it (see §2.3). Base:
  `elixir:1.20.1-otp-29-alpine`.
- **`projects/ai-service/Dockerfile`** — Python 3.14 / FastAPI (uvicorn on 8000).
- **`projects/platform/.tool-versions`** — must match the build images' OTP.
  Dialyzer embeds the OTP version in the PLT filename — a mismatch forces a rebuild.
- **`projects/platform/coveralls.json`** — coverage config (skips release/app/core
  components/health).
- **`projects/platform/.dialyzer_ignore.exs`** — keep `[]`; stale entries cause
  "Unnecessary Skips" after upgrades.
- **`projects/platform/lib/quote_assist/release.ex`** — `QuoteAssist.Release.migrate/0`
  + `rollback/2` + `seed/0` for production migrations without Mix.

> **Why trixie-slim runtime?** The OTP-29 Elixir images are built on Debian trixie.
> `bookworm-slim` fails with `glibc version not found`; `ubuntu:24.04` fails with an
> OpenSSL mismatch in the crypto NIF. Match the builder's OS exactly.

---

## Part 6 — Jenkins Pipeline (`Jenkinsfile` at repo root)

### 6.1 Branch behaviour

| Branch    | CI        | Deploy                 | Image tags          |
|-----------|-----------|------------------------|---------------------|
| `develop` | auto      | auto (staging)         | `stg-N` / `stg-latest` |
| `main`    | auto      | **manual approval**    | `prd-N` / `prd-latest` |
| other     | CI only   | skipped                | `pr-N`              |

### 6.2 Stages
Modelled on the MangoCMS pipeline. CI runs every mix task inside the shared
runner via a reusable `DOCKER_RUN` (named volumes cache `deps`/`_build`/hex/mix +
the Dialyzer PLT; the workspace is bind-mounted so `cover/` lands back for
archiving), against a throwaway **pgvector pg18** container on an isolated network.

1. **Configure** — branch vars (target, host, compose dir, tags, container/service
   name, env-var name, app URL) + a run banner.
2. **CI Image** — **pulls** the shared `mytechbytes-elixir-ci:1.20.1-otp-29` runner
   (login first — OCIR is private). Never built here.
3. **Checkout** — capture `GIT_COMMIT_SHORT` / branch for image labels.
4. **CI Infrastructure** — create the CI network + `quoteassist-postgres-ci`
   (pgvector pg18) and wait for readiness.
5. **Setup** — `mix deps.get · ecto.create · ecto.migrate`.
6. **Compile** — `mix compile --warnings-as-errors`.
7. **Quality Checks** (parallel) — `mix credo --strict` ‖ `mix dialyzer`.
8. **Tests & Coverage** — `mix coveralls.json` then
   `mix run --no-start ci/check_coverage.exs $COVERAGE_THRESHOLD`; archives
   `cover/*.json`.
9. **Build & Push** — `docker buildx --platform linux/arm64` with OCI/build labels:
   the `quoteassist` image from `projects/platform`, tagged `<prefix>-N` +
   `<prefix>-latest` (the `quoteassist-ai` image ships in its own release).
10. **Approval** — **main** only, 24h timeout.
11. **Deploy** — SSH (key + on-server `docker login`): pin `QUOTEASSIST_IMAGE_TAG`
    in `.env`, `compose pull` + `up -d --no-deps`, migrate, verify — scoped to
    **only** the quoteassist service so MangoCMS / others are never restarted.
12. **Rollback** (action = `ROLLBACK`) — validate the tag exists in OCIR, pin it,
    `pull` + `up -d --no-deps`, verify. No automatic migrations.
13. **Smoke Test** — `GET /health/ready`, 5 tries.

`post`: success/failure email (`emailext` → `NOTIFY_EMAIL`); `always` tears down
the CI postgres/network + root-owned `cover/` and logs out of OCIR (the cached
named volumes are kept for the next build).

The shared CI runner is **not built here** — one owner repo (MangoCMS) builds/pushes
`mytechbytes-elixir-ci:1.20.1-otp-29`; this pipeline only pulls it.

### 6.3 Parameters
`PIPELINE_ACTION` (`BUILD_AND_DEPLOY` | `ROLLBACK`) · `ROLLBACK_TAG`
(`prd-13`/`stg-13`) · `COVERAGE_THRESHOLD` (default `70` — raise toward 80+ as the
app matures).

Before first run, set `<OCI_NAMESPACE>`, `161.118.161.178` and the hostnames in the
`Jenkinsfile` (Configure stage + `environment` block).

### 6.4 Run migrations manually
```bash
# Production (run from /home/ubuntu/apps)
docker compose exec -T quoteassist     /app/bin/quote_assist eval "QuoteAssist.Release.migrate()"
# Staging (run from /home/ubuntu/apps-stg)
docker compose exec -T quoteassist-stg /app/bin/quote_assist eval "QuoteAssist.Release.migrate()"
# Seed reference data (idempotent) — usually production only, once
docker compose exec -T quoteassist     /app/bin/quote_assist eval "QuoteAssist.Release.seed()"
```

---

## Part 7 — OCI Email Delivery Setup

> QuoteAssist sends mail through **Swoosh** (`QuoteAssist.Mailer`). The SMTP config
> is already wired in `config/runtime.exs` and activates whenever `SMTP_SERVER` is
> set; `:ssl`/`:crypto` are in `extra_applications` and `gen_smtp` is a dependency.

### 7.1 Email domain + DNS
OCI → Email Delivery → Email Domains → Create `mytechbytes.in`. Add the **SPF** TXT
and **DKIM** CNAME records OCI shows you; it verifies to **Active** in 5–30 min.

### 7.2 Approved sender
OCI → Email Delivery → Approved Senders → Create `no-reply@quoteassist.mytechbytes.in`.

> **Critical:** the application FROM address must exactly match an approved sender.
> Wait 10–15 min for propagation before testing (535 errors in that window are
> normal).

### 7.3 SMTP credentials
OCI → Domains → Default → Users → `jenkins-ci` → SMTP Credentials → Generate. Copy
username + password (shown once).

### 7.4 Connection (Mumbai)
```
Server : smtp.email.ap-mumbai-1.oci.oraclecloud.com
Port   : 587   (STARTTLS — use tls: :if_available, NOT :always / port 465)
Auth   : Always
```

### 7.5 Add SMTP vars to `.env` and `docker-compose.yml`
```bash
cat >> /home/ubuntu/apps/.env << 'EOF'

SMTP_SERVER=smtp.email.ap-mumbai-1.oci.oraclecloud.com
SMTP_PORT=587
SMTP_USERNAME=<smtp-username>
SMTP_PASSWORD=<smtp-password>
SMTP_FROM=no-reply@quoteassist.mytechbytes.in
EOF
```
Add them to the `platform` service `environment:` block (Compose only injects vars
listed there):
```yaml
  platform:
    environment:
      SMTP_SERVER: ${SMTP_SERVER}
      SMTP_PORT: ${SMTP_PORT}
      SMTP_USERNAME: ${SMTP_USERNAME}
      SMTP_PASSWORD: ${SMTP_PASSWORD}
      SMTP_FROM: ${SMTP_FROM}
```
```bash
docker compose up -d --no-deps platform
docker compose config | grep SMTP   # verify they reached the service
```

### 7.6 App wiring (already done in this repo)
- `mix.exs` → `extra_applications: [:logger, :runtime_tools, :ssl, :crypto]` +
  `{:gen_smtp, "~> 1.2"}`.
- `config/runtime.exs` → `QuoteAssist.Mailer` SMTP adapter, `tls: :if_available`,
  `auth: :always`; `:mail_from` from `SMTP_FROM`.
- **When the email-token auth flow lands (Phase 2 completion):** the notifier must
  use `Application.get_env(:quote_assist, :mail_from)` (an approved sender), **not**
  the Phoenix default `contact@example.com`, and LiveViews must handle
  `{:error, _}` from `deliver/*` with a `case` (a hard `{:ok, _} =` match crashes
  the LiveView on SMTP failure).

### 7.7 Test SMTP from the running container
```bash
docker exec platform /app/bin/quote_assist rpc '
  res = QuoteAssist.Mailer.deliver(%Swoosh.Email{
    from: {"QuoteAssist", System.get_env("SMTP_FROM")},
    to: [{"Test", "you@email.com"}],
    subject: "SMTP Test", text_body: "OCI SMTP is working."
  })
  IO.inspect(res, label: "SMTP Result")
'
# Expected: SMTP Result: {:ok, "Ok\r\n"}
```

### 7.8 Common SMTP errors
| Error | Cause | Fix |
|---|---|---|
| `SSL not started` | `:ssl` missing from `extra_applications` | already added — rebuild the release |
| `535 ... Envelope From not authorized` | FROM ≠ approved sender (or not propagated) | add sender in OCI, wait 15 min |
| `tls_failed` | `tls: :always` vs STARTTLS on 587 | use `tls: :if_available` (already set) |
| vars not in container | not listed in `environment:` | add `SMTP_*: ${SMTP_*}`, restart |

---

## Part 8 — Adding another app / environment

1. **OCIR** — create the repo (same compartment).
2. **OCI Email** — approved sender (if new domain).
3. **DNS** — A record → production IP (skip for internal-only services like the AI
   service).
4. **Prod server** — add the service to `docker-compose.yml`, env to `.env`, create
   its DB if it needs one: `docker compose exec postgres createdb -U postgres <db>`.
5. **Caddyfile** — add a block + `docker compose exec caddy caddy reload --config
   /etc/caddy/Caddyfile` (zero downtime). Internal services get no block.
6. **Jenkins** — point the Configure stage + image envs at the new app/branch.

---

## Part 9 — Useful commands
```bash
docker logs -f platform                 # or: ai-service, postgres, redis
docker compose ps -a
docker compose restart platform
docker exec platform /app/bin/quote_assist eval "QuoteAssist.Release.migrate()"
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

---

## Part 10 — Production Monitoring

| Check | Command | Expected |
|---|---|---|
| Uptime | `docker ps` | `platform`/`ai-service` up in days |
| Liveness | `curl -s https://quoteassist.mytechbytes.in/health` | `{"status":"ok",...}` |
| Readiness | `curl -s https://quoteassist.mytechbytes.in/health/ready` | `{"status":"ready",...}` |
| Logs | `docker logs --tail 50 platform` | no `[error]` |
| Disk | `df -h` | `<80%` on `/` |
| SMTP | RPC test (7.7) | `{:ok, "Ok\r\n"}` |

**Monthly:** SMTP test · OCIR prune (keep last ~10 `prd-N` per image) ·
`docker image prune -f`.
**Annual:** rotate the `jenkins-ci` auth token (1-year expiry; update
`ocir-credentials`) and DKIM keys (update DNS CNAME).

### Key gotchas to never forget
1. **docker-credential-pass** breaks `docker push` (403) silently — remove it on any
   new Jenkins/prod box.
2. **pgvector image** — use `pgvector/pgvector:pg18`, not plain `postgres`, or the
   `vector(1536)` migration fails (`type "vector" does not exist`).
3. **`eval` vs `rpc`** — `eval` starts a minimal VM (kernel/stdlib only); use `rpc`
   to run in the live node when you need config/env/SSL (e.g. SMTP test).
4. **OCIR repos must pre-exist** — first push fails otherwise.
5. **Approved sender propagation** — wait 10–15 min after creating it.
6. **Two images, one repo** — bumping `PLATFORM_IMAGE_TAG` alone won't update the AI
   service; the pipeline tags both with the same build tag.

---

## Common Issues & Fixes

| Issue | Cause | Fix |
|---|---|---|
| `403` on push, login OK | federated user, or `credsStore: pass` | use local `jenkins-ci`; remove docker-credential-pass; reset config to `{}` |
| `Allow group Administrators` no effect | Identity Domains needs qualified name | use `'Default'/'Administrators'` |
| `403` push — repo missing | OCIR no auto-create | create repo in console first |
| `type "vector" does not exist` | plain `postgres` image | switch to `pgvector/pgvector:pg18` |
| postgres:18 exits with "unused mount/volume" | pg18 changed the default data dir | set `PGDATA: /var/lib/postgresql/data` (or mount the volume at `/var/lib/postgresql`) |
| `glibc version not found` at start | runtime OS ≠ builder | use `debian:trixie-slim` runtime |
| `ESOCK WARNING: libsctp.so.1` | missing SCTP lib | add `libsctp1` to runtime (done) |
| `groupadd: GID 1000 already exists` | base image default user | `userdel` UID 1000 before `groupadd` (done) |
| 502 from Caddy | Caddy not on `frontend-net` | add the network to the Caddy service |
| Smoke test HTTP 000 | container/Caddy not up | check `docker compose ps`, Caddy logs |
| `SSL not started` on SMTP | `:ssl` missing | already in `extra_applications`; rebuild |
| `tls_failed` | `tls: :always` on port 587 | `tls: :if_available` (already set) |
| platform can't reach AI service | not on `backend-net` / wrong URL | both on `backend-net`; `AI_SERVICE_URL=http://ai-service:8000` |
| `Exec format error` | wrong arch | build `linux/arm64` (run `uname -m` = `aarch64`) |
| `BRANCH_NAME` empty | not a Multibranch job | convert to Multibranch Pipeline |
