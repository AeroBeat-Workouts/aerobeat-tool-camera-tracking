# AeroBeat Tool Camera Tracking — Minimal Real Landmark Normalization Slice

**Date:** 2026-05-22  
**Status:** Stale  
**Agent:** Cookie 🍪

---

## Goal

Upgrade the public `CameraTracking` contract from truthful sampled-frame metadata into the first truthful **minimal real landmark frame** by normalizing vendor-supplied raw landmarks into the tool-owned public frame contract without overclaiming streaming/gameplay readiness.

---

## Overview

The completed minimal-real-frame normalization slice already proved the public ownership boundary: `CameraTracking` owns lifecycle/state/source/preview/public-frame truth, while the vendor repo only supplies the backend facts it can actually prove. The remaining gap is now spatial content. The upstream frame can carry real timestamp/source/frame-size metadata, but it still carries no landmark payload.

Once the paired vendor landmark slice lands, this repo should still avoid a broader claim than the vendor can support. The narrowest honest move is to take the vendor’s raw sampled-frame landmarks, normalize them into the public `CameraTracking` frame shape, and document exactly which public landmark semantics are guaranteed versus still provisional. That includes coordinate normalization that belongs here as part of the public contract, not in the vendor repo or the downstream input repo.

This slice intentionally stops short of declaring the full live-camera stack gameplay-ready. Even if the public frame now carries landmarks, the current upstream runtime is still sample-only (`startup` / `reconfigure` snapshots) rather than a continuous tracking stream. So this slice is about public contract truth, not about pretending downstream consumer migration is already done.

---

## REFERENCES

| ID | Description | Path |
| --- | --- | --- |
| `REF-01` | Completed tool minimal-real-frame normalization slice | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.plans/2026-05-22-minimal-real-frame-normalization-slice.md` |
| `REF-02` | Current public frame contract shell / normalizer | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTrackingFrame.gd` |
| `REF-03` | Current singleton that owns lifecycle/state/source/frame composition | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTracking.gd` |
| `REF-04` | Current preview ownership helper | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTrackingPreview.gd` |
| `REF-05` | Paired vendor minimal-real-landmark plan | `/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/.plans/2026-05-22-minimal-real-landmark-slice.md` |
| `REF-06` | Current vendor frame mapper seam | `/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/src/MediaPipePythonFrameMapper.gd` |
| `REF-07` | Current input tracking-frame adapter expectations | `/workspace/projects/aerobeat/aerobeat-input-camera-tracking/src/tracking_frame_adapter.gd` |
| `REF-08` | Current camera-tracking consumer provider using that adapter | `/workspace/projects/aerobeat/aerobeat-input-camera-tracking/src/providers/camera_tracking_provider.gd` |
| `REF-09` | Current input migration plan that remains downstream | `/workspace/projects/aerobeat/aerobeat-input-camera-tracking/.plans/2026-05-21-input-camera-tracking-contract-migration.md` |
| `REF-10` | Current camera-tracking API contract notes | `/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.plans/bootstrap-architecture/CAMERA-TRACKING-API.md` |

---

## Slice Boundaries

### In scope for this slice

- Consume the paired vendor repo’s new raw sampled-frame landmark payload through the existing backend seam.
- Preserve tool ownership of the public default shell while allowing truthful vendor landmark facts to override only the fields this repo is ready to guarantee.
- Normalize public landmarks into the shape downstream `TrackingFrameAdapter` already expects for the vendor-neutral seam.
- Keep support limited to `backend = mediapipe_python` + `source.kind = live_camera`.
- Document and test which public landmark fields/semantics are now guaranteed versus still provisional.

### Explicitly out of scope for this slice

- Replay / `video_file` support beyond honest failure.
- Streaming tracking updates or long-lived frame pumping.
- Consumer migration work inside `aerobeat-input-camera-tracking`.
- Multi-pose guarantees.
- Skeleton synthesis, head pose, or new non-zero confidence semantics.

---

## Ownership Decisions Captured Here

### `aerobeat-tool-camera-tracking` owns in this slice

- the public landmark schema exposed by `CameraTrackingFrame`
- mapping vendor/raw landmark fields into the public normalized contract
- gameplay-space coordinate normalization at the public contract boundary
- preserving tool-owned preview/source/lifecycle/default-frame truth around the new landmark payload
- documenting public guarantee language for downstream consumers

### `aerobeat-tool-camera-tracking` does **not** own in this slice

- MediaPipe runtime dependency truth
- raw camera capture or raw landmark extraction
- vendor inference configuration/health failures
- downstream detector/gameplay migration work

---

## Proposed Public Landmark Contract After This Slice

Assuming the paired vendor slice provides raw landmark entries shaped like `{id, x, y, z, visibility}`, this repo should expose a public normalized frame whose landmark entries are guaranteed to be shaped like:

```gdscript
{
  "id": <int>,
  "x": <float>,
  "y": <float>,
  "z": <float>,
  "v": <float>
}
```

Normalization rules owned here:

- `id` is preserved as the pose landmark ID.
- `x` / `y` are normalized into the public gameplay-space expectations used by downstream camera-tracking consumers.
- `z` is carried through as a numeric depth value, while its richer physical interpretation remains provisional.
- `v` is derived from the vendor/raw `visibility` field.
- `preview_transform.flip_horizontal` and `preview_transform.space = gameplay_normalized` remain tool-owned/public truth.

Important honesty rules:

- `tracking_state = "tracked"` is only appropriate when the paired vendor slice actually emitted landmarks for the sampled frame.
- `tracking_state = "idle"` remains honest when the sampled frame contains no detectable pose.
- `reacquiring` remains deferred because this stack still lacks a temporal stream.
- `confidence` should remain `0.0` unless this repo can define and prove its meaning.
- `skeleton`, `head_position`, `head_velocity`, and `head_orientation` remain default/empty.

---

## Guaranteed vs Provisional Public Truth After This Slice

### Guaranteed public fields after this slice

For successful `live_camera` startup/change in this repo:

- `timestamp_ms`, `backend`, `source_kind`, `source_id`, and `frame_size.{x,y}` remain truthful sampled-frame facts.
- `landmarks` is now a real public array field rather than an always-empty placeholder.
- when a landmark entry is emitted, it is guaranteed to include numeric `id`, `x`, `y`, `z`, and `v`.
- `tracking_state` may now truthfully be `tracked` on snapshot success when landmarks exist, otherwise `idle`.
- `preview_transform.flip_horizontal` remains driven by tool config truth.
- `preview_transform.space` remains `gameplay_normalized` and the tool-owned normalization point for downstream consumers.

### Still provisional / intentionally default-only after this slice

- continuous tracking semantics across time
- `reacquiring` / `lost` semantics
- non-zero aggregated `confidence` meaning
- `head_position`, `head_velocity`, `head_orientation`
- `skeleton`
- multi-pose support
- richer physical interpretation/scale guarantees for landmark `z`

Important nuance: a successful startup/change may still produce `landmarks = []` and `tracking_state = idle` if the sampled frame contained no detectable pose. The guaranteed improvement is the truthful landmark path and schema, not a promise that every camera sample contains a person.

---

## Remaining Blockers Before Honest `aerobeat-input-camera-tracking` Consumption

Even after this public-frame slice lands, these blockers remain for honest downstream gameplay consumption:

1. **Sample-only runtime path**
   - the current vendor/runtime stack still produces snapshot truth on `startup` / `reconfigure`, not a continuous tracking stream
   - `process_active=false` and `tracking_active=false` remain honest upstream, so gameplay consumers still lack continuous frame updates

2. **Consumer migration still unexecuted**
   - `aerobeat-input-camera-tracking` still needs its own coder → QA → auditor wave to consume the stronger contract

3. **Temporal tracking semantics still deferred**
   - `TrackingFrameAdapter.tracking_state_is_active()` can recognize `tracked`, but this slice still does not establish reacquisition/loss/stream semantics over time

4. **Replay / `video_file` remains deferred**
   - prerecorded proving flows remain blocked on later replay work

---

## Tasks

### Task 1: Implement public normalization for the minimal real landmark frame

**Bead ID:** `atct-9xa`  
**SubAgent:** `primary`  
**Role:** `coder`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`, `REF-10`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking`, claim bead `atct-9xa` with `bd update atct-9xa --status in_progress --json` when you start. Implement the narrowest honest public minimal-real-landmark slice described in `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.plans/2026-05-22-minimal-real-landmark-normalization-slice.md`. Required scope: consume the paired vendor raw landmark payload; normalize landmarks into the tool-owned public frame contract with guaranteed public landmark fields `id/x/y/z/v`; keep preview/source/lifecycle/public-frame ownership here; preserve default values for skeleton/head/confidence semantics that are still unresolved; keep `live_camera` as the only supported successful path; and add/adjust repo-local tests/docs only as needed. Do not broaden into streaming, replay support, or downstream consumer migration. Leave downstream beads open.

**Folders Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.testbed/tests/`

**Files Created/Deleted/Modified:**
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTrackingFrame.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTrackingFakeBackend.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.testbed/tests/test_CameraTracking.gd`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/README.md`

**Status:** ✅ Complete

**Results:** Implemented the narrowest honest tool-owned landmark normalization slice entirely in repo-root owned source. `src/CameraTrackingFrame.gd` now converts vendor/raw landmark entries into the public contract shape `id/x/y/z/v`, clamps `x`/`y` into normalized bounds, applies the tool-owned horizontal mirror normalization when `preview.flip_horizontal` is true, and only allows public `tracking_state = "tracked"` when at least one valid public landmark survives normalization. It intentionally keeps `confidence`, `head_position`, `head_velocity`, `head_orientation`, and `skeleton` at tool defaults instead of promoting richer backend fields that this slice does not honestly guarantee.

`src/CameraTrackingFakeBackend.gd` was tightened so repo-local fake tracked frames include one minimal landmark, keeping the proving backend aligned with the stricter public contract. `.testbed/tests/test_CameraTracking.gd` now proves three key truths: unproven rich fields stay default even if a backend tries to send them; raw vendor landmarks are normalized into public `id/x/y/z/v` entries with tool-owned flip/clamp behavior; and vendor-backed live-camera startup/change can now surface tracked-vs-idle snapshot truth depending on whether the sampled frame contains landmarks. `README.md` now documents the minimal-real-landmark public contract boundary and the still-deferred semantics.

Validation run from the repo root:
- `./scripts/prepare_testbed.sh && godot --headless --path .testbed --import && godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ❌ first run failed (`10/12` tests) because the hidden `.testbed/addons/aerobeat-vendor-mediapipe-python` install was stale and still returned the pre-landmark payload
- `cd .testbed && godotenv addons install && cd .. && ./scripts/prepare_testbed.sh && godot --headless --path .testbed --import && godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ passed after refreshing installed addons (`12/12` tests, `104` asserts)

Coder-slice public truth after this implementation:
- truly non-empty/proven when the sampled frame yields landmarks: `timestamp_ms`, `backend`, `source_kind`, `source_id`, `frame_size.{x,y}`, `tracking_state = tracked`, `preview_transform.flip_horizontal`, `preview_transform.space = gameplay_normalized`, and `landmarks[].id/x/y/z/v`
- still honest defaults/provisional after this slice: `confidence = 0.0`, `head_position`, `head_velocity`, `head_orientation` at zero/default identity, `skeleton = {}`, and any continuous/reacquiring/gameplay-readiness semantics

---

### Task 2: QA public normalization for the minimal real landmark frame

**Bead ID:** `atct-4nm`  
**SubAgent:** `primary`  
**Role:** `qa`  
**References:** `REF-02`, `REF-05`, `REF-06`, `REF-07`, `REF-08`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking`, wait until bead `atct-4nm` is unblocked, then claim it with `bd update atct-4nm --status in_progress --json`. Verify the public minimal-real-landmark slice using the highest-fidelity repo-local validation available. At minimum: prove successful `live_camera` startup/change can now surface truthful landmark payloads in the public frame when the sampled frame contains a pose; verify landmark entries are normalized to the public `id/x/y/z/v` shape; verify `tracking_state` remains honest when no pose is present; verify richer fields stay default/empty; verify unsupported `video_file` still fails honestly; and confirm addon mirrors were not treated as owned source. Record exact commands/results/gaps and leave the auditor bead open.

**Folders Created/Deleted/Modified:**
- validation-only use of `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.testbed/`

**Files Created/Deleted/Modified:**
- none required unless a minimal QA artifact becomes necessary

**Status:** ✅ Complete

**Results:** Claimed `atct-4nm` with `bd update atct-4nm --status in_progress --json` and verified the slice at the highest-fidelity repo-local level available: the hidden `.testbed/` Godot testbed using the real installed vendor addon path plus repo-root tool source via `./scripts/prepare_testbed.sh` shims. QA first inspected the implementation surface (`src/CameraTrackingFrame.gd`, `src/CameraTracking.gd`, `src/CameraTrackingFakeBackend.gd`, `.testbed/tests/test_CameraTracking.gd`, `README.md`) and confirmed the owned implementation stays in repo-root source, not `/addons` mirrors.

Exact validation command from the repo root:
- `./scripts/prepare_testbed.sh && godot --headless --path .testbed --import && godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

Result:
- ✅ passed on the first QA run (`12/12` tests, `104` asserts, exit `0`)

What QA proved:
- public sampled landmark payload now surfaces through `CameraTracking` with only the proven landmark fields `id/x/y/z/v`
- `x` / `y` are normalized/clamped into `[0,1]`
- tool-owned horizontal mirroring is applied when `preview.flip_horizontal = true`
- `tracking_state = tracked` survives only when at least one valid public landmark remains after normalization; otherwise the public frame falls back to `idle`
- richer/unproven fields (`confidence`, `head_position`, `head_velocity`, `head_orientation`, `skeleton`) remain honest defaults
- preview/source/lifecycle ownership remains in tool-owned public composition (`CameraTracking.gd` / `CameraTrackingFrame.gd`)
- unsupported `video_file` still fails honestly with `unsupported_source_kind`
- commit `f5063564082db0269677b1d104fad3a9293cc334` touched only repo-root owned files plus the plan (`src/CameraTrackingFrame.gd`, `src/CameraTrackingFakeBackend.gd`, `.testbed/tests/test_CameraTracking.gd`, `README.md`, plan file); no `/addons` mirror file was treated as owned source
- hidden installed vendor addon staleness was handled truthfully in the validation flow: QA inspected `.testbed/addons/aerobeat-vendor-mediapipe-python/src/MediaPipePythonFrameMapper.gd` and confirmed it already matched the vendor repo’s current landmark-capable mapper content, so no `godotenv addons install` refresh was necessary on this machine for the QA pass

Proven non-empty/public-on-success fields in this slice:
- top-level frame: `timestamp_ms`, `backend`, `source_kind`, `source_id`, `tracking_state`, `frame_size.{x,y}`, `preview_transform.flip_horizontal`, `preview_transform.space`, `landmarks[]`
- landmark entries: `id`, `x`, `y`, `z`, `v`

Still default/provisional after this slice:
- `confidence = 0.0`
- `head_position = {0,0,0}`
- `head_velocity = {0,0,0}`
- `head_orientation = {0,0,0,1}`
- `skeleton = {}`
- continuous/reacquiring/loss semantics remain deferred.

---

### Task 3: Audit public normalization for the minimal real landmark frame

**Bead ID:** `atct-gmo`  
**SubAgent:** `primary`  
**Role:** `auditor`  
**References:** `REF-01`, `REF-02`, `REF-03`, `REF-04`, `REF-05`, `REF-06`, `REF-07`, `REF-08`, `REF-09`, `REF-10`  
**Prompt:** In `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking`, wait until bead `atct-gmo` is unblocked, then claim it with `bd update atct-gmo --status in_progress --json`. Independently audit the minimal-real-landmark slice against this plan, the repo diff, coder evidence, and QA evidence. Verify the public frame now carries only truthful landmark fields the paired vendor slice can actually prove; verify coordinate/public normalization remains tool-owned; verify richer fields remain honest defaults; and verify downstream blocker notes are still accurate. If the slice passes, close bead `atct-gmo` with an honest reason; if not, report the exact gap and keep the lane active.

**Folders Created/Deleted/Modified:**
- none required

**Files Created/Deleted/Modified:**
- none required unless a minimal audit artifact becomes necessary

**Status:** ✅ Complete

**Results:** Independently audited commit `f5063564082db0269677b1d104fad3a9293cc334` against this repo-local plan, the landed diff, the paired coordination context, and the recorded coder/QA evidence. Re-read the owned implementation surface (`src/CameraTrackingFrame.gd`, `src/CameraTracking.gd`, `src/CameraTrackingFakeBackend.gd`, `.testbed/tests/test_CameraTracking.gd`, `README.md`), confirmed the commit touched only repo-root owned source/tests/docs plus the plan, and confirmed no `/addons` mirror was treated as owned source.

Exact audit commands/results:
- `bd update atct-gmo --status in_progress --json` ✅ claimed bead
- `git rev-parse HEAD` → `f5063564082db0269677b1d104fad3a9293cc334`
- `git show --stat --oneline f5063564082db0269677b1d104fad3a9293cc334` ✅ landed files were `.plans/2026-05-22-minimal-real-landmark-normalization-slice.md`, `.testbed/tests/test_CameraTracking.gd`, `README.md`, `src/CameraTrackingFakeBackend.gd`, `src/CameraTrackingFrame.gd`
- `git diff-tree --no-commit-id --name-only -r f5063564082db0269677b1d104fad3a9293cc334` ✅ no addon-mirror file paths appeared
- `./scripts/prepare_testbed.sh && godot --headless --path .testbed --import && godot --headless --path .testbed --script addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` ✅ passed (`12/12` tests, `104` asserts, exit `0`)
- `diff -u /home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/src/MediaPipePythonFrameMapper.gd /home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.testbed/addons/aerobeat-vendor-mediapipe-python/src/MediaPipePythonFrameMapper.gd` ✅ no diff, so the currently installed vendor addon on this host is not stale for this slice

Audit conclusions:
- the public sampled-frame landmark payload now surfaces through `CameraTracking` with only the proven public landmark fields `id`, `x`, `y`, `z`, and `v`
- `x` / `y` normalization is tool-owned in `CameraTrackingFrame.gd`, clamps into `[0,1]`, and applies tool-owned horizontal mirroring on `x` when `preview.flip_horizontal = true`
- `tracking_state` remains `tracked` only when at least one valid public landmark with an `id` survives normalization; otherwise attempted tracked frames fall back to `idle`
- richer/unproven fields remain honest defaults: `confidence = 0.0`, `head_position = {0,0,0}`, `head_velocity = {0,0,0}`, `head_orientation = {0,0,0,1}`, and `skeleton = {}`
- preview/source/lifecycle ownership remains tool-owned via `CameraTracking.gd`, `CameraTrackingFrame.gd`, and preview composition helpers; the tool slice did not move that ownership into the vendor repo
- current validation evidence is sufficient and truthful for the planned scope on this host: repo-local highest-fidelity validation passes, and the currently installed vendor addon used by the hidden testbed matches the vendor repo source for the mapper seam

Public fields proven by this slice:
- top-level sampled/public frame truth: `timestamp_ms`, `backend`, `source_kind`, `source_id`, `tracking_state`, `frame_size.{x,y}`, `preview_transform.flip_horizontal`, `preview_transform.space`, `landmarks[]`
- per-landmark truth when emitted: `id`, `x`, `y`, `z`, `v`

Still default/provisional after this slice:
- continuous tracking / streaming semantics
- `reacquiring` / loss semantics across time
- non-zero aggregate `confidence` meaning
- `head_position`, `head_velocity`, `head_orientation`
- `skeleton`
- multi-pose guarantees
- richer physical meaning/scale guarantees for landmark `z`

---

## Dependency Shape

- `atct-9xa` → first executable implementation bead
- `atct-4nm` depends on `atct-9xa`
- `atct-gmo` depends on `atct-4nm`

Execution note: this tool slice should not begin until the paired vendor slice in `REF-05` finishes green, even though that cross-repo ordering is documented here rather than encoded as a repo-local Beads dependency.

---

## Final Results

**Status:** ✅ Complete

**What We Built:** The tool slice is now independently audited complete for its planned scope. `aerobeat-tool-camera-tracking` truthfully consumes the paired vendor sampled-landmark payload, normalizes it into the public `CameraTracking` frame using only the proven public landmark fields (`id/x/y/z/v`), clamps and mirrors coordinates at the tool-owned contract boundary, preserves tool ownership of preview/source/lifecycle/public composition, and leaves richer semantics at honest defaults.

**Reference Check:** The implementation preserved the ownership split: the vendor repo still owns runtime/raw landmark extraction while this repo owns the public normalized frame contract, including coordinate normalization, public tracking-state truth at the sampled-frame boundary, and downstream guarantee language. Audit also confirmed the hidden installed vendor addon currently used by the testbed is aligned with vendor source rather than being a stale mirror.

**Commits:**
- `f5063564082db0269677b1d104fad3a9293cc334` - Normalize minimal real landmark frame

**Lessons Learned:** The right tool-side upgrade was still restraint. The win here was making the public landmark contract truthful, typed, and explicit without pretending the sample-only upstream runtime is already a continuous gameplay-ready tracking stream.

---

*Prepared on 2026-05-22*
