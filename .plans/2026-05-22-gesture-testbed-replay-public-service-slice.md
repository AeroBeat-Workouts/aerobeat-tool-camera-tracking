# AeroBeat Tool Camera Tracking — Gesture-Testbed Replay Public-Service Slice

**Date:** 2026-05-22  
**Status:** In Progress  
**Agent:** Cookie 🍪

---

## Goal

Surface the replay lane through the public `CameraTracking` contract truthfully once the vendor repo can provide a replay runtime/source lane.

---

## Overview

Once `aerobeat-vendor-mediapipe-python` supports replay truthfully, the tool repo becomes the next owner in the chain. The gesture testbed does not consume raw vendor payloads directly; it expects replay to appear through the same public `CameraTracking` service and preview/state surfaces that live mode uses.

This slice keeps that boundary strict. `aerobeat-tool-camera-tracking` should accept replay configs through the public contract, preserve truthful source/preview/state semantics, and expose replay through the existing public service without broadening into input-addon compatibility work or vendor-specific raw runtime internals.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Cross-repo coordination plan | `/workspace/projects/openclaw-cookie/.plans/aerobeat-architecture/2026-05-22-gesture-testbed-full-parity.md` |
| `REF-02` | Downstream parity audit | `/workspace/projects/openclaw-cookie/.plans/aerobeat-architecture/2026-05-22-downstream-testbed-parity-audit.md` |
| `REF-03` | Gesture testbed script | `/workspace/projects/aerobeat/aerobeat-tool-camera-gesture-control/.testbed/scripts/camera_gesture_testbed.gd` |
| `REF-04` | Public camera-tracking service | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTracking.gd` |
| `REF-05` | Public frame contract | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTrackingFrame.gd` |
| `REF-06` | Public preview helper | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTrackingPreview.gd` |
| `REF-07` | Vendor replay runtime/source plan | `/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/.plans/2026-05-22-gesture-testbed-replay-runtime-source-slice.md` |
| `REF-08` | Continuous public-state slice already green | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.plans/2026-05-22-continuous-tracking-public-state-slice.md` |

---

## Slice Boundaries

### In scope

- accept replay / `video_file` configs through the public contract once the vendor layer supports them
- preserve truthful source-kind/source-id/public preview semantics for replay sessions
- keep public frame/state guarantees conservative and honest for replay
- add/update repo-local tests and proving glue for replay start/change/stop behavior through `CameraTracking`

### Explicitly out of scope

- input-addon alias/session compatibility work
- vendor raw runtime ownership
- new rich public schema beyond what the gesture testbed replay lane actually needs

---

## Tasks

### Task 1: Implement replay public-service semantics for gesture testbed

**Bead ID:** `atct-7q9`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking`, claim bead `atct-7q9` with `bd update atct-7q9 --status in_progress --json` when you start. Implement the narrowest honest replay slice from `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.plans/2026-05-22-gesture-testbed-replay-public-service-slice.md`. Required outcomes: make the public `CameraTracking` contract accept and surface replay / `video_file` sessions truthfully once the vendor replay lane exists, preserve conservative source/preview/frame/state semantics, and validate replay start/change/stop behavior through repo-owned tool surfaces. Do not broaden into input-addon compatibility or vendor raw-runtime ownership. Run relevant repo-local validation, commit, and push before handoff unless blocked.

**Folders Created/Deleted/Modified:**
- `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/`
- `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.testbed/`
- `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.plans/`

**Files Created/Deleted/Modified:**
- `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTracking.gd`
- `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.testbed/tests/test_CameraTracking.gd`
- `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/README.md`
- `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.plans/2026-05-22-gesture-testbed-replay-public-service-slice.md`

**Status:** ✅ Complete

**Results:** Implemented the narrowest repo-owned replay public-service slice without vendor-scope drift. `src/CameraTracking.gd` now refreshes tool-owned cached frame/preview/camera surfaces on backend state transitions so public reads stay truthful during stop/idle settlement instead of retaining stale replay/live frames. Repo-local proving was updated in `.testbed/tests/test_CameraTracking.gd` to replace the old honest-unsupported `video_file` expectation with a truthful public replay path: start/change into `source.kind = video_file`, preserve public preview/source semantics, advance replay timestamps through the public service, and prove stop returns the public state/detail/frame shell to idle while keeping replay source identity truthful. `README.md` now documents replay/video-file flowing through the same public `CameraTracking` seam as live mode at the current minimal honest scope. Validation after refreshing testbed addons to the latest vendor main: `./scripts/prepare_testbed.sh` ✅, `godot --headless --path .testbed --import` ✅, `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ (`14/14` tests, `160` asserts). Coder result is ready for QA.

---

### Task 2: QA replay public-service semantics for gesture testbed

**Bead ID:** `atct-a7h`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking`, wait until bead `atct-a7h` is unblocked, then claim it with `bd update atct-a7h --status in_progress --json`. Independently verify the replay tool slice. Prove `CameraTracking` can start/change/stop a replay session truthfully, prove public source-kind/source-id/preview/frame/state reads stay honest, and confirm the work remained in repo-owned tool surfaces rather than addon mirrors. Record exact commands/results/gaps and leave the auditor bead open.

**Folders Created/Deleted/Modified:**
- validation-only use of repo-local proving surfaces

**Files Created/Deleted/Modified:**
- none required unless a minimal QA artifact is necessary

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 3: Audit replay public-service semantics for gesture testbed

**Bead ID:** `atct-mv8`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking`, wait until bead `atct-mv8` is unblocked, then claim it with `bd update atct-mv8 --status in_progress --json`. Independently audit the replay tool slice against this plan, the diff, coder evidence, and QA evidence. Close the bead only if replay now surfaces truthfully through the public `CameraTracking` contract, the public frame/state semantics stayed conservative, and the repo remained inside tool-owned boundaries.

**Folders Created/Deleted/Modified:**
- audit notes only if needed

**Files Created/Deleted/Modified:**
- none required unless a minimal audit artifact is necessary

**Status:** ⏳ Pending

**Results:** Pending.

---

## Dependency Shape

- `atct-7q9` → coder implementation bead
- `atct-a7h` depends on `atct-7q9`
- `atct-mv8` depends on `atct-a7h`

Cross-repo coordination note: this replay tool slice should begin after vendor replay auditor bead `avmp-7uq` closes. The input replay slice should start after `atct-mv8` closes.

---

## Final Results

**Status:** ⚠️ Partial

**What We Built:** Coder slice complete: replay/video-file sessions now surface through the repo-owned `CameraTracking` service/testbed seam with truthful source/preview/frame/state behavior for the narrow gesture-testbed path, and stop-time public reads no longer retain stale tracked frames after backend idle transitions.

**Reference Check:** `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, and `REF-08` are now exercised at the coder level for the planned scope. Replay no longer stops at the vendor boundary; it now crosses the tool-owned public-service boundary without broadening into downstream input-addon compatibility work.

**Commits:**
- Pending coder commit.

**Lessons Learned:** The replay public-service problem was mostly about keeping the tool-owned cached public surfaces truthful when backend state changes, plus updating repo-local proving to stop assuming legacy `video_file` rejection once the vendor lane turned green.

---

*Prepared on 2026-05-22*
