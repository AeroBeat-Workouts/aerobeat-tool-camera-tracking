# AeroBeat Tool Camera Tracking — Minimal Real Frame Normalization Slice

**Date:** 2026-05-22  
**Status:** Draft  
**Agent:** Cookie 🍪

---

## Goal

Upgrade the public `CameraTracking` live-camera contract from a truthful all-default frame to the first truthful **minimal real frame** by consuming vendor-supplied sampled-frame facts and normalizing only the fields that can be proven today.

---

## Overview

`aerobeat-tool-camera-tracking` already owns the public lifecycle/state/preview/source contract and now resolves the real `mediapipe_python` vendor backend through the registry seam. The remaining public payload gap is narrower than it was before: the vendor repo can truthfully boot, enumerate cameras, report health, and run the tool-owned live-camera path, but the public frame is still the all-default shell because the vendor runtime still emits an empty `raw_tracking_frame`.

Once the paired vendor slice lands, this repo should **not** invent a bigger contract than the vendor can prove. The narrowest honest tool-side move is to carry through the new vendor sample facts into the public normalized frame while preserving default values for everything not yet proven. That means this repo should own the public contract wording, mapping, and tests, but it should not start fabricating landmarks, skeletons, confidence semantics, or head-pose math.

This plan intentionally stops short of saying downstream gameplay consumers are ready. `aerobeat-input-camera-tracking` can only consume the result once the upstream frame includes active tracking-state semantics plus a useful landmark payload. This slice is still valuable because it turns the public frame from “default shell only” into “real sampled frame metadata with honest blanks elsewhere.”

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Current tool live-camera integration slice | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.plans/2026-05-22-live-camera-integration-slice.md` |
| `REF-02` | Current public default frame contract implementation | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTrackingFrame.gd` |
| `REF-03` | Current tool singleton that owns lifecycle/state/preview/source coordination | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTracking.gd` |
| `REF-04` | Current preview descriptor ownership helper | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTrackingPreview.gd` |
| `REF-05` | Paired vendor minimal-real-frame plan | `/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/.plans/2026-05-22-minimal-real-frame-slice.md` |
| `REF-06` | Current vendor frame mapper seam | `/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/src/MediaPipePythonFrameMapper.gd` |
| `REF-07` | Current input migration plan and downstream consumption blockers | `/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.plans/2026-05-21-input-camera-tracking-contract-migration.md` |
| `REF-08` | Current tracking-frame adapter that only becomes active once landmarks plus active tracking-state truth exist | `/workspace/projects/aerobeat/aerobeat-input-camera-tracking/src/tracking_frame_adapter.gd` |
| `REF-09` | Current minimal-real-frame coordination plan | `/workspace/projects/openclaw-cookie/.plans/aerobeat-architecture/2026-05-22-minimal-real-frame-slice.md` |

---

## Slice Boundaries

### In scope for this slice

- Consume the vendor repo’s new sampled-frame raw payload through the existing backend seam.
- Preserve public ownership of normalized frame defaults while allowing truthful vendor sample facts to override the default shell.
- Document and test which public frame fields are now guaranteed versus still provisional/default-only.
- Keep `source.kind = live_camera` as the only supported successful path in this slice.

### Explicitly out of scope for this slice

- Replay / `video_file` support beyond honest failure.
- Landmark/body/skeleton inference.
- Broad consumer migration in `aerobeat-input-camera-tracking`.
- New public promises for confidence, head pose, or coordinate-space meaning beyond what already exists.

---

## Guaranteed vs Provisional Public Frame Truth After This Slice

### Guaranteed public fields after this slice

Assuming the paired vendor slice passes, this repo should guarantee these public frame facts for successful `live_camera` startup:

- `timestamp_ms` is from a real captured sample, not a hardcoded zero.
- `backend` is the resolved backend ID (`mediapipe_python` here).
- `source_kind` is the active public source mode.
- `source_id` is the selected live camera ID.
- `frame_size.x` and `frame_size.y` come from the real sampled frame.
- `preview_transform.flip_horizontal` continues to reflect the tool-owned/public preview config truth.
- `preview_transform.space` remains `gameplay_normalized`.
- the frame remains structurally complete even when richer tracking data is absent.

### Still provisional or intentionally default-only after this slice

- exact `tracking_state` semantics once real inference exists
- any non-zero `confidence` meaning
- `head_position`, `head_velocity`, `head_orientation`
- `landmarks`
- `skeleton`
- body-part confidence/schema expectations
- exact coordinate-space truth for real landmark payloads beyond the already locked `preview_transform.space` label

Important honesty rule: if the vendor slice only proves a sampled frame and no pose inference, this repo should preserve empty/default values for the richer fields instead of silently promoting them.

---

## Remaining Blockers Before `aerobeat-input-camera-tracking` Can Consume This Result

Even after this public-frame slice lands, these blockers remain for meaningful downstream gameplay consumption:

1. **Active tracking-state truth**
   - `TrackingFrameAdapter.tracking_state_is_active()` only treats `tracked` and `reacquiring` as active.
   - A truthful sampled-frame-only payload is likely to remain `idle`, so the input adapter should still treat it as non-consumable for gameplay.

2. **Landmark payload truth**
   - `aerobeat-input-camera-tracking` needs useful landmark arrays (`id/x/y/z/v`) before Boxing/Flow detectors can operate.
   - A non-empty frame with empty landmarks is transport progress, not gameplay readiness.

3. **Richer coordinate-space guarantees**
   - downstream detector logic still depends on landmark orientation/space truth once real landmarks appear.

4. **Replay semantics**
   - prerecorded proving flows remain blocked on later `video_file` / replay work.

---

## Tasks

### Task 1: Implement public normalization for the minimal real frame

**Bead ID:** `atct-o9m`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-09`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking`, claim bead `atct-o9m` with `bd update atct-o9m --status in_progress --json` when you start. Implement the narrowest honest public minimal-real-frame slice described in `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.plans/2026-05-22-minimal-real-frame-normalization-slice.md`. Required scope: consume the paired vendor sampled-frame payload and expose it through the tool-owned normalized frame contract; upgrade only the fields the vendor can actually prove today; preserve default values for landmarks/skeleton/head-pose/confidence semantics that are still unresolved; keep `live_camera` as the only successful path; and add/adjust repo-local tests/docs only as needed. Do not broaden into replay support, consumer migration, or fabricated tracking claims. Leave downstream beads open.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.testbed/tests/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTrackingFrame.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTracking.gd` only if state/frame synchronization changes are strictly needed
- repo-local tests under `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.testbed/tests/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/README.md` only if the public truth statement changes

**Status:** ✅ Complete

**Results:** Implemented the narrowest tool-owned public-frame normalization seam in repo-root source. `src/CameraTrackingFrame.gd` now exposes `normalize(frame, config)` so the public frame is always composed from the tool-owned default shell and only then overlaid with backend-provided facts. `src/CameraTracking.gd` now runs both backend sync-time and signal-time frames through that normalizer instead of trusting backend payloads wholesale. This preserves tool ownership of the lifecycle/source/preview/public-frame contract while allowing the paired vendor slice to populate only the minimal real sampled-frame facts it truly proved.

Repo-local proving was updated in `.testbed/tests/test_CameraTracking.gd` to pass fixture-backed sample-frame metadata through `AEROBEAT_CAMERA_SAMPLE_FIXTURES_JSON`, assert that successful `live_camera` startup/change now surface real `timestamp_ms` plus `frame_size.{x,y}` and selected `source_id`, and assert that richer fields (`confidence`, `landmarks`, `skeleton`, head/body semantics) stay at truthful defaults when the vendor payload does not provide them. `README.md` now documents that the public frame has minimal real sampled-frame facts while replay/video and richer inference remain deferred.

One integration wrinkle surfaced during validation: the hidden `.testbed` addon install was still on the pre-`027fbeb` vendor code and produced JSON parse failures from the older bridge path. Refreshing with `cd .testbed && godotenv addons install` brought the installed vendor addon up to the completed minimal-real-frame slice, after which import/tests passed cleanly.

Validation run from the repo root:
- `./scripts/prepare_testbed.sh` ✅ prepared local overlay shims
- `godot --headless --path .testbed --import` ✅ completed successfully; emitted the known non-fatal vendor `.uid` regeneration warnings and `ObjectDB instances leaked at exit` warning on shutdown
- `godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ❌ first run failed because `.testbed/addons/aerobeat-vendor-mediapipe-python` was still on stale pre-`027fbeb` install content (`Parse JSON failed ... got 'env'` from the old bridge path)
- `cd .testbed && godotenv addons install` ✅ refreshed installed addons, including the paired vendor repo
- `./scripts/prepare_testbed.sh && godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ `10/10` tests passed
- `godot --headless --path .testbed --import` ✅ reran successfully after addon refresh with the same non-fatal vendor `.uid` regeneration warnings and `ObjectDB instances leaked at exit` warning

References validated: `REF-01`, `REF-02`, `REF-03`, `REF-05`, `REF-06`, and `REF-09`. Downstream blockers in `REF-07`/`REF-08` remain intentionally unchanged because the frame still carries sampled metadata only, not active-tracking landmarks.

---

### Task 2: QA public normalization for the minimal real frame

**Bead ID:** `atct-91t`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-01`, `REF-02`, `REF-05`, `REF-06`, `REF-09`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking`, wait until bead `atct-91t` is unblocked, then claim it with `bd update atct-91t --status in_progress --json`. Verify the public minimal-real-frame slice using the highest-fidelity repo-local validation available. At minimum: prove successful `live_camera` startup now yields a public frame with real sample timestamp/source/frame-size facts instead of the all-default shell; verify the richer tracking fields remain honestly default/empty when not proven; verify unsupported `video_file` still fails honestly; and confirm addon mirrors were not treated as owned source. Record exact commands/results/gaps and leave the auditor bead open.

**Folders Created/Deleted/Modified:**
- validation-only use of `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.testbed/`

**Files Created/Deleted/Modified:**
- none required unless a minimal QA artifact is needed

**Status:** ⏳ Pending

**Results:** Pending.

---

### Task 3: Audit public normalization for the minimal real frame

**Bead ID:** `atct-5g2`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`, `REF-09`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking`, wait until bead `atct-5g2` is unblocked, then claim it with `bd update atct-5g2 --status in_progress --json`. Independently audit the public minimal-real-frame slice against this plan, the repo diff, coder evidence, and QA evidence. Verify the public frame now carries only truthful vendor-proven sample facts; verify default/empty richer fields are still preserved honestly; verify lifecycle/preview/source ownership remains in this repo; and verify the plan’s downstream blocker notes remain accurate. If the slice passes, close bead `atct-5g2` with an honest reason; if not, report the exact gap and keep the lane active.

**Folders Created/Deleted/Modified:**
- none required

**Files Created/Deleted/Modified:**
- none required unless a minimal audit artifact becomes necessary

**Status:** ⏳ Pending

**Results:** Pending.

---

## Dependency Shape

- `atct-o9m` → first executable implementation bead
- `atct-91t` depends on `atct-o9m`
- `atct-5g2` depends on `atct-91t`

Execution note: this tool slice should not begin until the paired vendor slice in `REF-05` finishes green, even though that cross-repo dependency is documented here rather than encoded in repo-local Beads.

---

## Final Results

**Status:** ⚠️ Coder complete / awaiting QA + audit

**What We Built:** The coder slice landed the first tool-owned public minimal-real-frame normalization seam. Successful `live_camera` startup/change now surface real sampled-frame metadata (`timestamp_ms`, source identity, `frame_size`) through the public `CameraTracking` frame contract while richer tracking fields remain default/empty unless a backend truly provides them.

**Reference Check:** The coder implementation preserves tool ownership from `REF-01` through `REF-04`, consumes the vendor truth expansion in `REF-05` and `REF-06`, and leaves the downstream blocker story in `REF-07`, `REF-08`, and `REF-09` intentionally unchanged.

**Commits:**
- Pending coder commit.

**Lessons Learned:** The honest next public step is to normalize at the tool boundary instead of trusting backend payloads wholesale, and repo-local validation needs the installed testbed vendor addon refreshed whenever the paired vendor slice advances.

---

*Prepared on 2026-05-22*
