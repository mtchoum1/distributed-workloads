# Self-contained CPU training-universal bootstrap PoC

Additive PoC (atheo / migration-plan style) under `th-torch-cpu-py312-poc/`.
Compare with the lean PoC and see pros/cons in
[POC-README.md](../POC-README.md).

This PoC proves that the CPU Training Hub universal image can own its
Jupyter workbench layer. It does **not** use a published
`odh-workbench-jupyter-minimal-*` image, `jupyter/minimal` as a build context,
a submodule, or a clone/copy of notebooks at build time.

The default `BASE_IMAGE` is the RHOAI 3.7 candidate AIPCC CPU base:
`quay.io/aipcc/base-images/cpu-torch2.13-el9.8`. Its tag and digest are a
reviewable placeholder for the 3.7 GA resolved base; pass `--build-arg
BASE_IMAGE=<approved-digest>` when the final base is released.

## Vendored contract

`jupyter-bootstrap/` is the DevX-owned boundary. It includes:

- `start-notebook.sh` and its required `utils/process.sh`;
- `utils/jupyter_server_config.py` and optional `utils/install_pdf_deps.sh`;
- a small, real CPU Jupyter requirements input plus provenance `pyproject.toml`;
- a clearly non-production `pylock.cpu.toml` placeholder.

Its source lineage is recorded in the image as
`BOOTSTRAP_LINEAGE=notebooks@3.7-GA-TAG-TODO`. Replace that value and replace
the small requirements file/placeholder lock with the full locked export from
the one-time 3.7 GA maintenance-tag handoff before production promotion.

## Build and smoke test

The PoC uses an online index only for a local developer build. It is expected
to need registry and AIPCC-index access.

```bash
cd images/universal/training/th-torch-cpu-py312-poc
podman build -f Dockerfile.poc -t th-torch-cpu-poc .

# Workbench mode: NOTEBOOK_ARGS selects start-notebook.sh.
podman run --rm -p 8888:8888 \
  -e NOTEBOOK_ARGS='--ServerApp.token= --ServerApp.password= --ServerApp.ip=0.0.0.0' \
  th-torch-cpu-poc

# Runtime mode: a command bypasses workbench startup.
podman run --rm --entrypoint python th-torch-cpu-poc \
  -c 'import torch; import training_hub; print(torch.__version__)'
```

Open `http://localhost:8888` after the workbench command reports that Jupyter
is listening. In an OpenShift smoke test, use the platform-injected
`NOTEBOOK_ARGS` rather than the development arguments above.

## Before production

- Replace the reduced bootstrap requirements and placeholder lock with the
  complete CPU locks from the 3.7 GA maintenance tag; set the immutable
  `BOOTSTRAP_LINEAGE` tag.
- Add Cachi2 inputs and switch both bootstrap and training installs to
  `--no-index`/prefetched artifacts; include PDF RPM inputs if PDF export is
  retained.
- Validate the approved AIPCC base includes OpenMPI, Python/uv, and all OS
  contracts used here. Keep EL9 and Python 3.12.
- Recreate the owned bootstrap independently for CUDA and ROCm, using their
  separately approved bases, indexes, locks, and accelerator smoke tests.
- Add the production component's Konflux configuration and run
  `UV_SYSTEM_CERTS=true make verify-universal-requirements` from the repository
  root. Do not change the existing production Dockerfile until this PoC is
  reviewed.

References: [training image guide](../README.md),
[dual-purpose image ADR](https://github.com/opendatahub-io/architecture-context/blob/main/overlays/0013-universal-training-image-dual-purpose.md), and
[notebooks minimal source](https://github.com/opendatahub-io/notebooks/tree/main/jupyter/minimal/ubi9-python-3.12).
