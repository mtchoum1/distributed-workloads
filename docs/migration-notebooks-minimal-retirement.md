# DevX migration from Notebooks minimal images

## Decision and deadline

DevX will make the Training Hub universal images self-contained before the RHOAI 3.8 kickoff (**RHAI-21742**). After RHOAI 3.7 GA, no DevX build may rely on a published Notebooks minimal OCI image, `jupyter/minimal` on the Notebooks `main` branch, a Notebooks-`main` submodule, or a future Notebooks minimal rebuild. This is the consumer-signoff work required by RHAIENG-7905 and unblocks the RHAIENG-7981 wave-2 retirement.

The source handoff is a one-time, versioned archival export at 3.7 GA. It comes from a Notebooks maintenance branch/tag and is not a live build dependency or a promise to rebuild minimal images for DevX. The resulting DevX component stays on EL9 and Python 3.12.

The architecture decision for the two-purpose training image is public: [ADR 0013](https://github.com/opendatahub-io/architecture-context/blob/main/overlays/0013-universal-training-image-dual-purpose.md). Jupyter Universal is deliberately not a base for this work: it is an Elyra/KFP workbench/runtime, not a Training Hub/PyTorch base.

## Current and target architecture

Each flavor independently replaces its external minimal image base with an
internal, DevX-owned `jupyter-bootstrap` stage on the matching AIPCC base. The
three existing directories and their future layout remain DevX's decision; this
migration does not require a directory consolidation or build-system redesign.

The owned bootstrap includes the Jupyter server/launcher contract, its locked
Python dependencies, needed Jupyter utility scripts/configuration, and any
selected PDF/OS dependency contract. The training layer remains responsible
for PyTorch, Training Hub, MPI/SSH, and `/usr/local/bin/entrypoint-universal.sh`.

## Milestones and exit criteria

| Milestone | Work | Exit criteria |
| --- | --- | --- |
| **A. Vendor bootstrap** | At 3.7 GA, export each flavor's locked minimal inputs from the Notebooks maintenance tag; commit them under DevX ownership and record `BOOTSTRAP_LINEAGE=notebooks@<git-tag>`. | No Dockerfile fetches, copies, or refers to Notebooks at build time; full locks, scripts, and provenance are reviewable in the DevX repo. |
| **B. Rebase Dockerfiles** | Replace the external minimal image base with an internal `jupyter-bootstrap` stage on the approved AIPCC base. Preserve CPU/CUDA/ROCm entrypoint, MPI, SSH, and OpenShift arbitrary-UID behavior. | Each flavor has no `FROM ...jupyter-minimal...`; local build works from a DevX-only checkout; base and index are immutable/approved. |
| **C. Release 3.7 readiness** | Build and smoke all flavors; set up Cachi2/Konflux inputs; obtain AIPCC and Trainer compatibility signoff. | Workbench and runtime smoke tests pass, full lock verification passes, and DevX has published internal image candidates before 3.8 kickoff. |
| **D. Cut dependency** | Switch downstream/DevX build and test configuration to owned images, remove obsolete references, and record migration evidence. | The zero-reference scan is clean, no Notebooks rebuild is in the release plan, and DevX declares readiness before RHAI-21742. |

## RACI

| Activity | DevX | Notebooks | AIPCC | Trainer |
| --- | --- | --- | --- | --- |
| Own vendored bootstrap and Dockerfiles | **A/R** | C | C | C |
| One-time 3.7 tag/export and minimal retirement | C | **A/R** | I | I |
| EL9 flavor bases, index and hermetic availability | C | C | **A/R** | C |
| Training Hub/PyTorch compatibility and runtime contracts | R | I | C | **A/R** |
| Workbench and runtime release signoff | **A/R** | C | C | R |

**A** = accountable, **R** = responsible, **C** = consulted, **I** = informed.

## Per-flavor adoption checklist

| Flavor | Vendored inputs | 3.7 AIPCC base and index | Status/open question |
| --- | --- | --- | --- |
| CPU | `start-notebook.sh`, Jupyter utilities/config, full `requirements.cpu.txt`, `pylock.cpu.toml`, selected PDF/RPM inputs, permission helper contract | `cpu-torch2.13-el9.8`; `https://packages.redhat.com/api/pypi/public-rhai/cpu-torch2.13-el9.8/simple/` | Additive PoCs supplied (`-poc-lean` and `-poc`). Full locks / `BOOTSTRAP_LINEAGE` still required. AIPCC must approve final tag/digest and all Training Hub wheels. |
| CUDA | CPU set plus CUDA-flavor requirements/lock and accelerator smoke scripts | `cuda13.0-torch2.13-el9.8`; `https://packages.redhat.com/api/pypi/public-rhai/cuda13.0-torch2.13-el9.8/simple/` | Confirm the final CUDA base/image tooling and GPU test environment with AIPCC and Trainer. |
| ROCm | CPU set plus ROCm-flavor requirements/lock and accelerator smoke scripts | `rocm7.14-torch2.12-el9.8`; `https://packages.redhat.com/api/pypi/public-rhai/rocm7.14-torch2.12-el9.8/simple/` | Confirm the Torch 2.12 base is compatible with the chosen Training Hub ROCm stack; if not, AIPCC supplies the approved replacement base/index. |

The base names and indexes above are the public 3.7 Notebooks build-input candidates, not a promise that their current tags/digests are production approved. DevX must pin the accepted digest during milestone B.

## Validation plan

1. Build from a clean DevX checkout with no sibling Notebooks checkout: `podman build -f Dockerfile.poc -t th-torch-cpu-poc:lean .` under `th-torch-cpu-py312-poc-lean/`, and `podman build -f Dockerfile.poc -t th-torch-cpu-poc:bootstrap .` under `th-torch-cpu-py312-poc/`.
2. Workbench smoke: run with platform-style `NOTEBOOK_ARGS`; verify `start-notebook.sh` starts JupyterLab and the Jupyter API is reachable.
3. Runtime smoke: override the entrypoint or use the Trainer command path and run `python -c 'import torch; import training_hub'`.
4. MPI/OpenShift smoke: use an arbitrary UID and validate MPI launcher/SSH behavior for the flavors that support it.
5. Dependency validation: regenerate or verify each full, hash-locked requirements set against its flavor index and run `UV_SYSTEM_CERTS=true make verify-universal-requirements`.
6. Konflux validation: build with Cachi2 prefetched RPM and wheel inputs, with both bootstrap and training installs offline. This is required before production promotion, not before local PoC review.
7. Guardrail: scan the DevX tree and built Dockerfile inputs for `jupyter-minimal`, `odh-workbench-jupyter-minimal`, Notebooks submodules, and build-time `git clone`/remote copy operations.

## Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| RHAIENG-7742 slips a GPU minimal-source rebase. | Finish DevX ownership and base/index selection independently. A temporary Notebooks maintenance source may be an archival handoff only; it must not become a post-3.7 operational dependency. |
| Cachi2 cannot reproduce the online PoC. | Treat the PoC as local-only; before promotion, add complete wheel/RPM inputs, verify an offline build, and retain the exact lock provenance. |
| AIPCC index URL/package availability drifts. | Keep URL, channel/base digest, lock generation command, and `BOOTSTRAP_LINEAGE` together; AIPCC signs off availability before merging each flavor. |
| Jupyter bootstrap differs from legacy minimal behavior. | Vendor all required scripts/config and test workbench startup/API, arbitrary UID, and Jupyter extensions; do not assume Training Hub requirements provide JupyterLab. |
| GPU ABI or Torch mismatch. | Keep CUDA and ROCm migrations separate from CPU; validate the final accelerator base, Torch, drivers, collectives, and Trainer version on real hardware. |

## Explicit non-goals

- Using Notebooks Jupyter Universal as the training-image base.
- A submodule, git clone, remote copy, or Docker build context from Notebooks `main` after 3.7 GA.
- Waiting for a Notebooks minimal rebuild after 3.7 GA.
- Replacing the legacy production CPU Dockerfile with this PoC before review.
- Treating the online local PoC as Konflux hermetic-build signoff.

## One-time Notebooks handoff at 3.7 GA

Notebooks supplies a public maintenance tag and an immutable export manifest for each flavor. The manifest identifies the tag, AIPCC base digest, index URL, full requirements/pylock files, Jupyter scripts/configuration, RPM/PDF inputs, and license/provenance. DevX imports those files once, records `BOOTSTRAP_LINEAGE=notebooks@<git-tag>`, and owns all future changes. A maintenance branch remains archival/EUS support only; it is not in any DevX build path.

## Gap analysis

### Notebooks retirement scope

The stated RHAIENG-7981 wave-2 scope removes `jupyter/minimal/**` for CPU/CUDA/ROCm, their standalone build/Tekton components, and corresponding ImageStream entries (leaving retirement stubs as applicable). The task brief refers once to “7983”; this plan treats that as RHAIENG-7981 unless the release owner confirms a separate tracker.

Before that deletion, the surviving Notebooks Jupyter Universal Dockerfiles must themselves retain or inline their own Jupyter-minimal contract:

- Jupyter requirements/locks and any meta-package resolution needed by Universal;
- `start-notebook.sh`, `process.sh`, server configuration, JupyterLab addon handling, kernel metadata setup, and arbitrary-UID permissions;
- selected PDF/pandoc/RPM setup and its hermetic inputs;
- embedded minimal-stage OS package and post-install behavior.

That is Notebooks work. It does not make Jupyter Universal a permitted DevX base and is not in the CPU PoC scope.

### Current distributed-workloads inventory

At inventory time, the only build-time references to published Notebooks minimal images were:

- `images/universal/training/th-torch-cpu-py312/Dockerfile`;
- `images/universal/training/th-torch-cuda-py312/Dockerfile`;
- `images/universal/training/th-torch-rocm-py312/Dockerfile`.

Each defaults `BASE_IMAGE` to an `odh-workbench-jupyter-minimal-*-py312-ubi9` image. Production directories are left unchanged on this branch.

Two **additive** CPU PoCs remove that dependency without editing production Dockerfiles:

- [`th-torch-cpu-py312-poc-lean/`](../images/universal/training/th-torch-cpu-py312-poc-lean/) — `odh-base` + lean in-repo `start-notebook.sh` and `jupyterlab`/`ipykernel` install (no Elyra/Kale);
- [`th-torch-cpu-py312-poc/`](../images/universal/training/th-torch-cpu-py312-poc/) — AIPCC base + vendored `jupyter-bootstrap/` with `BOOTSTRAP_LINEAGE` (migration-plan style).

Pros/cons and when to prefer each: [POC-README.md](../images/universal/training/POC-README.md). Milestones B–D still require full locks, provenance, and Konflux/Cachi2 offline validation before production promotion.

## Rough effort after the PoC

Assuming approved bases/indexes and access to the target hardware: CPU is approximately 3–5 engineer-days for full locks, offline build, and CI; CUDA is 5–8 days; ROCm is 5–8 days; and shared Konflux/Cachi2 enablement is 5–10 days. These are planning ranges, not release commitments; AIPCC package or accelerator compatibility gaps can extend them.

Public references: [DevX training images](https://github.com/opendatahub-io/distributed-workloads/tree/main/images/universal/training), [Notebooks minimal source](https://github.com/opendatahub-io/notebooks/tree/main/jupyter/minimal/ubi9-python-3.12), and [Notebooks Universal source](https://github.com/opendatahub-io/notebooks/tree/main/jupyter/universal/ubi9-python-3.12).
