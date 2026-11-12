# Training-image PoCs: Notebooks minimal retirement

Two **additive** CPU PoCs explore how DevX can keep dual-mode Training Hub
images after Notebooks retires `jupyter-minimal-*`, without using Jupyter
Universal (Elyra/Kale) as a base.

Production directories (`th-torch-{cpu,cuda,rocm}-py312/`) are unchanged.
Promote only after review, locks, and Konflux/Cachi2 validation.

Migration context:
[docs/migration-notebooks-minimal-retirement.md](../../../docs/migration-notebooks-minimal-retirement.md).
Architecture:
[ADR 0013](https://github.com/opendatahub-io/architecture-context/blob/main/overlays/0013-universal-training-image-dual-purpose.md).

## PoC folders

| Folder | Style | Base | Workbench ownership |
|--------|-------|------|---------------------|
| [`th-torch-cpu-py312-poc-lean/`](th-torch-cpu-py312-poc-lean/) | Lean (this branch's approach) | `odh-base-image-cpu-*` | In-repo `start-notebook.sh` + unlocked `jupyterlab` / `jupyter-server` / `ipykernel` install |
| [`th-torch-cpu-py312-poc/`](th-torch-cpu-py312-poc/) | Bootstrap (atheo / migration-plan) | AIPCC `cpu-torch2.13-el9.8` | Vendored `jupyter-bootstrap/` (scripts, config, requirements, lineage) |

Both use `Dockerfile.poc` and keep the production tree intact.

## Pros and cons

### Lean PoC (`th-torch-cpu-py312-poc-lean`)

**Pros**

- Smallest delta from today's production Dockerfile (same midstream/downstream pattern).
- Stays on familiar midstream `odh-base` digests already used by Notebooks.
- Explicitly avoids Elyra/Kale without vendoring a large Jupyter tree.
- Easy to extend to CUDA/ROCm by copying the same lean layer pattern.
- Fast local iteration for dual-mode smoke (workbench + runtime command).

**Cons**

- Workbench packages are not hash-locked yet (online `pip install` in the PoC).
- Missing Notebooks-parity helpers (`process.sh`, server config, PDF deps, labextension defaults).
- No `BOOTSTRAP_LINEAGE` provenance for the one-time 3.7 GA handoff.
- Behavior may drift from legacy minimal workbench probes/extensions.
- Weaker story for hermetic Konflux/Cachi2 signoff until locks are added.

### Bootstrap PoC (`th-torch-cpu-py312-poc`)

**Pros**

- Clear DevX-owned boundary: `jupyter-bootstrap/` is the Jupyter contract.
- Closer to the migration plan milestones (vendor → rebase → locks → cut).
- Records `BOOTSTRAP_LINEAGE=notebooks@…` for auditability.
- Includes starter scripts/config shape expected from Notebooks minimal export.
- Targets the 3.7 AIPCC flavor base/index directly (production-aligned channel).

**Cons**

- Larger additive tree and more moving parts to review.
- Reduced/placeholder Jupyter requirements until the real 3.7 GA export lands.
- Different base/index than current midstream production Dockerfiles (needs AIPCC digest pin).
- PDF/RPM path is opt-in and not hermetic in the local PoC.
- More upfront work before CUDA/ROCm replicas exist.

## When to prefer which

| Need | Prefer |
|------|--------|
| Fast dual-mode proof on today's midstream bases | **Lean** |
| Reviewable owned bootstrap + lineage for RHAIENG/RHAI exit criteria | **Bootstrap** |
| Closest path to hermetic Konflux promotion | **Bootstrap** (after full locks) |
| Smallest code review / CUDA-ROCm copy-paste first | **Lean**, then harden toward bootstrap |

Recommended path: use **lean** to validate product behavior quickly; use
**bootstrap** as the productionization template (full locks, lineage, offline
build) before changing `th-torch-*-py312/` Dockerfiles.

## Quick build

```bash
# Lean
cd images/universal/training/th-torch-cpu-py312-poc-lean
podman build -f Dockerfile.poc -t th-torch-cpu-poc:lean .

# Bootstrap
cd images/universal/training/th-torch-cpu-py312-poc
podman build -f Dockerfile.poc -t th-torch-cpu-poc:bootstrap .
```

Per-PoC smoke steps: [lean README](th-torch-cpu-py312-poc-lean/README-PoC.md),
[bootstrap README](th-torch-cpu-py312-poc/README-PoC.md).
