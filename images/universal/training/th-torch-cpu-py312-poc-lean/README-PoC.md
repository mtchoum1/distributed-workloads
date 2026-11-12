# Lean workbench PoC (`th-torch-cpu-py312-poc-lean`)

Additive PoC for dual-mode **workbench + runtime** after Notebooks retires
`jupyter-minimal-*`, **without** Elyra/Kale.

It does **not** use a published `odh-workbench-jupyter-minimal-*` image,
`jupyter/minimal` as a build context, a submodule, or a clone/copy of Notebooks
at build time.

Compare with the bootstrap PoC and see pros/cons in
[POC-README.md](../POC-README.md).

## Approach

| Before (production) | After (this PoC) |
|--------|------------------|
| `FROM jupyter-minimal-*` | `FROM odh-base-image-cpu-*` |
| Jupyter + starter inherited from Notebooks | In-repo lean `start-notebook.sh` |
| Full minimal Jupyter contract from base | `jupyterlab` / `jupyter-server` / `ipykernel` installed in builder |

Default midstream base digest matches Notebooks `build-args` for `odh-base`.
Downstream still overrides `BASE_IMAGE` / `DOWNSTREAM=true` for AIPCC.

## Owned workbench contract (lean)

- `start-notebook.sh` — honors `NOTEBOOK_PORT`, `NOTEBOOK_BASE_URL`,
  `NOTEBOOK_ROOT_DIR`, and `NOTEBOOK_ARGS`; does **not** source Elyra/Kale
- Builder install of `jupyterlab`, `jupyter-server`, `ipykernel` (kernelspec)
- Copy of `/opt/app-root/share/jupyter` into the final image

Explicitly **not** included: `odh-elyra`, `odh-kale`, PDF/pandoc bootstrap,
`utils/process.sh`, or a full Notebooks-parity Jupyter config tree.

## Build and smoke test

```bash
cd images/universal/training/th-torch-cpu-py312-poc-lean
podman build -f Dockerfile.poc -t th-torch-cpu-poc:lean .

# Workbench mode
podman run --rm -p 8888:8888 \
  -e NOTEBOOK_ARGS='--ServerApp.port=8888 --ServerApp.token= --ServerApp.password= --ServerApp.ip=0.0.0.0' \
  th-torch-cpu-poc:lean

# Runtime mode
podman run --rm th-torch-cpu-poc:lean \
  python -c 'import torch, jupyterlab; print(torch.__version__)'
```

## Before production

- Pin lean workbench packages in `pyproject.toml` and regenerate hash-locked
  `requirements.txt` (no unlocked `pip install` layer).
- Confirm OpenMPI on the chosen `odh-base` / AIPCC base.
- Add Jupyter server config if dashboard probes need Notebooks-parity paths.
- Smoke: workbench + TrainJob override + papermill (`-k python3`) + arbitrary UID.
- Prefer promoting via the bootstrap PoC path if full Notebooks-minimal parity
  and `BOOTSTRAP_LINEAGE` provenance are required for signoff.

References: [POC comparison](../POC-README.md),
[migration plan](../../../docs/migration-notebooks-minimal-retirement.md),
[ADR 0013](https://github.com/opendatahub-io/architecture-context/blob/main/overlays/0013-universal-training-image-dual-purpose.md).
