# AeroBeat Tool Camera Tracking — Contract-Shell Slice

**Date:** 2026-05-21  
**Status:** Stale  
**Agent:** Cookie 🍪

---

## Goal

Create the first execution-ready contract shell for camera tracking in this repo, with serialized repo-local Beads for coder → QA → auditor handoff.

---

## Overview

This repo is still at the fresh tool-template stage, so the first slice should establish a stable contract shell before any real backend integration work begins. The implementation should replace the current `AeroToolManager` template stub with camera-tracking-specific sharable code at the repo root, while using `.testbed/` only as the proving project and test surface.

The contract-shell slice intentionally stops short of real camera or MediaPipe integration. Instead, it should define the singleton lifecycle API, state model, signals, config helpers/model, backend interface, fake backend for tests, preview attachment contract, and a normalized tracking frame contract stub. That gives later slices a clean seam for backend-specific implementation without forcing downstream consumers to guess the shape.

Execution is serialized through repo-local Beads. The coder lane implements the shell and tests first, QA validates through `.testbed/`, and the auditor independently truth-checks scope, repo conventions, and evidence before closure. If dependency restoration is needed during implementation or validation, use `/home/derrick/.openclaw/workspace/scripts/godotenv-sync` rather than treating `.testbed/addons/` as an editing surface.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Tool-template repo conventions and `.testbed/` workflow | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/README.md` |
| `REF-02` | First-pass camera-tracking singleton API assumptions | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.plans/bootstrap-architecture/CAMERA-TRACKING-API.md` |
| `REF-03` | Current template singleton stub to be replaced or evolved | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/AeroToolManager.gd` |
| `REF-04` | Current repo-local test baseline showing template-only coverage | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.testbed/tests/test_AeroToolManager.gd` |
| `REF-05` | Current plugin metadata still branded as template | `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/plugin.cfg` |

Use these references for implementation and audit decisions instead of relying on memory.

---

## Tasks

### Task 1: Implement contract-shell slice for CameraTracking singleton

**Bead ID:** `atct-fry`  
**SubAgent:** `primary` (for `coder`)  
**Role:** `coder`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking`, claim bead `atct-fry` with `bd update atct-fry --status in_progress --json` when you start. Implement the first contract-shell slice for this repo. Required scope: singleton class, state enum/constants, signals, config helpers/model, backend interface class, fake backend for tests, preview attachment contract, and tracking frame contract stub. Keep sharable implementation code/assets at the repo root, use `.testbed/` only as the proving project, and do not treat `.testbed/addons/` as an owning edit surface. If dependency restoration is needed, note and use `/home/derrick/.openclaw/workspace/scripts/godotenv-sync`. Add or replace repo-local tests under `.testbed/tests/`, run the relevant repo-local validation you can support, and report the exact files changed plus commands/results. Leave the bead open if QA/audit are still pending; do not close downstream beads.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.testbed/tests/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/*`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.testbed/tests/*`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/plugin.cfg` (only if branding/entrypoint metadata must change to match the new singleton surface)
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/README.md` (only if usage notes must be updated to reflect the shell contract)

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 2: QA contract-shell slice in `.testbed`

**Bead ID:** `atct-boj`  
**SubAgent:** `primary` (for `qa`)  
**Role:** `qa`  
**References:** `REF-01`, `REF-02`, `REF-04`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking`, wait until bead `atct-boj` is unblocked, then claim it with `bd update atct-boj --status in_progress --json`. Verify the contract-shell implementation through the highest-fidelity repo-local validation available in `.testbed/`. At minimum, confirm imports are healthy, run the relevant automated tests for the singleton shell plus fake backend/config/tracking-frame contracts, and confirm the implementation did not rely on editing `.testbed/addons/` as an owning surface. If dependencies need restoration, use or note `/home/derrick/.openclaw/workspace/scripts/godotenv-sync`. Record exact commands, results, and any gaps. Do not close the auditor bead.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.testbed/` (validation-only; no owning-source edits inside `addons/`)

**Files Created/Deleted/Modified:**
- None required; QA should prefer evidence gathering over source changes.

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 3: Audit contract-shell slice against plan and QA evidence

**Bead ID:** `atct-46h`  
**SubAgent:** `primary` (for `auditor`)  
**Role:** `auditor`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking`, wait until bead `atct-46h` is unblocked, then claim it with `bd update atct-46h --status in_progress --json`. Independently audit the finished contract-shell slice against this plan, the repo diff, the test suite, and QA evidence. Verify all required scope exists: singleton class, state enum/constants, signals, config helpers/model, backend interface class, fake backend for tests, preview attachment contract, and tracking frame contract stub. Verify repo conventions were respected: sharable code/assets at repo root, `.testbed/` used as proving surface, `.testbed/addons/` not treated as an owning edit surface, and dependency restoration handled cleanly if needed. If the slice passes, close bead `atct-46h`; if not, report the exact gap and keep the lane active.

**Folders Created/Deleted/Modified:**
- None required.

**Files Created/Deleted/Modified:**
- None required; audit should only change files if a minimal audit note artifact becomes necessary.

**Status:** ⏳ Pending

**Results:** Pending.

---

## Dependency Shape

- `atct-fry` → first executable implementation bead
- `atct-boj` depends on `atct-fry`
- `atct-46h` depends on `atct-boj`

This enforces a serialized coder → QA → auditor lane in the owning repo.

---

## Final Results

**Status:** ⚠️ Partial

**What We Built:** Created the first execution-ready repo-local plan and the serialized repo-local Beads for the contract-shell slice. Implementation/QA/audit execution has not started yet.

**Reference Check:** Planning aligns with `REF-01` and `REF-02`; `REF-03` through `REF-05` are captured as current-state audit anchors.

**Commits:**
- None in this planning pass.

**Lessons Learned:**
- The repo already had an embedded Beads workspace, but its issue prefix was unset; `bd init --force --prefix atct --non-interactive --role maintainer` was required before repo-local bead creation would work.
- Running parallel `bd create` calls against embedded Dolt caused lock contention, so bead creation should be serialized for this repo.

---

*Prepared on 2026-05-21*
