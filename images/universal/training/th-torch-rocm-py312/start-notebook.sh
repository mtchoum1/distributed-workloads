#!/usr/bin/env bash
# Lean workbench starter for training-hub images (POC: workbench required).
# Intentionally omits Elyra / Kale setup sourced by notebooks' jupyter-minimal.
set -euo pipefail

NOTEBOOK_PROGRAM_ARGS=()

if [ -n "${NOTEBOOK_PORT:-}" ]; then
  NOTEBOOK_PROGRAM_ARGS+=("--ServerApp.port=${NOTEBOOK_PORT}")
fi

if [ -n "${NOTEBOOK_BASE_URL:-}" ]; then
  NOTEBOOK_PROGRAM_ARGS+=("--ServerApp.base_url=${NOTEBOOK_BASE_URL}")
fi

if [ -n "${NOTEBOOK_ROOT_DIR:-}" ]; then
  NOTEBOOK_PROGRAM_ARGS+=("--ServerApp.root_dir=${NOTEBOOK_ROOT_DIR}")
else
  NOTEBOOK_PROGRAM_ARGS+=("--ServerApp.root_dir=${HOME}")
fi

# Word-splitting is intentional: NOTEBOOK_ARGS is newline- or space-separated
# platform input from the OpenShift workbench controller.
if [ -n "${NOTEBOOK_ARGS:-}" ]; then
  while IFS= read -r line || [ -n "${line}" ]; do
    if [ -n "${line}" ]; then
      read -ra _line_args <<< "${line}"
      NOTEBOOK_PROGRAM_ARGS+=("${_line_args[@]}")
    fi
  done <<< "${NOTEBOOK_ARGS}"
fi

exec jupyter lab "${NOTEBOOK_PROGRAM_ARGS[@]}" \
  --ServerApp.ip="" \
  --ServerApp.allow_origin="*" \
  --ServerApp.open_browser=False
