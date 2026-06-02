# AeroBeat Tool Camera Tracking — Live-Camera Integration Slice

**Date:** 2026-05-22  
**Status:** Stale  
**Agent:** Cookie 🍪

---

## Goal

Turn the existing `CameraTracking` contract shell into the first truthful tool-owned live-camera path by resolving a real vendor backend at runtime and surfacing vendor facts through the public tool contract without taking vendor-runtime ownership away from `aerobeat-vendor-mediapipe-python`.

---

## Overview

`aerobeat-tool-camera-tracking` is no longer blocked on a fake vendor seam. The paired vendor repo now owns a truthful bootstrap/probe lane: it can enumerate cameras, report runtime health, reject unsupported source kinds honestly, and expose a contract-facing backend class (`MediaPipePythonCameraTrackingBackend`) that already maps vendor bootstrap snapshots into the shared camera-tracking contract shape. The next real gap is now on the tool side: the public `CameraTracking` singleton still only works when a backend is manually injected, so the approved config-first ownership model is not yet real.

The narrowest honest Phase 2 slice is therefore **tool-owned backend registration/resolution for live camera only**. This repo should not preload or hard-depend on the vendor repo from sharable source because that would invert package ownership and risk a tool↔vendor cycle. Instead, the tool repo should add the public seam that lets runtime/product/test surfaces register a backend factory by backend ID, then let `CameraTracking` resolve and lifecycle-manage that backend while preserving tool ownership of preview attachment semantics, source coordination, and normalized tracking/public state.

This slice should stay deliberately narrow. It should prove `backend = mediapipe_python` with `source.kind = live_camera` can flow through the real vendor bootstrap/probe path and back through the tool singleton with truthful `running` / error state, camera inventory, preview descriptor facts, and normalized frame/default-frame behavior. It should **not** claim replay/video-file support, long-lived tracking inference, or consumer migrations. Those remain later phases.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Locked platform phase order and ownership boundaries | `/workspace/projects/openclaw-cookie/.plans/aerobeat-architecture/IMPLEMENTATION-PHASES.md` |
| `REF-02` | Prior tool-side contract-shell plan | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.plans/2026-05-21-contract-shell-slice.md` |
| `REF-03` | Approved camera-tracking API sketch | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.plans/bootstrap-architecture/CAMERA-TRACKING-API.md` |
| `REF-04` | Completed truthful vendor runtime slice plan | `/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/.plans/2026-05-22-first-truthful-runtime-slice.md` |
| `REF-05` | Current tool singleton shell implementation that still requires manual backend injection | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTracking.gd` |
| `REF-06` | Current tool backend interface seam | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTrackingBackend.gd` |
| `REF-07` | Current vendor backend implementation that already targets the tool contract | `/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/src/MediaPipePythonCameraTrackingBackend.gd` |
| `REF-08` | Current truthful vendor runtime bridge behavior | `/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/src/MediaPipePythonRuntimeBridge.gd` |
| `REF-09` | Current vendor runtime probe entrypoint and deterministic camera-root override path | `/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/runtime/mediapipe_runtime_probe.py` |
| `REF-10` | Current input migration plan and remaining upstream dependency list | `/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.plans/2026-05-21-input-camera-tracking-contract-migration.md` |

Use these references during implementation and audit instead of hand-waving the current seam truth.

---

## Slice Boundaries

### In scope for this slice

- Add a tool-owned backend registration / resolution seam keyed by public backend ID.
- Allow `CameraTracking` to resolve the configured backend truthfully for `backend = mediapipe_python` without requiring the caller to manually call `set_backend()` first.
- Preserve preview attachment ownership in the tool singleton while passing truthful preview descriptor facts through from the resolved backend.
- Prove the real vendor bootstrap/probe path through the tool boundary for `source.kind = live_camera`.
- Surface truthful camera inventory, runtime-driven `running` / error state, and normalized tracking-frame/default-frame behavior through the tool contract.
- Add repo-local tests and `.testbed` proving wiring that install the vendor package as a dependency and register the backend factory there without editing addon mirrors.

### Explicitly out of scope for this slice

- Replay / `source.kind = video_file` support beyond honest rejection.
- Long-lived MediaPipe inference or landmark streaming.
- Consumer migration work in `aerobeat-input-camera-tracking` or other downstream repos.
- Moving vendor runtime/bootstrap/config/camera/health ownership into this repo.
- Creating a tool-root preload cycle from `aerobeat-tool-camera-tracking` directly into `aerobeat-vendor-mediapipe-python` sharable source.

### Expected boundary after this slice

- Product/test code can register a `mediapipe_python` backend factory with the tool layer.
- `CameraTracking.start(config)` can resolve that backend from config, drive the real vendor bootstrap/probe path for `live_camera`, and expose truthful state/cameras/preview/default-frame facts through the public tool API.
- Unsupported `video_file` use still fails honestly because replay is not part of this slice.
- `aerobeat-input-camera-tracking` is unblocked for the next migration work that depends on a stable, truthful live-camera tool path, but remains blocked on replay semantics and final frame/coordinate details listed below.

---

## Ownership Decisions Captured Here

### `aerobeat-tool-camera-tracking` owns

- `CameraTracking` singleton lifecycle semantics and state machine truth
- backend registration/resolution policy at the public tool boundary
- preview attachment semantics (`attach_preview_surface(node)` / `detach_preview_surface()`)
- source coordination and public source-mode truth
- normalized tracking-frame/default-frame contract presented to consumers
- public errors when no backend is registered or a configured backend cannot be resolved

### `aerobeat-vendor-mediapipe-python` owns

- concrete `mediapipe_python` backend implementation
- runtime bootstrap/probe process orchestration
- vendor config translation and runtime entrypoint wiring
- camera enumeration, runtime-health facts, and vendor-specific error translation
- raw vendor frame payload mapping before it reaches the tool-owned normalized contract

### Not creating in this slice

- direct tool-root preload/import of vendor classes in sharable source
- replay lifecycle work
- consumer-facing migration inside input repos

---

## Remaining `aerobeat-input-camera-tracking` Blockers After This Slice

This slice should remove the biggest live-camera blocker: the tool repo will finally own a truthful config-first live-camera runtime path instead of a shell that only works with manual backend injection. But these blockers still remain for `aerobeat-input-camera-tracking` after this tool slice lands:

1. **Final normalized tracking-frame payload guarantees** (`REF-03`, `REF-10`)
   - landmark optionality vs guarantees in v1
   - final `tracking_state` enum semantics once real inference exists
   - whether any velocity/skeleton/body-part confidence fields are guaranteed beyond empty/default values in the bootstrap/probe era

2. **Coordinate-space truth under real tracking output** (`REF-03`, `REF-10`)
   - mirrored-vs-gameplay orientation contract once non-empty frames are emitted
   - exact consumer expectations for `preview_transform.flip_horizontal` beyond default stub behavior

3. **Replay / `video_file` semantics** (`REF-01`, `REF-03`, `REF-10`)
   - `aerobeat-input-camera-tracking` proving flows that depend on prerecorded clips still need the later replay/tool-video-player phase

4. **Final consumer/runtime registration pattern** (`REF-10`)
   - consumers will need the stable addon/package/runtime path for registering or receiving the concrete backend in product bootstraps, even if repo-local proving can register it directly in `.testbed`

5. **Real tracking inference availability** (`REF-04`, `REF-10`)
   - the vendor repo still truthfully exposes bootstrap/probe only, so downstream gameplay consumers should not yet assume non-empty live landmarks from the new live-camera path

---

## Candidate Repo Surfaces

Expected owned implementation surfaces for this slice likely include:

- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTracking.gd`
- a new repo-root backend registration/factory helper under `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTrackingConfig.gd` if backend-resolution defaults/errors need tightening
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.testbed/addons.jsonc`
- repo-local tests under `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.testbed/tests/`
- `README.md` if the repo truth statement needs to evolve from shell-only to first truthful live-camera integration

Exact file layout is up to the coder as long as repo-root sharable source stays the ownership surface and `.testbed/` remains only the proving surface.

---

## Tasks

### Task 1: Implement tool-owned live-camera backend registration and vendor path

**Bead ID:** `atct-e77`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`, `REF-09`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking`, claim bead `atct-e77` with `bd update atct-e77 --status in_progress --json` when you start. Implement the narrowest honest Phase 2 live-camera slice described in `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.plans/2026-05-22-live-camera-integration-slice.md`. Required scope: add tool-owned backend registration/resolution so `CameraTracking` can resolve `backend = mediapipe_python` from config without a sharable-source package-cycle preload; preserve tool ownership of lifecycle, preview attachment, source coordination, and normalized tracking/public state; prove the real `aerobeat-vendor-mediapipe-python` bootstrap/probe path through the tool boundary for `source.kind = live_camera`; and add/adjust repo-local tests/docs only as needed. Keep sharable work at repo root, use `.testbed/` as the proving surface, and do not edit `.testbed/addons/` or other addon mirrors as owned source. Validation should include repo-local import/tests plus a proving path that exercises truthful startup/list/change/error behavior through the real vendor backend/runtime probe lane. Do not broaden into replay/video-file support or consumer migration. Leave downstream beads open.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.testbed/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.testbed/tests/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTracking.gd`
- new repo-root backend registration/factory helper(s) under `src/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTrackingConfig.gd` only if needed
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.testbed/addons.jsonc`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.testbed/tests/*`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/README.md` only if the repo truth statement changes

**Status:** ✅ Complete

**Results:** Claimed `atct-e77` with `bd update atct-e77 --status in_progress --json`. Added repo-root backend registration/resolution via new `src/CameraTrackingBackendRegistry.gd` plus `CameraTracking` static factory helpers and config-first backend resolution logic, while preserving manual `set_backend()` injection for existing callers. `src/CameraTracking.gd` now resolves `backend = mediapipe_python` from config without a repo-root vendor preload, treats unregistered/factory-failed backends honestly, keeps tool ownership of lifecycle/state machine transitions, and preserves tool-owned preview attachment facts even when vendor preview descriptors report detached state. Tightened normalized default-frame truth in `src/CameraTrackingFrame.gd` so `source_id` follows the truthful active source mode, and adjusted `src/CameraTrackingPreview.gd` so backend facts cannot overwrite tool-owned attachment/surface-path semantics.

Repair follow-up for this reopened bead: removed the tracked `.testbed/addons/aerobeat-tool-camera-tracking/src/*.gd` shim files that had incorrectly put tool source under the proving mirror. Replaced that with a tiny repo-owned helper at `scripts/prepare_testbed.sh` which recreates **untracked local shim files** under `.testbed/addons/aerobeat-tool-camera-tracking/src/` after `godotenv addons install`. Each shim is just `extends "res://src/..."`, which keeps the proving/runtime path truthful for installed vendor packages while returning sharable source ownership to repo-root `src/` only. Updated `.gitignore`, `README.md`, and CI so the overlay is prepared as part of the documented validation flow instead of being tracked in git.

Validation run from the repo root after the repair:
- `cd .testbed && godotenv addons install && cd .. && ./scripts/prepare_testbed.sh` ✅ installed `aerobeat-tool-core`, `aerobeat-vendor-mediapipe-python`, and `gut`, then prepared untracked shim files in `.testbed/addons/aerobeat-tool-camera-tracking/src/`
- `godot --headless --path .testbed --import` ✅ completed successfully; emitted the known non-fatal `ObjectDB instances leaked at exit` warning after import
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ 9/9 tests passed
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` covers the live-camera proving flow directly in repo-owned tests, including startup, camera enumeration, preview/default-frame facts, restart/change behavior, and honest `video_file` rejection through the real vendor backend/runtime probe lane

Boundary notes for QA/audit: no tracked source remains under `.testbed/addons/aerobeat-tool-camera-tracking` or `.testbed/.addons`. The vendor addon still compiles against the live repo-root contract files during proving because the overlay path is created locally at validation time, not committed as owned source. Replay/video-file support, long-lived inference, and non-empty final tracking frames remain explicitly out of scope.

---

### Task 2: QA the live-camera tool/vendor integration slice

**Bead ID:** `atct-21l`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-03`, `REF-04`, `REF-05`, `REF-07`, `REF-08`, `REF-09`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking`, wait until bead `atct-21l` is unblocked, then claim it with `bd update atct-21l --status in_progress --json`. Verify the live-camera integration slice using the highest-fidelity repo-local validation available. At minimum: confirm the tool-owned backend registration/resolution path can start the real `mediapipe_python` vendor backend through the runtime probe lane; rerun the repo-local import/tests; exercise camera enumeration, truthful running/error state, preview descriptor facts, and normalized empty/default-frame truth through the tool contract; verify unsupported source kinds fail honestly; and confirm no addon mirrors were treated as owned source. Record exact commands, results, and gaps. Do not close the auditor bead.

**Folders Created/Deleted/Modified:**
- validation-only use of `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.testbed/`

**Files Created/Deleted/Modified:**
- none required; used and removed one temporary untracked headless smoke script under `.testbed/` during verification

**Status:** ✅ Complete

**Results:** Claimed `atct-21l` with `bd update atct-21l --status in_progress --json` and independently re-verified the repaired slice from the repo root using the highest-fidelity repo-local proving path available.

Exact QA commands/results:
- `git ls-files .testbed/addons .testbed/.addons` → no tracked files under addon mirrors; `git status --short` only showed pre-existing untracked plan paths outside this QA slice.
- `rm -rf .testbed/addons/aerobeat-tool-camera-tracking/src && cd .testbed && godotenv addons install && cd .. && ./scripts/prepare_testbed.sh` ✅ reinstalled testbed addons and re-created the local overlay shim package. Verified the generated `.testbed/addons/aerobeat-tool-camera-tracking/src/*.gd` files are untracked and that `.testbed/.addons/aerobeat-tool-camera-tracking` does not exist.
- `godot --headless --path .testbed --import` ✅ import succeeded. Observed non-fatal warnings only: several vendor `.uid` files were regenerated from cache and Godot emitted `ObjectDB instances leaked at exit` on shutdown.
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ 9/9 tests passed.
- Standalone smoke verification via a temporary untracked headless script under `.testbed/` that registered `mediapipe_python` through `CameraTracking.register_backend_factory(...)`, constructed `MediaPipePythonCameraTrackingBackend` + `MediaPipePythonRuntimeBridge`, and exercised the real tool → vendor runtime-probe lane with fixture cameras rooted at `user://qa-live-camera-fixture`:
  - live-camera start returned `state=running` with detail `{backend_ready:true, preview_ready:true, source_ready:true, tracking_ready:false}`
  - camera inventory returned two truthful `live_camera` entries (`video0`, `video2`) with vendor metadata `probe_mode=filesystem_glob`
  - preview descriptor stayed tool-owned and truthful: `{attached:true, backend:"mediapipe_python", surface_path:"PreviewSlot", flip_horizontal:false}`
  - normalized default frame stayed truthful and empty/default as expected for the current bootstrap/probe-only slice: `backend="mediapipe_python"`, `source_kind="live_camera"`, `source_id=<selected camera path>`, `tracking_state="idle"`, `frame_size={x:0,y:0}`, empty landmarks/skeleton
  - changing to unsupported `source.kind = video_file` failed honestly with `state=error` and `last_error.code="unsupported_source_kind"`; the normalized frame also truthfully switched to `source_kind="video_file"` and `source_id="res://clips/demo.mp4"`
- Ownership-boundary spot check: `grep -RIn "addons/aerobeat-vendor-mediapipe-python\|MediaPipePython" src` → no vendor preload/import references in repo-root sharable source; vendor-specific references remain in proving/tests only.

QA conclusion: pass. The repaired `scripts/prepare_testbed.sh` flow is truthful and sufficient for proving, import/test coverage passes, the real vendor runtime probe lane starts through the tool-owned backend registry path, unsupported `video_file` still fails honestly, and sharable source ownership remains at repo root rather than inside `.testbed/addons` / `.testbed/.addons`. Non-blocking gap noted for audit context only: import still emits vendor `.uid` regeneration warnings plus the known `ObjectDB instances leaked at exit` warning, but neither prevented import or test success.

---

### Task 3: Audit the live-camera tool/vendor integration slice

**Bead ID:** `atct-57m`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`, `REF-09`, `REF-10`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking`, wait until bead `atct-57m` is unblocked, then claim it with `bd update atct-57m --status in_progress --json`. Independently audit the finished live-camera integration slice against this plan, the repo diff, coder evidence, QA evidence, and the ownership boundaries recorded here. Verify tool-camera-tracking still owns lifecycle, preview attachment semantics, source coordination, and normalized tracking/public contract truth; verify vendor-mediapipe-python only contributes vendor runtime/bootstrap/config/camera/health behavior; verify the slice is honestly limited to `live_camera` and does not pretend replay/full tracking inference or consumer migration is complete; and verify no addon mirrors were treated as owned source. If the slice passes, close bead `atct-57m` with an honest reason; if not, report the exact gap and keep the lane active.

**Folders Created/Deleted/Modified:**
- none required

**Files Created/Deleted/Modified:**
- none required unless a minimal audit artifact becomes necessary

**Status:** ✅ Complete

**Results:** Claimed `atct-57m` with `bd update atct-57m --status in_progress --json` and independently audited the repaired slice against the repo-local plan, commit `ebc60ac69ae58177c8cdce73ee51d49faad1fdf0`, current repo source, and QA evidence.

Exact audit commands/results:
- `git ls-files .testbed/addons/aerobeat-tool-camera-tracking .testbed/.addons/aerobeat-tool-camera-tracking` → no tracked files under either addon-mirror path for this repo, confirming the tracked shim source was removed.
- `git show --stat --patch ebc60ac69ae58177c8cdce73ee51d49faad1fdf0 -- scripts/prepare_testbed.sh README.md .gitignore .github/workflows/gut_ci.yml ...` → confirmed the repair commit only removed the tracked `.gitignore` exemptions, added the repo-owned `scripts/prepare_testbed.sh` helper, documented the proving flow in `README.md`, and wired CI to run the helper before import/tests.
- Read/spot-checked `scripts/prepare_testbed.sh`, `src/CameraTracking.gd`, `src/CameraTrackingBackendRegistry.gd`, `src/CameraTrackingPreview.gd`, and `src/CameraTrackingFrame.gd` → confirmed the helper only writes one-line local shims (`extends "res://src/<name>.gd"`) while the repo-root `src/` files still own backend registry/resolution, lifecycle/state transitions, preview attachment semantics, and normalized default-frame truth.
- `grep -RIn "MediaPipePython\|aerobeat-vendor-mediapipe-python" src` → no vendor-specific preload/import coupling in repo-root sharable source.
- `rm -rf .testbed/addons/aerobeat-tool-camera-tracking/src && cd .testbed && godotenv addons install && cd .. && ./scripts/prepare_testbed.sh` ✅ reinstall + overlay regeneration succeeded. The helper produced only local shim files under `.testbed/addons/aerobeat-tool-camera-tracking/src/`.
- `godot --headless --path .testbed --import` ✅ succeeded; observed only non-blocking vendor `.uid` regeneration warnings plus the known `ObjectDB instances leaked at exit` warning.
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ 9/9 tests passed.
- Temporary untracked smoke script `audit_live_camera_smoke.gd` under `.testbed/` registered the real vendor backend via `CameraTracking.register_backend_factory(...)` and exercised the real tool → vendor runtime-probe lane. Results:
  - live start returned `state=running` with detail `{backend_ready:true, preview_ready:true, source_ready:true, tracking_ready:false}`
  - camera inventory returned two truthful `live_camera` entries with `probe_mode=filesystem_glob`
  - preview descriptor stayed tool-owned and truthful: `{attached:true, backend:"mediapipe_python", surface_path:"PreviewSlot", flip_horizontal:false}`
  - normalized default frame stayed empty/default but truthful for the current bootstrap/probe-only slice: `backend="mediapipe_python"`, `source_kind="live_camera"`, `source_id=<selected fixture camera>`, `tracking_state="idle"`, zero `frame_size`, empty landmarks/skeleton
  - changing to unsupported `source.kind = video_file` failed honestly with `state=error`, `last_error.code="unsupported_source_kind"`, and normalized frame truthfully switched to `source_kind="video_file"` + `source_id="res://clips/demo.mp4"`

Audit conclusion: pass. The repaired slice is truly complete for the planned scope. No tracked source remains under `.testbed/addons` or `.testbed/.addons` for this repo; `scripts/prepare_testbed.sh` is truthful proving glue rather than hidden owned source; the tool repo still owns backend registration/resolution and public lifecycle/state/preview/normalized contract behavior; vendor-specific implementation details do not leak into repo-root sharable source; the real vendor runtime-probe lane starts truthfully for `live_camera`; and unsupported `video_file` use still fails honestly instead of pretending replay support exists. Remaining non-blocking warnings are limited to vendor `.uid` regeneration and the known `ObjectDB instances leaked at exit` message during headless import/shutdown.

---

## Dependency Shape

- `atct-e77` → first executable implementation bead
- `atct-21l` depends on `atct-e77`
- `atct-57m` depends on `atct-21l`

This enforces the serialized coder → QA → auditor lane in the owning repo.

---

## Final Results

**Status:** ✅ Complete

**What We Built:** Landed and independently audited the repo-root backend registration/resolution seam plus the first truthful `aerobeat-tool-camera-tracking` live-camera integration proof against the real `aerobeat-vendor-mediapipe-python` runtime probe lane. The repair commit also restored honest source ownership by removing tracked addon-mirror shims and replacing them with a local proving-only overlay helper.

**Reference Check:** `REF-01` remains honored because the slice stays locked to `live_camera` only and still rejects `video_file` honestly. `REF-02`, `REF-03`, `REF-05`, and `REF-06` remain intact because lifecycle, preview attachment semantics, source coordination, backend resolution, and normalized public tracking-frame truth still live in this repo. `REF-04`, `REF-07`, `REF-08`, and `REF-09` are now exercised through the tool boundary rather than only inside the vendor repo. `REF-10` is satisfied for the planned scope because the proving surface demonstrates truthful startup/list/change/error behavior without claiming replay, long-lived inference, or consumer migration.

**Commits:**
- `ebc60ac69ae58177c8cdce73ee51d49faad1fdf0` - Repair testbed camera-tracking overlay ownership

**Lessons Learned:**
- The critical enabling move was a tool-owned backend-factory seam, not another vendor singleton or a repo-root vendor preload.
- A tiny `.testbed` shim package is enough to let the installed vendor addon compile against the live local tool source without treating addon mirrors as owned sharable source.
- The normalized default-frame contract needs to key off the truthful active source mode, even when the runtime rejects that mode.

---

*Prepared on 2026-05-22*
