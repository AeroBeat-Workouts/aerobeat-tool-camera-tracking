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
- `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.plans/2026-05-22-gesture-testbed-replay-public-service-slice.md`

**Status:** ✅ Complete

**Results:** Claimed `atct-a7h` after verifying dependency bead `atct-7q9` was closed, then independently QA’d commit `6c5c091` (`Surface replay through CameraTracking service`). QA confirms the public `CameraTracking` seam now truthfully surfaces replay / `video_file` through repo-owned lifecycle/state/detail/frame/preview/source coordination instead of stopping at the vendor boundary.

Implementation truth check during QA:
- `src/CameraTracking.gd` now refreshes cached public frame/preview/camera surfaces inside `_on_backend_state_changed()`, so stop/idle transitions no longer leave stale live or replay public reads behind.
- `.testbed/tests/test_CameraTracking.gd` replaced the old unsupported replay assumption with `test_registered_vendor_backend_change_surfaces_truthful_restart_into_replay_and_public_stop()`, which drives live → live-change → replay/video-file → stop through public `CameraTracking` APIs and asserts truthful `source.kind`, `source_id`, preview/backend facts, readiness flags, replay timestamps, and idle settlement.
- Scope stayed tool-owned: the commit only touched repo-root sources/tests/docs/plan files (`src/CameraTracking.gd`, `.testbed/tests/test_CameraTracking.gd`, `README.md`, and this plan). No addon mirrors were edited as owned source, and public lifecycle/state/detail/preview/source coordination remained in `CameraTracking`.

Validation run during QA:
- `bd show atct-a7h --json`
- `bd update atct-a7h --status in_progress --json`
- `git status --short`
- `git log --oneline --decorate -n 5`
- `git diff --stat HEAD~1..HEAD`
- `git diff --name-only HEAD~1..HEAD`
- `git diff -- .plans/2026-05-22-gesture-testbed-live-preview-public-state-slice.md`
- `./scripts/prepare_testbed.sh`
- `godot --headless --path .testbed --import`
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gtest=res://tests/test_CameraTracking.gd -gexit` ✅ (`12/12` passed, `151` asserts)
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ (`14/14` passed, `160` asserts)
- `grep -RIn "video_file\|replay\|source_kind\|source_id\|tracking_ready\|preview_ready\|backend_ready\|source_ready\|_on_backend_state_changed\|_compose_preview_descriptor" src .testbed/tests README.md`

QA verdict: pass. No repo-local functional gaps found for this replay public-service slice; auditor bead `atct-mv8` should remain open for independent audit.

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

**Status:** ✅ Complete

**Results:** Claimed `atct-mv8` after verifying the dependency on QA bead `atct-a7h` was closed, then independently audited commit `6c5c091` (`Surface replay through CameraTracking service`) against the plan, repo diff, coder notes, and QA notes. Audit passes for the planned replay public-service scope.

Implementation truth check:
- `src/CameraTracking.gd:316-323` now refreshes `_tracking_frame`, `_preview_descriptor`, and `_last_cameras` inside `_on_backend_state_changed()`, so public service reads no longer stay stale after backend stop/idle transitions.
- `src/CameraTrackingFrame.gd:8-18` already defines public replay identity truthfully (`source_kind = video_file`, `source_id = path`), and the audited slice now exercises that path through the public `CameraTracking` service instead of stopping at an unsupported-source assumption.
- `.testbed/tests/test_CameraTracking.gd:396-458` replaces the old unsupported replay expectation with `test_registered_vendor_backend_change_surfaces_truthful_restart_into_replay_and_public_stop()`, which drives live → live-change → replay/video-file → stop through the public API and asserts truthful `active_config`, `source_kind`, `source_id`, preview/backend facts, replay timestamps, readiness flags, and idle settlement.

Scope/ownership audit:
- `git diff --name-only 6c5c091^..6c5c091` shows only repo-owned files changed: `src/CameraTracking.gd`, `.testbed/tests/test_CameraTracking.gd`, `README.md`, and this plan.
- Public lifecycle/state/detail/preview/source coordination remained owned by `src/CameraTracking.gd`; there was no drift into addon mirrors, downstream consumer repos, or vendor raw-runtime ownership.
- README scope text now truthfully documents replay/video-file flowing through the same public service seam, but no new public schema beyond the planned minimal replay slice was introduced.

Independent validation rerun during audit:
- `./scripts/prepare_testbed.sh` ✅
- `godot --headless --path .testbed --import` ✅
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gtest=res://tests/test_CameraTracking.gd -gexit` ✅ (`12/12` passed, `151` asserts)
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ (`14/14` passed, `160` asserts)
- `grep -RIn "video_file\|unsupported_source_kind\|_on_backend_state_changed\|tracking_ready\|source_id\|source_kind\|preview_descriptor\|get_active_config\|replay" src .testbed/tests README.md` ✅

Unstaged residue check:
- `git diff -- .plans/2026-05-22-gesture-testbed-live-preview-public-state-slice.md` shows substantive QA/audit/final-results documentation for the already-complete live preview slice, not throwaway scratch noise.
- That residue does not invalidate this replay audit, but it should be committed (or consciously discarded) before treating the repo as clean for continuation, because it is durable plan state for completed work and is the only unrelated dirty file in the worktree.

Audit verdict: pass. The replay public-service slice is genuinely complete for its planned scope, so bead `atct-mv8` can be closed.

---

## Dependency Shape

- `atct-7q9` → coder implementation bead
- `atct-a7h` depends on `atct-7q9`
- `atct-mv8` depends on `atct-a7h`

Cross-repo coordination note: this replay tool slice should begin after vendor replay auditor bead `avmp-7uq` closes. The input replay slice should start after `atct-mv8` closes.

---

## Final Results

**Status:** ✅ Complete

**What We Built:** Completed the gesture-testbed replay public-service parity slice in the tool-owned `CameraTracking` service. Replay/video-file sessions now flow through the same public lifecycle/state/detail/frame/preview/source seam as live mode at the minimal truthful scope, and stop/idle transitions now refresh cached public surfaces so stale frames/previews/camera lists do not linger after replay stops.

**Reference Check:** `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, and `REF-08` are satisfied for the planned scope. Replay now crosses the tool-owned public-service boundary truthfully, repo-local proving covers replay start/change/stop expectations instead of the old unsupported-source assumption, and the slice did not broaden into downstream input-addon compatibility or vendor raw-runtime ownership. `REF-01` and `REF-02` remain aligned at the cross-repo coordination level.

**Commits:**
- `6c5c091` - Surface replay through CameraTracking service

**Lessons Learned:** The replay parity gap was not a new public schema problem; it was cache truth and proving ownership. Once the vendor lane could replay truthfully, this repo only needed to refresh its cached public surfaces on backend state changes and move replay expectations into repo-owned `CameraTracking` tests instead of preserving an outdated rejection assumption.

---

*Prepared on 2026-05-22*
