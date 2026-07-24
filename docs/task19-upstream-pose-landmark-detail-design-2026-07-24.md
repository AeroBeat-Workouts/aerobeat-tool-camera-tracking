# Task 19 Design Packet: Upstream pose landmark-detail seam

Date: 2026-07-24
Owner of this design packet: `aerobeat-tool-camera-tracking`

## Goal

Replace the input-local `GAMEPLAY_ANCHOR_LANDMARKS` shortcut with a real upstream pose-landmark detail control that lives in the GodotEnv-managed dependency lane, while staying honest about what performance changes are and are not possible.

## Short answer

- **Do not overload `tracking.quality`.**
- **Add a new pose-specific enum:** `tracking.pose.landmark_detail`.
- **Recommended enum values:** `full`, `reduced`, `gameplay_anchors`.
- **Default/back-compat behavior:** if `tracking.pose.landmark_detail` is absent, preserve today's behavior by deriving it from `tracking.quality` (`optimized/simple -> reduced`, `full/raw -> full`).
- **Truth about perf:** this does **not** reduce MediaPipe pose inference compute by itself because the landmarker still produces the full 33-point pose. It **does** reduce post-inference filtering/normalization work and emitted/consumed landmark payload size if the vendor runtime applies the subset before smoothing/output.

## Why a new enum is the right contract

### Why not extend `tracking.quality`

`tracking.quality` already carries legacy meaning in the tracker/vendor path and currently folds together output detail expectations with older overlay/filter semantics. Extending it again to distinguish `reduced` vs `gameplay_anchors` would make the field less truthful and harder to reason about:

- `tracking.quality` already maps to current vendor `point_mode` selection.
- `tracking.pose.smoothing_style` already owns smoothing/filter behavior.
- `runtime.model_complexity` already owns model selection.
- landmark-subset control is specifically a **pose payload/detail** concern, not a general quality concern.

### Why `tracking.pose.landmark_detail`

A new pose-owned field keeps the meaning narrow and explicit:

- sits next to `tracking.pose.enabled`, `tracking.pose.inference_interval_frames`, and `tracking.pose.smoothing_style`
- avoids lying about model quality or smoothing behavior
- leaves room for future pose-only detail choices without disturbing hand config or generic tracking knobs
- keeps the schema readable for YAML authors

## Recommended contract

### Public YAML surface

```yaml
tracking:
  quality: optimized
  pose:
    enabled: true
    inference_interval_frames: 1
    smoothing_style: lite_filtered
    landmark_detail: gameplay_anchors
```

### Enum definition

`tracking.pose.landmark_detail`

- `full`
  - emit/process the full pose landmark set currently preserved by `tracking.quality=full`
  - needed when downstream consumers depend on hips/knees/ankles/full preview/debug truth
- `reduced`
  - emit/process the current vendor reduced set
  - current set in vendor runtime: `nose`, shoulders, elbows, wrists, hips, knees, ankles
- `gameplay_anchors`
  - emit/process only the current gameplay anchor set
  - target set: `nose`, shoulders, elbows, wrists

### Runtime-facing mapping

Tool layer should normalize `tracking.pose.landmark_detail` and mirror it into `runtime.pose_landmark_detail` for the vendor runtime.

Vendor runtime should stop deriving pose landmark subset purely from `tracking.quality` when the new field is explicitly present.

Recommended precedence:

1. If `tracking.pose.landmark_detail` is present, use it.
2. Else derive from current back-compat rules:
   - `tracking.quality in {optimized, simple}` -> `reduced`
   - `tracking.quality in {full, raw}` -> `full`
3. Never implicitly choose `gameplay_anchors` from legacy fields.

That last rule is important: `gameplay_anchors` is a new opt-in contract, not something old YAML should silently fall into.

## Owning repos and exact files to touch

### 1) `aerobeat-tool-camera-tracking` (schema owner / public contract owner)

Owns the public tracker config contract and the tool-to-vendor compatibility bridge.

**Files to update**

- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/src/CameraTrackingConfig.gd`
  - add default for `tracking.pose.landmark_detail`
  - normalize the enum
  - carry it into `runtime.pose_landmark_detail`
  - preserve old `tracking.quality` behavior when the new field is absent
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/docs/tracker-config-schema.md`
  - document the new enum and precedence rules
  - explicitly state compute-win limits
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/README.md`
  - brief contract note for consumers if README summarizes tracker-owned config
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking/.testbed/tests/test_CameraTracking.gd`
  - add config normalization coverage for new field and back-compat derivation

### 2) `aerobeat-vendor-mediapipe-python` (vendor/runtime owner)

Owns the real emitted pose payload subset and therefore the only honest upstream runtime reduction seam currently available in this stack.

**Files to update**

- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/src/MediaPipePythonConfig.gd`
  - accept/pass through the new normalized pose field in public/vendor runtime config
  - preserve old `tracking.quality` behavior when absent
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/runtime/mediapipe_runtime_probe.py`
  - replace binary `point_mode` logic with explicit pose-landmark-detail logic
  - define named sets for `full`, `reduced`, `gameplay_anchors`
  - apply subset selection before filtering/output so post-processing cost scales with the selected set
  - continue surfacing truth in `vendor_tracking_semantics`
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/runtime/tests/test_mediapipe_runtime_probe.py`
  - add tests for explicit `gameplay_anchors`
  - add tests for explicit override precedence vs legacy `tracking.quality`
  - keep current `optimized -> reduced` behavior green when field absent
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/README.md`
  - document perf truth and runtime model limitations

### 3) `aerobeat-input-camera-tracking` (consumer / local-helper removal owner)

Owns the current local helper and downstream assumptions that still depend on lower-body landmarks.

**Files to update**

- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/assets/boxing.camera_tracking.yaml`
  - eventually opt into `tracking.pose.landmark_detail` once downstream coupling is ready
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/assets/flow.camera_tracking.yaml`
  - same as above
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/src/detectors/pose_landmark_ids.gd`
  - remove `GAMEPLAY_ANCHOR_LANDMARKS` once upstream detail selection is the source of truth
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/src/detectors/pose_detector_substrate.gd`
  - remove local subset extraction paths that exist only to emulate upstream reduction
  - keep or refactor any true semantic lookup helpers that remain useful independently of subset control
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/docs/cross-repo-config-contract.md`
  - replace the current “allowed local helper” note with the finalized upstream contract
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/tests/unit/test_pose_detector_substrate.gd`
  - rework tests that currently assert the local helper boundary
- `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking/tests/unit/test_camera_tracking_config_profiles.gd`
  - add YAML/profile coverage for the new field once profiles adopt it

## Important downstream coupling: why this is not a one-file swap

Today the input repo still uses more than gameplay anchors in several paths:

- baseline capture accumulates knees and ankles
- tracking validity / body measurements still depend on broader pose metrics
- preview/debug/full-scene truth still expects more than anchor points

That means **adding the upstream enum is safe immediately**, but **switching current boxing/flow profiles to `gameplay_anchors` is not automatically safe**.

### Practical consequence

There are really two implementation phases:

#### Phase A: Add the upstream seam safely

- ship `tracking.pose.landmark_detail`
- keep existing profile behavior unchanged by default
- preserve current `optimized -> reduced` legacy mapping
- allow explicit `gameplay_anchors` in contract/tests, but do not flip existing production profile YAML yet unless the downstream consumer is ready

#### Phase B: Remove the local input helper and adopt the new seam

- either:
  - refactor input runtime so gameplay-only logic no longer depends on lower-body landmarks, **or**
  - keep full/reduced pose available for preview/debug while explicitly consuming the upstream-selected gameplay-anchor pose subset for gameplay-only logic
- only then remove `GAMEPLAY_ANCHOR_LANDMARKS` and change profile YAML to `gameplay_anchors`

## Runtime/performance truth

### What gets better

If the vendor runtime applies `gameplay_anchors` before smoothing/output, this creates real wins in the **post-inference** path:

- fewer landmarks copied into runtime payloads
- fewer landmarks passed through smoothing/filtering state
- smaller emitted JSON payloads / replay artifacts
- less downstream parsing and dictionary churn in tool/input layers

Going from current reduced set (13 ids) to gameplay anchors (7 ids) is a real reduction in post-processing and transport size.

### What does not get better

This does **not** reduce the underlying MediaPipe pose model compute by itself:

- the Tasks pose landmarker still infers the full pose internally
- `runtime.model_complexity` still selects lite/full/heavy model size, but not landmark count
- there is no evidence in the current runtime that MediaPipe can be told to infer only 7 landmark outputs for this model family

So the honest statement is:

> The upstream seam yields a real payload/post-processing reduction, but not a true pose-inference compute reduction unless a different upstream model/runtime capability is introduced later.

## Recommended backward-compatibility strategy

1. **Schema stays at version 1** for this additive field.
2. Make `tracking.pose.landmark_detail` optional.
3. Derive default behavior from legacy `tracking.quality` when the new field is absent.
4. Keep current assets valid without edit.
5. Do not silently reinterpret old configs as `gameplay_anchors`.
6. Surface the chosen value in vendor/tool debug metadata so QA can verify the actual active detail mode.

Recommended normalization rules:

- accepted values: `full`, `reduced`, `gameplay_anchors`
- normalize hyphen/case variants only if already consistent with current repo style
- unknown values fall back to legacy-derived behavior, not to `gameplay_anchors`

## Validation path before rollout

### Tool repo validation

- update/add `.testbed/tests/test_CameraTracking.gd`
  - config normalization adds `tracking.pose.landmark_detail`
  - runtime compatibility mirrors `runtime.pose_landmark_detail`
  - legacy YAML without the field still normalizes to today’s behavior

Suggested command:

```bash
godot --headless --path .testbed --script addons/aerobeat-vendor-godot-unit-test/gut_cmdln.gd -gdir=res://tests -gselect=test_CameraTracking.gd -gexit
```

### Vendor repo validation

- update/add `runtime/tests/test_mediapipe_runtime_probe.py`
  - explicit `gameplay_anchors` produces only ids `0,11,12,13,14,15,16`
  - explicit `reduced` preserves current reduced set
  - explicit `full` preserves all landmarks
  - absent field + `tracking.quality=optimized` still resolves to reduced
  - explicit field overrides legacy `tracking.quality`
  - `vendor_tracking_semantics` reports both selected detail mode and before/after counts

Suggested command:

```bash
python3 -m pytest runtime/tests/test_mediapipe_runtime_probe.py
```

### Input repo validation

When the consumer adoption slice lands:

- rerun `tests/unit/test_pose_detector_substrate.gd`
- rerun `tests/unit/test_camera_tracking_config_profiles.gd`
- rerun proving-harness coverage that depends on calibration/baseline/debug truth
- verify no lower-body-dependent logic is accidentally broken when profile YAML opts into `gameplay_anchors`

Suggested commands:

```bash
godot --headless --path .testbed --script addons/aerobeat-vendor-godot-unit-test/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_pose_detector_substrate.gd -gexit
godot --headless --path .testbed --script addons/aerobeat-vendor-godot-unit-test/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_camera_tracking_config_profiles.gd -gexit
```

## Risks / coupling to call out explicitly

1. **Current input coupling to knees/ankles/hips**
   - the new upstream field can exist before the input repo is ready to consume `gameplay_anchors`
   - flipping the YAML too early would break baseline/metrics/debug assumptions

2. **Preview/debug truth changes**
   - if the upstream runtime emits only gameplay anchors, preview skeleton/debug UIs will also see fewer points unless a parallel full-detail debug path exists

3. **Replay artifact compatibility**
   - saved session frames recorded with fewer landmarks may affect any tooling that implicitly expects reduced/full pose payloads
   - QA should verify replay and preview presentation are still truthful

4. **Terminology drift**
   - avoid introducing both `landmark_mode` and `landmark_detail` for pose at the same time
   - pick one name and use it consistently; this packet recommends `landmark_detail` for clarity

## Recommended next slices

### Next coder slice

1. **Coder A (tool + vendor lane)**
   - implement `tracking.pose.landmark_detail` end-to-end in `aerobeat-tool-camera-tracking` and `aerobeat-vendor-mediapipe-python`
   - preserve all current defaults/back-compat behavior
   - add explicit `vendor_tracking_semantics.landmark_detail`
   - do **not** flip input profile YAML to `gameplay_anchors` yet unless input coupling is addressed in the same slice

2. **Coder B (input consumer lane)**
   - remove/replace local `GAMEPLAY_ANCHOR_LANDMARKS`
   - either decouple lower-body-dependent logic from gameplay-anchor-only configs, or keep current profiles on `reduced`
   - only opt profile YAML into `gameplay_anchors` if tests prove the remaining runtime no longer needs lower-body landmarks

### Next QA slice

- verify back-compat first: old boxing/flow YAML still behaves exactly as before
- verify explicit `gameplay_anchors` truth via runtime metadata and emitted ids
- verify replay/preview/debug remain honest when fewer landmarks are emitted
- if input profiles switch, rerun calibration/weave/hook/uppercut test coverage and scene truth

### Next auditor slice

- audit that implementation did not claim a false inference-compute win
- audit that legacy configs still map to current reduced/full behavior
- audit that the local helper was only removed once the upstream field truly became the source of truth for that path
- audit that docs in all three repos agree on the same enum name, values, and precedence

## Final recommendation

Approve Task 19 with this contract:

- introduce **new** `tracking.pose.landmark_detail`
- values: `full | reduced | gameplay_anchors`
- keep `tracking.quality` for legacy/back-compat only
- treat `gameplay_anchors` as an explicit opt-in, not a silent remap
- claim only post-inference/payload/runtime wins, not MediaPipe inference-compute wins
