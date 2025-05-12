#!/usr/bin/env bash
set -euo pipefail

# Usage: ./create_env.sh [YAML_FILENAME]
# Defaults to 'environment.yaml' if no argument is given.
YAML_FILE="${1:-environment.yaml}"
ENV_YAML="../envs/${YAML_FILE}"

if [[ ! -f "$ENV_YAML" ]]; then
  echo "Error: '$ENV_YAML' not found."
  exit 1
fi

# Extract the environment name from the YAML (expects a top-level 'name:' field)
ENV_NAME=$(grep -E '^name:' "$ENV_YAML" | awk '{print $2}')
if [[ -z "$ENV_NAME" ]]; then
  echo "Error: Could not determine 'name:' from $ENV_YAML."
  exit 1
fi

echo "Creating Conda environment '$ENV_NAME' from '$ENV_YAML'…"
conda env create -f "$ENV_YAML"

echo "Done! Environment '$ENV_NAME' has been created."
echo "You can activate it with: conda activate $ENV_NAME"
