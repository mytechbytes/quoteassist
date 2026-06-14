# Shared Elixir CI runner image (used by the Jenkins pipeline for the platform).
# Match the Elixir/OTP to .tool-versions (OTP 29). Rebuild + repush when bumping
# the toolchain (REBUILD_CI_IMAGE=true).
ARG ELIXIR_IMAGE="hexpm/elixir:1.18.4-erlang-29.0.1-alpine-3.21.3"
FROM ${ELIXIR_IMAGE}

RUN apk add --no-cache git build-base curl bash
RUN mix local.hex --force && mix local.rebar --force

WORKDIR /app
