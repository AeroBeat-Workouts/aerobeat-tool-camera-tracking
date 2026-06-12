# Tracker Config Schema

This document is the tracker-layer companion to the input repo's cross-repo contract.

- Input/gameplay owner repo: `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-input-camera-tracking`
- Tracker/tool owner repo: `/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-tool-camera-tracking`

## v1 schema identity

```yaml
schema: aerobeat/camera_tracking_config
version: 1
profile: boxing|flow
```

The tracker layer consumes only the `aerobeat/camera_tracking_config` schema.

It does **not** parse or validate `aerobeat/gesture_detection_config` files.

## Canonical file producers

The input repo currently authors four config assets under its repo-root `assets/` folder:

- `assets/boxing.camera_tracking.yaml`
- `assets/flow.camera_tracking.yaml`
- `assets/boxing.gesture_detection.yaml`
- `assets/flow.gesture_detection.yaml`

Only the two `*.camera_tracking.yaml` files are tracker-layer inputs.

## Ownership boundary

### Owned by `aerobeat-tool-camera-tracking`

- parsing of `aerobeat/camera_tracking_config`
- validation of tracker-facing fields
- normalization/defaulting of tracker-facing fields
- rejection or surfacing of invalid tracker config values
- interpretation of cadence, smoothing, hand inference, bbox recompute, association, and validity policies

### Not owned by `aerobeat-tool-camera-tracking`

- gameplay gesture tuning
- boxing straight-punch thresholds
- gesture enable/disable rules beyond tracker cost controls
- parsing/validation of `aerobeat/gesture_detection_config`
- selection of which profile file a gameplay consumer wants to load

## Locked v1 field set

```yaml
source:
  live_camera:
    requested_width: 960
    requested_height: 540
    requested_fps: 15
preview:
  surface_mode: attach
  flip_horizontal: true
  live:
    enabled: true
    max_fps: 10
    width: 960
    height: 540
    quality: 75
  replay:
    enabled: true
    max_fps: 10
    width: 960
    height: 540
    quality: 75
  overlays:
    pose_skeleton_visible: true
    hand_bbox_visible: true
tracking:
  max_fps: 30
  state_update_max_fps: 30
  pose:
    enabled: true
    inference_interval_frames: 1
    smoothing_style: lite_filtered
  hands:
    enabled: true|false
    landmark_mode: lite
    inference_interval_frames: 1
    bbox:
      enabled: true
    association:
      prefer_existing_pose_side_binding: true
      nearest_wrist_fallback: true
    validity:
      max_stale_ms: 80
      reacquire_stable_ms: 40
    grace:
      enabled: true
      position_decay: 1.0
      size_decay: 1.0
```

## Field semantics

### `source.kind`

The tracker service currently accepts three runtime source kinds through its public config surface:
- `live_camera`
- `video_file`
- `session_manifest`

`session_manifest` is the first-class saved-session replay source. It consumes a saved-session package entrypoint (`session_manifest.json`) and dispatches from `replay_contract.replay_mode`:

- `saved_tracking_frames` → deterministic B-mode replay from saved artifacts
- `video_reinference` → A-mode replay through the packaged source video and the mounted vendor/video tracking lane

The public entry stays the same either way; only the manifest-declared replay branch changes.

### `source.live_camera.requested_width|requested_height|requested_fps`

These are the tracker-owned public live camera request knobs. They resolve to vendor runtime `live_camera_width`, `live_camera_height`, and `live_camera_fps` only for live-camera sessions. They do not pretend to affect replay decode.

### `preview.live.*` and `preview.replay.*`

These are the source-specific preview feed knobs. The tracker layer resolves the active source block into the legacy runtime-facing `preview.enabled|max_fps|width|height|quality` fields before handing the config to the vendor layer.

### `preview.overlays.pose_skeleton_visible`

Presentation-only intent for the tool-owned pose/skeleton overlay. This is intentionally separate from full video feed enablement.

### `preview.overlays.hand_bbox_visible`

Presentation-only intent for the input-owned hand bbox overlay. The tracker schema carries the public flag, but current proving-scene consumption still happens in the input repo rather than the vendor runtime.

### `tracking.max_fps`

Requested upper bound for tracker/inference cadence. This maps to vendor runtime `tracking_max_fps`. It is a cap/request, not a hardware guarantee.

### `tracking.state_update_max_fps`

Requested upper bound for how often runtime state/debug updates are emitted. This maps to vendor runtime `state_update_max_fps`. Preview publication now follows its own `preview.*.max_fps` caps instead of being forced down to the same cadence.

### `tracking.pose.enabled`

Enables or disables pose production for the tracker session.

### `tracking.pose.inference_interval_frames`

Number of frames between pose inference passes. `1` means every frame.

### `tracking.pose.smoothing_style`

Locked v1 enum:

- `lite_filtered`
- `lite_raw`

Default: `lite_filtered`

### `tracking.hands.enabled`

Enables or disables hand tracking work. The current boxing and flow profile assets both default this to `false`, while the schema still keeps the rest of the hand fields stable for future re-enable/tuning passes.

### `tracking.hands.landmark_mode`

Locked v1 enum:

- `lite`
- `full`

Default: `lite`

### `tracking.hands.inference_interval_frames`

Number of frames between hand inference passes. `1` means every frame. Hand bbox updates happen on the same cadence because bbox geometry is derived from the emitted hand sample.

### `tracking.hands.bbox.enabled`

Controls whether the tracker should surface hand bbox data in the normalized hand payload.

### `tracking.hands.association.prefer_existing_pose_side_binding`

When true, maintain the current hand-to-side association when the data remains valid.

### `tracking.hands.association.nearest_wrist_fallback`

When true, allow nearest-wrist fallback when a stable side binding is not already available.

### `tracking.hands.validity.max_stale_ms`

Maximum age, in milliseconds since the last observed hand sample, before a hand lane becomes stale/invalid.

### `tracking.hands.validity.reacquire_stable_ms`

Milliseconds of continuous valid hand observations required before the tracker reports a reacquired valid hand lane. `0` makes reacquire immediate.

### `tracking.hands.grace.enabled`

When true, missing hand detections stay in a tracker-owned `grace` state for up to `tracking.hands.validity.max_stale_ms` milliseconds instead of surfacing as plain stale carry-forward.

### `tracking.hands.grace.position_decay`

Per-grace-step multiplier applied to the carried bbox movement delta after each prediction step. `1.0` keeps constant motion; `0.0` stops positional extrapolation after the first grace step.

### `tracking.hands.grace.size_decay`

Per-grace-step multiplier applied to the carried bbox width/height growth delta after each prediction step. `1.0` keeps constant growth/shrink trend; `0.0` freezes size after the first grace step.

## Normalized hand output contract

The tracker layer now owns the per-side hand transport contract exposed in normalized tracking frames:

```yaml
hands:
  left|right:
    tracking_valid: true|false
    tracking_state: disabled|idle|unavailable|reacquiring|tracked|grace|stale|tracking_lost
    landmark_mode: lite|full
    frame_index: <int>
    timestamp_ms: <int>
    timestamp_seconds: <float>
    stale_frames: <int>
    stale_ms: <int>
    grace_frames: <int>
    grace_ms: <int>
    stable_ms: <int>
    predicted: true|false
    association:
      side: left|right
      assigned: true|false
      method: none|prefer_existing_pose_side_binding|nearest_wrist_fallback
      source_hand_index: <int>
      source_label: <string>
      source_score: <float>
    landmarks:
      - id: <int>
        x: <float>
        y: <float>
        z: <float>
        v: <float>
    bbox:
      x: <float>
      y: <float>
      width: <float>
      height: <float>
      area: <float>
      area_unit: normalized_frame_area
```

Important semantics:

- side ownership is tracker-associated upstream from raw MediaPipe hand detections; vendor handedness labels are recorded as metadata only and are not treated as durable left/right truth
- preview mirroring is applied in the tracker layer so normalized hand coordinates stay aligned with normalized pose coordinates
- `tracking_valid` becomes `false` during `reacquiring`, `unavailable`, and `tracking_lost`
- `grace` means the tool predicted the hand bbox/landmark placement from the recent tracker-owned trend; these frames still count as valid hand samples for downstream consumers
- grace/stale carry-forward is allowed only up to `tracking.hands.validity.max_stale_ms`; after that the lane becomes `tracking_lost`
- if the vendor explicitly reports hand inference unavailable, the tracker must surface `unavailable` instead of pretending stale/tracked data exists

## Locked profile defaults

### Boxing

```yaml
schema: aerobeat/camera_tracking_config
version: 1
profile: boxing
tracking:
  max_fps: 30
  state_update_max_fps: 30
  pose:
    enabled: true
    inference_interval_frames: 1
    smoothing_style: lite_filtered
  hands:
    enabled: false
    landmark_mode: lite
    inference_interval_frames: 1
    bbox:
      enabled: true
    association:
      prefer_existing_pose_side_binding: true
      nearest_wrist_fallback: true
    validity:
      max_stale_ms: 80
      reacquire_stable_ms: 40
    grace:
      enabled: true
      position_decay: 1.0
      size_decay: 1.0
```

### Flow

```yaml
schema: aerobeat/camera_tracking_config
version: 1
profile: flow
tracking:
  max_fps: 30
  state_update_max_fps: 30
  pose:
    enabled: true
    inference_interval_frames: 1
    smoothing_style: lite_filtered
  hands:
    enabled: false
    landmark_mode: lite
    inference_interval_frames: 1
    bbox:
      enabled: true
    association:
      prefer_existing_pose_side_binding: true
      nearest_wrist_fallback: true
    validity:
      max_stale_ms: 80
      reacquire_stable_ms: 40
```

## Validation responsibility

The tracker repo should validate at minimum:

- `schema == aerobeat/camera_tracking_config`
- `version == 1`
- `profile` is present and non-empty
- `tracking.pose.inference_interval_frames >= 1`
- `tracking.pose.smoothing_style` is a supported enum
- `tracking.hands.landmark_mode` is a supported enum
- `tracking.hands.inference_interval_frames >= 1`
- `tracking.hands.validity.max_stale_ms >= 0`
- `tracking.hands.validity.reacquire_stable_ms >= 0`

The tracker repo should ignore no unknown gesture fields because gesture files must never be handed to it in the first place.
