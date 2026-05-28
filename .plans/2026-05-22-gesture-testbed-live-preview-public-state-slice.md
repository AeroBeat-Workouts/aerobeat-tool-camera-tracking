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

**Status:** ✅ Complete

**Results:** Claimed `atct-0fu` after verifying the bead was unblocked by closed dependency `atct-dyf`, then independently QA’d commit `49ddb53` (`Harden shared live preview attachment semantics`). QA confirms the live preview attachment semantics are now stack-safe inside the tool-owned public service: `src/CameraTracking.gd` replaced the old single `_attached_preview_surface` slot with `_attached_preview_surfaces`, prunes freed surfaces, dedupes re-attaches, keeps the newest surface active, and `detach_preview_surface()` restores the previous attachment instead of permanently stomping it. `src/CameraTrackingPreview.gd` truthfully exposes `attached_surface_count`, and repo-local tests prove detached/single/stacked/vendor-backed cases.

Targeted borrowed-consumer parity stayed green in the proving path: the vendor-backed live-camera test attaches a proving-harness `PreviewSlot`, temporarily borrows the session with `InsetPreviewSlot`, observes `surface_path = InsetPreviewSlot` with `attached_surface_count = 2`, then detaches and sees `surface_path = PreviewSlot` with `attached_surface_count = 1`. Public preview/state truth stayed coherent alongside earlier live/public-state slices: running state/detail readiness, `get_active_config()`, normalized tracking frames, backend identity, and preview descriptor reads all remained truthful in repo-local validation.

Scope/ownership checks also passed. The committed diff only touched repo-root tool-owned files plus the repo-local plan/tests/README: `src/CameraTracking.gd`, `src/CameraTrackingPreview.gd`, `.testbed/tests/test_CameraTracking.gd`, `README.md`, and this plan. No addon mirrors were edited as owned source, and no replay implementation drift happened; the only `video_file` / replay mentions in this repo-local QA pass were existing honest unsupported-source checks and unrelated vendor-plan/reference files under `.testbed`.

Validation run during QA:
- `bd ready --json`
- `bd show atct-0fu --json`
- `bd update atct-0fu --status in_progress --json`
- `git status --short`
- `git diff --name-only HEAD~1..HEAD`
- `git log --oneline -1`
- `git show --stat --oneline --decorate=short 49ddb53`
- `git show --unified=40 --no-ext-diff 49ddb53 -- src/CameraTracking.gd src/CameraTrackingPreview.gd .testbed/tests/test_CameraTracking.gd README.md .plans/2026-05-22-gesture-testbed-live-preview-public-state-slice.md`
- `./scripts/prepare_testbed.sh`
- `godot --headless --path .testbed --import`
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gtest=res://tests/test_CameraTracking.gd -gexit` ✅ (`12/12` passed, `126` asserts)
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ (`14/14` passed, `135` asserts)
- `grep -RIn "attached_surface_count\|attach_preview_surface\|detach_preview_surface\|video_file\|replay\|PreviewSlot\|InsetPreviewSlot" src .testbed README.md`

QA verdict: pass. No functional gaps found in this slice; leave auditor bead `atct-c8n` open for independent audit.

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

**Status:** ✅ Complete

**Results:** Claimed `atct-c8n` after verifying the dependency on QA bead `atct-0fu` was closed, then independently audited commit `49ddb53` (`Harden shared live preview attachment semantics`) against the plan, the repo diff, coder notes, and QA notes. Audit passes for the planned live-only scope.

Implementation truth check:
- `src/CameraTracking.gd:127-146` now treats preview attachments as a stack, not a single stompable slot: null/invalid nodes are ignored, duplicate re-attaches are deduped then moved to the top, and `detach_preview_surface()` pops only the newest attachment.
- `src/CameraTracking.gd:236-266` composes public preview state from the currently active top-of-stack surface while pruning freed nodes first, so public preview reads stay honest instead of advertising dead/restored attachments.
- `src/CameraTrackingPreview.gd:4-25` exposes `attached_surface_count` in both detached and attached descriptors, which makes the public preview descriptor truthful about whether the active preview is the only attachment or a borrowed top layer over an older one.

Borrowed-consumer / downstream-path reality check:
- `.testbed/tests/test_CameraTracking.gd:209-235` proves stack restoration in the abstract tool contract.
- `.testbed/tests/test_CameraTracking.gd:340-391` proves the real vendor-backed live path keeps the original proving-harness `PreviewSlot`, temporarily activates `InsetPreviewSlot` with `attached_surface_count = 2`, then restores `PreviewSlot` with count `1` after detach. That is real enough for the downstream live gesture-testbed inset path described in `REF-03`.
- `REF-03` still keeps live/replay ownership and session borrowing on the consumer side; this repo only hardened the shared preview/public-state seam it owns.

Scope/ownership audit:
- `git diff --name-only HEAD~1..HEAD` shows only repo-owned files changed: `src/CameraTracking.gd`, `src/CameraTrackingPreview.gd`, `.testbed/tests/test_CameraTracking.gd`, `README.md`, and this plan.
- No addon-mirror source was treated as owned source, and no replay implementation drift occurred. Replay/video-file mentions remain existing honest unsupported-source behavior and documentation only.
- Public state/detail ownership remained in this repo; there was no drift into downstream consumer code for this slice.

Independent validation rerun during audit:
- `./scripts/prepare_testbed.sh && godot --headless --path .testbed --import && godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gtest=res://tests/test_CameraTracking.gd -gexit` ✅ (`12/12` passed, `126` asserts)
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ (`14/14` passed, `135` asserts)

Audit verdict: pass. The live preview/public-state parity slice is genuinely complete for its planned scope, so bead `atct-c8n` can be closed.

---

## Dependency Shape

- `atct-dyf` → coder implementation bead
- `atct-0fu` depends on `atct-dyf`
- `atct-c8n` depends on `atct-0fu`

Cross-repo coordination note: this live tool slice should begin after the input live auditor bead `aerobeat-input-camera-tracking-yu1` closes.

---

## Final Results

**Status:** ✅ Complete

**What We Built:** Completed the live-only gesture-testbed preview/public-state parity slice in the tool-owned `CameraTracking` service. Shared live preview attachment is now stack-safe, the public preview descriptor truthfully reports `attached_surface_count`, and the proving-backed live path shows that a borrowed inset-style consumer can temporarily take the active preview surface and then restore the previous proving-harness attachment without losing truthful public state.

**Reference Check:** `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, and `REF-08` are satisfied for the planned scope. The implementation stayed inside repo-owned preview/public-state semantics, preserved the proving-harness lane, exposed only the minimal additive public preview fact needed for shared live reuse, and did not broaden into replay. `REF-01` and `REF-02` remain aligned at the cross-repo coordination level.

**Commits:**
- `49ddb53` - Harden shared live preview attachment semantics

**Lessons Learned:** The real live parity gap was attachment ownership semantics, not backend startup. Once a downstream lane can borrow the same live service, a truthful stack model plus explicit public attachment count is the narrow seam that keeps preview ownership honest without pushing state/detail ownership into consumer repos.

---

*Prepared on 2026-05-22*
