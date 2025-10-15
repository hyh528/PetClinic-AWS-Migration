#!/usr/bin/env bash
set -euo pipefail

# init-layer.sh
# Usage: init-layer.sh <layer-name> [environment]
# Example: ./init-layer.sh 02-security dev

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LAYERS_DIR="$PROJECT_ROOT/layers"

LAYER=${1:-}
ENVIRONMENT=${2:-dev}

if [[ -z "$LAYER" ]]; then
  echo "Usage: $0 <layer-name> [environment]"
  echo "Example: $0 02-security dev"
  exit 2
fi

LAYER_DIR="$LAYERS_DIR/$LAYER"

if [[ ! -d "$LAYER_DIR" ]]; then
  echo "Layer directory not found: $LAYER_DIR"
  exit 3
fi

echo "[INFO] Formatting Terraform files in $LAYER_DIR"
terraform -chdir="$LAYER_DIR" fmt -recursive || true

BACKEND_COMMON="$PROJECT_ROOT/backend.hcl"
BACKEND_CONFIG_FILE="$LAYER_DIR/backend.config"

if [[ -f "$BACKEND_CONFIG_FILE" ]]; then
  # Extract key and normalize environment prefix
  KEY_LINE=$(grep -E '^\s*key\s*=' "$BACKEND_CONFIG_FILE" || true)
  if [[ -n "$KEY_LINE" ]]; then
    RAW_KEY=$(echo "$KEY_LINE" | sed -E 's/^\s*key\s*=\s*"(.*)"\s*/\1/')
    if [[ "$RAW_KEY" == */* ]]; then
      REMAINDER=${RAW_KEY#*/}
      BACKEND_KEY_ARG="-backend-config=key=${ENVIRONMENT}/${REMAINDER}"
    else
      BACKEND_KEY_ARG="-backend-config=key=${ENVIRONMENT}/${RAW_KEY}"
    fi
  else
    BACKEND_KEY_ARG="-backend-config=$BACKEND_CONFIG_FILE"
  fi
else
  BACKEND_KEY_ARG="-backend-config=key=${ENVIRONMENT}/${LAYER}/terraform.tfstate"
fi

echo "[INFO] Initializing layer $LAYER (env: $ENVIRONMENT)"
terraform -chdir="$LAYER_DIR" init -backend-config="$BACKEND_COMMON" $BACKEND_KEY_ARG -reconfigure -upgrade

echo "[INFO] Validating Terraform configuration in $LAYER_DIR"
terraform -chdir="$LAYER_DIR" validate

echo "[SUCCESS] Layer $LAYER initialized and validated"
