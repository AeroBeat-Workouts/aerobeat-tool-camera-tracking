# First-Pass `CameraTracking` Singleton API

## Purpose

A vendor-agnostic camera-tracking service that owns lifecycle, preview, and normalized tracking output for both live-camera and replay/video sources.

## State machine

Standardize these top-level states now:
- `idle`
- `starting`
- `running`
- `restarting`
- `stopping`
- `error`

Standardize these readiness facets/details now:
- `backend_ready`
- `preview_ready`
- `tracking_ready`
- `source_ready`

## Core methods

- `start(config: Dictionary) -> void`
- `stop() -> void`
- `change(config: Dictionary) -> void`
- `list_cameras() -> Array`
- `get_state() -> Dictionary`
- `get_active_config() -> Dictionary`
- `get_tracking_frame() -> Dictionary`
- `get_preview_descriptor() -> Dictionary`
- `attach_preview_surface(node: Node) -> void`
- `detach_preview_surface() -> void`
- `get_last_error() -> Dictionary`
- `is_running() -> bool`

Assumption now locked in:
- `attach_preview_surface(node)` is the preferred ownership model.
- The provided node can still be a smaller or larger UI slot/container in Godot.
- `tool-camera-tracking` should maintain aspect ratio inside that slot, rather than forcing consumers to rebuild preview binding logic themselves.

## Signals

- `state_changed(state: String, detail: Dictionary)`
- `tracking_updated(frame: Dictionary)`
- `preview_changed(descriptor: Dictionary)`
- `cameras_changed(cameras: Array)`
- `error_raised(error_info: Dictionary)`

## Config shape assumptions

```gdscript
{
  "backend": "mediapipe_python", # or mediapipe_native
  "source": {
    "kind": "live_camera",       # or video_file
    "camera_id": "/dev/video0",  # live only
    "path": "res://.../clip.mp4" # replay only
  },
  "tracking": {
    "quality": "optimized",      # none|optimized|full or future richer enum
    "overlay_mode": "optimized",
    "gesture_eval_interval_frames": 1,
    "min_visibility": 0.35
  },
  "preview": {
    "enabled": true,
    "surface_mode": "attach",
    "flip_horizontal": true
  }
}
```

## Tracking frame contract assumptions

The singleton should normalize and expose a single canonical frame payload, regardless of backend.

```gdscript
{
  "timestamp_ms": 0,
  "backend": "mediapipe_python",
  "source_kind": "live_camera",
  "source_id": "/dev/video0",
  "tracking_state": "tracked",   # or reacquiring/lost
  "confidence": 0.0,
  "frame_size": {"x": 0, "y": 0},
  "preview_transform": {
    "flip_horizontal": true,
    "space": "gameplay_normalized"
  },
  "head_position": {"x": 0.0, "y": 0.0, "z": 0.0},
  "head_velocity": {"x": 0.0, "y": 0.0, "z": 0.0},
  "head_orientation": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
  "landmarks": [],
  "skeleton": {}
}
```

Important assumption:
- coordinate-space truth must be documented once here to avoid per-consumer flip/bounds mismatches.

## Backend abstraction assumptions

A backend implementation should support equivalent operations behind the singleton:
- start
- stop
- change
- list cameras
- provide preview descriptor or preview binding support
- emit tracking updates
- emit lifecycle state changes

Possible backend interface shape:
- `CameraTrackingBackend.start(config)`
- `CameraTrackingBackend.stop()`
- `CameraTrackingBackend.change(config)`
- `CameraTrackingBackend.list_cameras()`
- `CameraTrackingBackend.get_state()`
- `CameraTrackingBackend.get_tracking_frame()`
- `CameraTrackingBackend.get_preview_descriptor()`

## Replay model assumptions

Replay should still be a `CameraTracking` source mode:
- `source.kind = "video_file"`
- `tool-camera-tracking` remains the owner of tracking lifecycle
- `tool-video-player` provides playback lifecycle/time/surface services
- `tool-camera-tracking` coordinates with `tool-video-player` rather than reimplementing playback UX
- `tool-camera-tracking` may consume `tool-video-player` as a GodotEnv dependency for replay mode

## Open questions

1. Should `change(config)` guarantee a full stop boundary always, or allow vendor-defined hot-change for safe subsets?
2. Should `list_cameras()` include verification status/quality metadata or stay minimal at first?
3. Should tracking quality remain user-facing as `none/optimized/full`, or should config separate overlay mode vs detection quality more explicitly?
4. Should preview attachment be a single surface only in v1, or should multi-surface mirroring be a first-class later feature?
