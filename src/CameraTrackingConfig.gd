class_name CameraTrackingConfig
extends RefCounted

const DEFAULT_BACKEND := "mediapipe_python"
const DEFAULT_SOURCE_KIND := "live_camera"
const DEFAULT_TRACKING_QUALITY := "optimized"
const DEFAULT_OVERLAY_MODE := "optimized"
const DEFAULT_MIN_VISIBILITY := 0.35
const DEFAULT_GESTURE_EVAL_INTERVAL_FRAMES := 1
const DEFAULT_SURFACE_MODE := "attach"

static func defaults() -> Dictionary:
	return {
		"backend": DEFAULT_BACKEND,
		"source": {
			"kind": DEFAULT_SOURCE_KIND,
			"camera_id": "",
			"path": ""
		},
		"tracking": {
			"quality": DEFAULT_TRACKING_QUALITY,
			"overlay_mode": DEFAULT_OVERLAY_MODE,
			"gesture_eval_interval_frames": DEFAULT_GESTURE_EVAL_INTERVAL_FRAMES,
			"min_visibility": DEFAULT_MIN_VISIBILITY
		},
		"preview": {
			"enabled": true,
			"surface_mode": DEFAULT_SURFACE_MODE,
			"flip_horizontal": true
		}
	}

static func normalize(config: Dictionary = {}) -> Dictionary:
	var normalized := defaults()
	_deep_merge(normalized, config)
	return normalized

static func make_state_detail(overrides: Dictionary = {}) -> Dictionary:
	var detail := {
		"backend_ready": false,
		"preview_ready": false,
		"tracking_ready": false,
		"source_ready": false
	}
	_deep_merge(detail, overrides)
	return detail

static func _deep_merge(base: Dictionary, incoming: Dictionary) -> void:
	for key in incoming.keys():
		var incoming_value: Variant = incoming[key]
		if base.has(key) and base[key] is Dictionary and incoming_value is Dictionary:
			_deep_merge(base[key], incoming_value)
		else:
			base[key] = incoming_value
