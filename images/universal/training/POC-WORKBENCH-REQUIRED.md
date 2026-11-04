# POC: Workbench required (lean JupyterLab, no Elyra/Kale)

Branch: `poc/workbench-required`

## Goal

Keep dual-mode **workbench + runtime** after notebooks retires
`jupyter-minimal-*`, **without** inheriting Elyra/Kale from
`jupyter-universal`.

## Approach

| Before | After (this POC) |
|--------|------------------|
| `FROM jupyter-minimal-*` (Jupyter + starter from notebooks) | `FROM odh-base-image-*` |
| `start-notebook.sh` from base (may source Elyra/Kale) | In-repo lean `start-notebook.sh` |
| Jupyter stack inherited | `jupyterlab` / `jupyter-server` / `ipykernel` installed in builder |
| Dual-mode entrypoint | Unchanged behavior |

Midstream digests match notebooks `build-args/*.conf`. Downstream still
overrides `BASE_IMAGE` / `DOWNSTREAM=true` for AIPCC.

## What is explicitly excluded

- `odh-elyra`, `odh-kale`, `setup-elyra.sh`, `setup-kale.sh`
- `FROM jupyter-universal` (would pull datascience/Elyra meta packages)

## Follow-ups before productionizing

1. Move lean workbench packages into each `pyproject.toml` and regenerate
   `requirements.txt` (hashes) so Konflux hermetic builds do not use an
   unlocked `pip install` layer.
2. Confirm CPU/ROCm OpenMPI presence on `odh-base` (CUDA builds OpenMPI).
3. Add a thin Jupyter server config if dashboard workbench probes need the
   same paths as notebooks' `jupyter_server_config.py`.
4. Smoke: workbench (`NOTEBOOK_ARGS`) + TrainJob command override + papermill
   (`-k python3` / ipykernel).

## Local smoke

```bash
cd images/universal/training/th-torch-cpu-py312
podman build -t localhost/th-torch-cpu-poc:required .
# Workbench default
podman run --rm -p 8888:8888 -e NOTEBOOK_ARGS='--ServerApp.port=8888 --ServerApp.token=' localhost/th-torch-cpu-poc:required
# Runtime
podman run --rm localhost/th-torch-cpu-poc:required python -c 'import torch, jupyterlab; print(torch.__version__)'
```
