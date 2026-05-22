# AeroBeat Tool Camera Tracking — Gesture-Testbed Live Preview/Public-State Slice

**Date:** 2026-05-22  
**Status:** In Progress  
**Agent:** Cookie 🍪

---

## Goal

Finish the tool-owned live `CameraTracking` public-service semantics the gesture testbed still needs, with special attention to preview attachment behavior and public state truth when a session is shared across multiple consumers.

---

## Overview

The tool repo already owns the public `CameraTracking` service, continuous live state, backend registration, and preview attachment semantics. But the downstream audit still left a live-mode gap for the gesture testbed: the testbed’s bottom-right media inset and provider snapshot path assume the shared live session can support its preview/state expectations without collapsing ownership back into the old monolith or lying about borrowed-vs-owned behavior.

This slice stays in the tool boundary. `aerobeat-tool-camera-tracking` should harden the public-service and preview behavior needed when the gesture testbed borrows or owns a live session: stable public preview attachment semantics, truthful active-config/public-state reads for the borrowed lane, and no regressions for proving-harness preview behavior.

Replay is out of scope in this plan. This is the second implementation wave after the input live adapter slice.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Cross-repo coordination plan | `/workspace/projects/openclaw-cookie/.plans/aerobeat-architecture/2026-05-22-gesture-testbed-full-parity.md` |
| `REF-02` | Downstream parity audit | `/workspace/projects/openclaw-cookie/.plans/aerobeat-architecture/2026-05-22-downstream-testbed-parity-audit.md` |
| `REF-03` | Gesture testbed script | `/workspace/projects/aerobeat/aerobeat-tool-camera-gesture-control/.testbed/scripts/camera_gesture_testbed.gd` |
| `REF-04` | Public camera-tracking service | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTracking.gd` |
| `REF-05` | Preview descriptor helper | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTrackingPreview.gd` |
| `REF-06` | Public config contract | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTrackingConfig.gd` |
| `REF-07` | Live integration slice already green | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.plans/2026-05-22-live-camera-integration-slice.md` |
| `REF-08` | Continuous public-state slice already green | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.plans/2026-05-22-continuous-tracking-public-state-slice.md` |

---

## Slice Boundaries

### In scope

- preserve proving-harness preview behavior while making shared live-session preview attachment semantics safe for the gesture testbed’s media inset path
- strengthen public active-config / preview / state truth needed when a live `CameraTracking` session is reused across lanes
- expose only the minimal additional public facts needed for the gesture testbed’s provider snapshot and media-inset behavior
- add/update repo-local tests and proving glue for borrowed/owned live preview attachment behavior

### Explicitly out of scope

- replay / `video_file` support
- input-addon alias compatibility work
- vendor runtime/source changes
- broader new public schema beyond the minimum needed for the live gesture-testbed surface

---

## Tasks

### Task 1: Implement live preview/public-state semantics for gesture testbed

**Bead ID:** `atct-dyf`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking`, claim bead `atct-dyf` with `bd update atct-dyf --status in_progress --json` when you start. Implement the narrowest honest live gesture-testbed slice from `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.plans/2026-05-22-gesture-testbed-live-preview-public-state-slice.md`. Required outcomes: keep proving-harness preview compatibility green, make shared live-session preview attachment semantics safe/truthful for the gesture testbed’s media inset path, and expose only the minimal public-state/active-config facts needed for the live borrowed-vs-owned downstream behavior. Do not broaden into replay, input-addon alias work, or vendor runtime changes. Run relevant repo-local validation, commit, and push before handoff unless blocked.

**Folders Created/Deleted/Modified:**
- `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/`
- `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.testbed/`
- `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.plans/`

**Files Created/Deleted/Modified:**
- `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTracking.gd`
- `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTrackingPreview.gd`
- `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.testbed/tests/test_CameraTracking.gd`
- `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/README.md`
- `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.plans/2026-05-22-gesture-testbed-live-preview-public-state-slice.md`

**Status:** ✅ Complete

**Results:** Claimed `atct-dyf` with `bd update atct-dyf --status in_progress --json` and kept the change inside the repo-owned public service / preview layer. `src/CameraTracking.gd` no longer treats preview attachment as a single global slot that the newest consumer can irreversibly stomp. It now keeps a truthful stacked attachment list for shared live sessions: the most recently attached surface is active, duplicate attaches are deduped/moved to the top, invalid/freed surfaces are pruned, and `detach_preview_surface()` restores the previous active attachment instead of collapsing the whole preview state. That keeps proving-harness ownership green while making temporary live media-inset attachment safe for a borrowed consumer lane.

`src/CameraTrackingPreview.gd` now surfaces the minimal additive public preview fact needed for that shared-session behavior: `attached_surface_count`. The descriptor still reports the active `surface_path`, `attached`, `surface_mode`, `flip_horizontal`, and backend identity, but can now truthfully say whether a live session has one attachment or several queued tool-owned attachments behind the active one.

Repo-local tests in `.testbed/tests/test_CameraTracking.gd` were expanded to prove the new public semantics: detached defaults report `attached_surface_count = 0`; single attach/detach remains green; a second attachment temporarily becomes active while preserving the first; detaching the newest attachment restores the previous surface; and the real vendor-backed live-camera path keeps proving-harness preview compatibility while allowing a second inset-style attachment to come and go without losing the original preview slot.

Validation run in this repo:
- `./scripts/prepare_testbed.sh && godot --headless --path .testbed --import && godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gtest=res://tests/test_CameraTracking.gd -gexit` ✅ (`12/12` tests passed)
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ (`14/14` tests passed)

---

### Task 2: QA live preview/public-state semantics for gesture testbed

**Bead ID:** `atct-0fu`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking`, wait until bead `atct-0fu` is unblocked, then claim it with `bd update atct-0fu --status in_progress --json`. Independently verify the live gesture-testbed tool slice. Prove shared live preview attachment behavior stays truthful, prove public active-config / preview / state reads support the borrowed-vs-owned downstream flow without regressing the proving harness, and confirm repo ownership stayed in tool-owned source instead of addon mirrors. Record exact commands/results/gaps and leave the auditor bead open.

**Folders Created/Deleted/Modified:**
- validation-only use of repo-local proving surfaces

**Files Created/Deleted/Modified:**
- none required unless a minimal QA artifact is necessary

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 3: Audit live preview/public-state semantics for gesture testbed

**Bead ID:** `atct-c8n`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking`, wait until bead `atct-c8n` is unblocked, then claim it with `bd update atct-c8n --status in_progress --json`. Independently audit the live gesture-testbed tool slice against this plan, the diff, coder evidence, and QA evidence. Close the bead only if the public-service / preview semantics are genuinely proven for the shared live session case, the proving-harness path remains green, and the repo stayed inside tool-owned boundaries.

**Folders Created/Deleted/Modified:**
- audit notes only if needed

**Files Created/Deleted/Modified:**
- none required unless a minimal audit artifact is necessary

**Status:** ⏳ Pending

**Results:** Pending.

---

## Dependency Shape

- `atct-dyf` → coder implementation bead
- `atct-0fu` depends on `atct-dyf`
- `atct-c8n` depends on `atct-0fu`

Cross-repo coordination note: this live tool slice should begin after the input live auditor bead `aerobeat-input-camera-tracking-yu1` closes.

---

## Final Results

**Status:** ⚠️ Partial

**What We Built:** Implemented the coder slice for shared live-session preview/public-state semantics in the tool-owned `CameraTracking` service. Preview attachment is now stack-safe for shared sessions, the preview descriptor exposes `attached_surface_count`, and repo-local tests prove that the active preview surface can temporarily switch for an inset-style consumer and then restore the prior proving-harness attachment.

**Reference Check:** `REF-04`, `REF-05`, `REF-06`, `REF-07`, and `REF-08` are satisfied for the planned coder scope. The slice preserved proving-harness preview behavior while strengthening the tool-owned public preview truth needed for shared live-session reuse. Replay remains intentionally untouched.

**Commits:**
- Pending coder commit.

**Lessons Learned:** The honest live gap in this repo was not another runtime boot path. It was preview ownership semantics under shared-session reuse: a single-slot attach model is too brittle once more than one consumer can temporarily borrow the same live service.

---

*Prepared on 2026-05-22*
