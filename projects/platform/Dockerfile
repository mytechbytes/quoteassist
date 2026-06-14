# Multi-stage production build for the QuoteAssist platform (Elixir/Phoenix release).
#
# Pin the build image to match .tool-versions (OTP 29, Elixir 1.18+ line). hexpm
# images let you pin the exact Erlang/OTP patch. RUNTIME_IMAGE must be the SAME
# Debian release as the builder (trixie), or the release fails at start with
# "glibc version not found".
ARG ELIXIR_IMAGE="hexpm/elixir:1.18.4-erlang-29.0.1-debian-trixie-20250630-slim"
ARG RUNTIME_IMAGE="debian:trixie-slim"

# ── Builder ───────────────────────────────────────────────────────────────
FROM ${ELIXIR_IMAGE} AS builder

# build-essential: NIFs. git: github deps (heroicons).
RUN apt-get update -y \
  && apt-get install -y build-essential git curl \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV="prod"

# Deps first for layer caching.
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

# Build + digest assets (tailwind/esbuild standalone binaries, no Node needed).
RUN mix assets.setup
RUN mix assets.deploy
RUN mix compile

COPY config/runtime.exs config/
RUN mix release

# ── Runtime ───────────────────────────────────────────────────────────────
FROM ${RUNTIME_IMAGE} AS runtime

# libsctp1 silences the Erlang ESOCK/SCTP warning on boot.
RUN apt-get update -y \
  && apt-get install -y libstdc++6 openssl libncurses6 locales ca-certificates libsctp1 \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

WORKDIR /app

# Non-root user at UID/GID 1000 (drop the base image's default 1000 if present).
RUN userdel -r "$(getent passwd 1000 | cut -d: -f1)" 2>/dev/null || true \
  && groupadd -g 1000 appgroup \
  && useradd -u 1000 -g appgroup -m -s /bin/bash appuser

ENV MIX_ENV="prod"
COPY --from=builder --chown=appuser:appgroup /app/_build/${MIX_ENV}/rel/quote_assist ./

USER appuser
EXPOSE 4000

# PHX_SERVER=true makes the release boot the endpoint (see config/runtime.exs).
ENV PHX_SERVER="true"
CMD ["/app/bin/quote_assist", "start"]
