#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-.env}"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: Env file not found: $ENV_FILE"
  exit 1
fi

echo "Running environment preflight check using $ENV_FILE"

required_vars=(
  "PRIVATE_KEY"
  "RPC_URL"
  "DOMAIN"
)

missing=0

while IFS='=' read -r key value; do
  if [[ " ${required_vars[*]} " =~ " ${key} " ]]; then
    required_vars=("${required_vars[@]/$key}")
  fi
done < <(grep -v '^\s*#' "$ENV_FILE" | grep '=')

for var in "${required_vars[@]}"; do
  if [ -n "$var" ]; then
    echo "Missing required env variable: $var"
    missing=1
  fi
done

if [ "$missing" -ne 0 ]; then
  echo "Preflight check failed."
  exit 1
fi

echo "Preflight check passed."
