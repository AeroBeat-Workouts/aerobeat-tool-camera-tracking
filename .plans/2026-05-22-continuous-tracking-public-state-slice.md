# AeroBeat Tool Camera Tracking — Continuous Tracking Public State Slice

**Date:** 2026-05-22  
**Status:** Draft  
**Agent:** Cookie 🍪

---

## Goal

Upgrade `aerobeat-tool-camera-tracking` from truthful sampled public landmark snapshots into the first truthful **continuous public tracking lane** that keeps `CameraTracking` updated over time while preserving tool ownership of lifecycle/state/preview/source coordination and the normalized public frame contract.

---

## Overview

The tool repo already proved two important boundaries. First, it owns the public `CameraTracking` service, not the vendor repo. Second, it can normalize the paired vendor sampled landmark payload into a truthful public frame with minimal landmark fields `id/x/y/z/v`. But the current public truth is still snapshot-shaped: a successful `start()` or `change()` can produce one public frame, then nothing else happens unless the runtime is restarted.

Once the paired vendor continuous-runtime slice lands, the next honest tool move is not to broaden the schema. It is to define and verify how continuous vendor updates map into the existing public service. This repo should stay responsible for lifecycle/source/preview/state coordination and the normalized frame/state contract, while consuming repeated vendor updates through the backend seam and making the public guarantees stronger only where time-based truth is now actually proven.

This slice remains intentionally narrower than replay and narrower than downstream consumer migration. Even after it lands, the public contract should still avoid overclaiming `reacquiring`, multi-pose, skeleton, or richer body/head semantics.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Coordination plan for the continuous-tracking wave | `/workspace/projects/openclaw-cookie/.plans/aerobeat-architecture/2026-05-22-continuous-tracking-slice.md` |
| `REF-02` | Completed sampled public landmark slice | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.plans/2026-05-22-minimal-real-landmark-normalization-slice.md` |
| `REF-03` | Current public service singleton | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTracking.gd` |
| `REF-04` | Current public frame normalization surface | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTrackingFrame.gd` |
| `REF-05` | Current backend interface seam | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTrackingBackend.gd` |
| `REF-06` | Current preview ownership helper | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTrackingPreview.gd` |
| `REF-07` | Paired vendor continuous runtime slice plan | `/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/.plans/2026-05-22-continuous-tracking-runtime-slice.md` |
| `REF-08` | Current downstream input adapter assumptions | `/workspace/projects/aerobeat/aerobeat-input-camera-tracking/src/tracking_frame_adapter.gd` |
| `REF-09` | Current downstream camera-tracking provider | `/workspace/projects/aerobeat/aerobeat-input-camera-tracking/src/providers/camera_tracking_provider.gd` |
| `REF-10` | Current camera-tracking API contract notes | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.plans/bootstrap-architecture/CAMERA-TRACKING-API.md` |

---

## Slice Boundaries

### In scope for this slice

- Consume repeated vendor runtime updates through the existing backend/service seam after a successful `live_camera` start.
- Keep `CameraTracking` as the owner of public lifecycle/source/preview/state coordination while stronger continuous truth becomes available underneath it.
- Strengthen the public meaning of `detail.tracking_ready`, `get_tracking_frame()`, and repeated `tracking_updated` emissions for a continuous live session.
- Preserve the existing public landmark schema (`id/x/y/z/v`) and sampled public field limits while allowing repeated frames to arrive over time.
- Document and test which public guarantees are now stronger because the runtime is continuous, versus which temporal semantics remain provisional.

### Explicitly out of scope for this slice

- Replay / `video_file` support.
- Public `reacquiring` / `lost` semantics beyond honest deferral.
- New landmark/body/head fields.
- Multi-pose guarantees.
- Downstream `aerobeat-input-camera-tracking` migration work.

---

## Ownership Decisions Captured Here

### `aerobeat-tool-camera-tracking` owns in this slice

- the public meaning of `CameraTracking` lifecycle/state/detail behavior
- the public meaning of `tracking_updated` over time
- the normalized public frame contract and public landmark schema
- source/preview coordination behavior while the runtime stays alive
- documentation of stronger-vs-provisional public guarantees for downstream consumers

### `aerobeat-tool-camera-tracking` does **not** own in this slice

- MediaPipe runtime session/process management internals
- raw capture cadence or raw inference cadence
- vendor runtime health/model/import failure implementation details
- replay or prerecorded source semantics
- downstream detector migration

---

## Proposed Stronger Public Guarantees After This Slice

If this slice lands successfully on top of the paired vendor runtime slice, this repo should be able to guarantee all of the following for `backend = mediapipe_python` + `source.kind = live_camera`:

1. `CameraTracking.start()` can lead to a public `running` session that keeps receiving `tracking_updated` frames over time rather than only one startup snapshot.
2. `get_tracking_frame()` returns the latest normalized public frame from that running session.
3. `tracking_updated` may fire repeatedly while the service remains in `running` state.
4. `detail.tracking_ready = true` now means the underlying continuous tracking lane is actively delivering a live session, not merely that one startup snapshot succeeded.
5. Public per-frame shape remains minimal and stable:
   - top-level: `timestamp_ms`, `backend`, `source_kind`, `source_id`, `tracking_state`, `frame_size`, `preview_transform`, `landmarks`, plus existing default-only fields
   - landmarks only `id`, `x`, `y`, `z`, `v`
6. Public `tracking_state` remains frame-level truth only:
   - `tracked` when the current normalized frame has landmarks
   - `idle` when the current normalized frame does not
7. `preview_transform.flip_horizontal` and `preview_transform.space = gameplay_normalized` remain tool-owned truth across repeated updates.

---

## Still Provisional / Intentionally Deferred After This Slice

Even after this slice lands, these public semantics remain provisional or default-only:

- `reacquiring` / `lost` meaning across time
- any guarantee that every update contains a pose
- non-zero aggregate `confidence` meaning
- `head_position`, `head_velocity`, `head_orientation`
- `skeleton`
- multi-pose semantics
- richer physical meaning/scale guarantees for landmark `z`
- replay / prerecorded source coordination

Important nuance: `detail.tracking_ready` can become true for an active continuous lane while the latest public frame still has `tracking_state = idle`. Session-alive truth and current-pose-detected truth are different guarantees.

---

## What Still Blocks Honest Downstream Consumption Even If This Lands

Even after this tool slice lands, honest `aerobeat-input-camera-tracking` consumption is still blocked by:

1. **No public `reacquiring` semantics yet**
   - `TrackingFrameAdapter.tracking_state_is_active()` already recognizes `reacquiring`, but this wave still does not define or prove it.

2. **No downstream migration execution yet**
   - the input repo still needs its own coder → QA → auditor execution wave against the stronger continuous contract.

3. **No replay / `video_file` contract yet**
   - prerecorded proving flows remain deferred.

4. **No gameplay-grade temporal audit yet**
   - this slice will prove continuous service/frame truth, not full Boxing + Flow gameplay correctness under sustained tracking.

---

## Tasks

### Task 1: Implement tool continuous tracking public state slice

**Bead ID:** `atct-2tq`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`, `REF-09`, `REF-10`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking`, claim bead `atct-2tq` with `bd update atct-2tq --status in_progress --json` when you start. Implement the narrowest honest continuous public tracking slice described in `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.plans/2026-05-22-continuous-tracking-public-state-slice.md`. Required scope: consume repeated vendor updates after a successful `live_camera` start; keep `CameraTracking` as the owner of public lifecycle/state/source/preview coordination; strengthen the public meaning of repeated `tracking_updated` frames, `get_tracking_frame()`, and `detail.tracking_ready` for a continuous live session; preserve the existing public frame/landmark schema (`id/x/y/z/v`) and default-only richer fields; update repo-local tests/docs only as needed; do not broaden into replay, `reacquiring` semantics, new body/head fields, or downstream input migration.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.testbed/tests/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTracking.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTrackingFrame.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.testbed/tests/test_CameraTracking.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/README.md`

**Status:** ✅ Complete

**Results:** Claimed `atct-2tq` with `bd update atct-2tq --status in_progress --json` and implemented the narrow tool-owned continuous public-state slice without broadening the contract. `src/CameraTracking.gd` now refreshes backend state/frame/preview/cameras while the service remains `running`, updates getter reads from the live backend seam, and emits repeated public events only when those public facts actually change over time. This keeps lifecycle/source/preview ownership in the tool repo while consuming repeated vendor updates through the existing backend boundary.

`src/CameraTrackingFrame.gd` now keeps frame-level public truth conservative: normalized public `tracking_state` resolves only to `tracked` when the current normalized frame has public landmarks and otherwise to `idle`, even if a backend/vendor payload names a richer temporal state. That preserves the locked-scope promise not to overclaim final `reacquiring` / loss semantics yet.

Repo-local proving stayed in sharable repo-root code plus `.testbed/` tests only. `.testbed/tests/test_CameraTracking.gd` now includes a deterministic continuous-backend proving case that demonstrates `CameraTracking` staying `running`, receiving repeated frame updates over time, exposing the latest normalized frame through `get_tracking_frame()`, keeping `detail.tracking_ready = true` for an active continuous lane while an intermediate public frame is still `idle`, and preserving the minimal landmark/default-only richer-field contract. `README.md` was updated to document which public guarantees are now stronger versus still intentionally conservative.

Validation run in this repo:
- `./scripts/prepare_testbed.sh && godot --headless --path .testbed --import` ✅
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ (`13/13` tests passed)

---

### Task 2: QA tool continuous tracking public state slice

**Bead ID:** `atct-cuy`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-03`, `REF-04`, `REF-05`, `REF-07`, `REF-08`, `REF-09`, `REF-10`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking`, wait until bead `atct-cuy` is unblocked, then claim it with `bd update atct-cuy --status in_progress --json`. QA the continuous public tracking slice from `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.plans/2026-05-22-continuous-tracking-public-state-slice.md`. At minimum: prove `CameraTracking` now receives repeated `tracking_updated` frames over time from the live vendor lane; prove `get_tracking_frame()` advances to the latest normalized frame without restart; prove `detail.tracking_ready` truthfully reflects an active continuous lane while frame-level `tracking_state` can still toggle between `tracked` and `idle`; verify the public landmark shape stays `id/x/y/z/v`; verify richer fields stay default/empty; verify unsupported `video_file` still fails honestly; and confirm addon mirrors were not treated as owned source. Record exact commands/results/gaps and leave the auditor bead open.

**Folders Created/Deleted/Modified:**
- validation-only use of `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.testbed/`

**Files Created/Deleted/Modified:**
- none required unless a minimal QA artifact becomes necessary

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 3: Audit tool continuous tracking public state slice

**Bead ID:** `atct-5r8`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`, `REF-09`, `REF-10`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking`, wait until bead `atct-5r8` is unblocked, then claim it with `bd update atct-5r8 --status in_progress --json`. Independently audit the continuous public tracking slice against this plan, the diff, coder evidence, and QA evidence. Verify the public service now truthfully represents a continuous live session rather than only a startup snapshot; verify public lifecycle/state/preview/source ownership remains in this repo; verify the public frame shape stayed conservative; and verify the downstream blocker notes remain honest. If the slice passes, close `atct-5r8` with an honest reason; if it fails, record the exact remaining gap without broadening scope.

**Folders Created/Deleted/Modified:**
- none required

**Files Created/Deleted/Modified:**
- none required unless a minimal audit artifact is necessary

**Status:** ⏳ Pending

**Results:** Pending.

---

## Dependency Shape

- `atct-2tq` → first executable implementation bead
- `atct-cuy` depends on `atct-2tq`
- `atct-5r8` depends on `atct-cuy`

Execution note: this tool slice should not begin until the paired vendor slice in `REF-07` is green, even though that cross-repo ordering is documented here rather than encoded as a repo-local dependency.

---

## Final Results

**Status:** ⚠️ Planned / ready for execution

**What We Built:** A repo-local execution plan plus serialized coder → QA → auditor beads for the first truthful continuous public tracking slice in `aerobeat-tool-camera-tracking`.

**Reference Check:** This plan keeps the ownership split strict: vendor runtime/session/inference/raw-update truth remains in the vendor repo, while this repo owns the public continuous state/detail/frame semantics that downstream consumers will actually observe.

**Commits:**
- Pending.

**Lessons Learned:** The honest tool-side upgrade is not “invent richer tracking semantics.” It is “make the current public service truly continuous, keep the contract conservative, and say exactly what got stronger versus what is still provisional.”

---

*Prepared on 2026-05-22*
