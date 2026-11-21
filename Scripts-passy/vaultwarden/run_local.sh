#!/bin/bash
# Starts the throwaway Vaultwarden for the UI tests (never a real server). Binary: $VW_BIN, default /Users/enrico/Documents/GitHub/vaultwarden-build/vaultwarden
# (built by the README route: git clone tag 1.37.5, cargo build --release --features sqlite,vendored_openssl).
# usage: run_local.sh [--fresh]     --fresh wipes the data directory first
CACHE="${PASSY_CACHE:-$HOME/Library/Caches/passy-vw-scratch}"
BIN="${VW_BIN:-/Users/enrico/Documents/GitHub/vaultwarden-build/vaultwarden}"
DATA="${VW_DATA:-$CACHE/data}"
[ -x "$BIN" ] || { echo "no binary at $BIN (build it first, see README)"; exit 1; }
[ "$1" = "--fresh" ] && rm -rf "$DATA"
mkdir -p "$DATA"
PORT="${VW_PORT:-8088}"
export DATA_FOLDER="$DATA" ROCKET_PORT="$PORT" LOGIN_RATELIMIT_SECONDS=1 LOGIN_RATELIMIT_MAX_BURST=1000 \
  DOMAIN="http://localhost:$PORT" SIGNUPS_ALLOWED=true WEB_VAULT_ENABLED=false \
  EXPERIMENTAL_CLIENT_FEATURE_FLAGS=pm-32009-new-item-types
mkdir -p "$CACHE/out"
cd "$CACHE" && exec "$BIN" >> "$CACHE/out/vaultwarden.log" 2>&1
