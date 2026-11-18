#!/bin/bash
# Starts the throwaway Vaultwarden for the UI tests (never a real server). Binary: ~/Library/Caches/passy-vw/src
# (built by the README route: git clone tag 1.37.5, cargo build --release --features sqlite,vendored_openssl).
# usage: run_local.sh [--fresh]     --fresh wipes the data directory first
CACHE="${PASSY_CACHE:-$HOME/Library/Caches/passy-vw}"
BIN="$CACHE/src/target/release/vaultwarden"
DATA="$CACHE/data"
[ -x "$BIN" ] || { echo "no binary at $BIN (build it first, see README)"; exit 1; }
[ "$1" = "--fresh" ] && rm -rf "$DATA"
mkdir -p "$DATA"
export DATA_FOLDER="$DATA" ROCKET_PORT=8088 LOGIN_RATELIMIT_SECONDS=1 LOGIN_RATELIMIT_MAX_BURST=1000 \
  DOMAIN=http://localhost:8088 SIGNUPS_ALLOWED=true WEB_VAULT_ENABLED=false \
  EXPERIMENTAL_CLIENT_FEATURE_FLAGS=pm-32009-new-item-types
cd "$CACHE" && exec "$BIN" >> "$CACHE/out/vaultwarden.log" 2>&1
