class_name CameraTrackingFrame
extends RefCounted

static func empty(config: Dictionary = {}) -> Dictionary:
	var normalized := CameraTrackingConfig.normalize(config)
	var source: Dictionary = normalized.get("source", {})
	var preview: Dictionary = normalized.get("preview", {})
	return {
		"timestamp_ms": 0,
		"backend": normalized.get("backend", CameraTrackingConfig.DEFAULT_BACKEND),
		"source_kind": source.get("kind", CameraTrackingConfig.DEFAULT_SOURCE_KIND),
		"source_id": source.get("camera_id", source.get("path", "")),
		"tracking_state": "idle",
		"confidence": 0.0,
		"frame_size": {"x": 0, "y": 0},
		"preview_transform": {
			"flip_horizontal": preview.get("flip_horizontal", true),
			"space": "gameplay_normalized"
		},
		"head_position": {"x": 0.0, "y": 0.0, "z": 0.0},
		"head_velocity": {"x": 0.0, "y": 0.0, "z": 0.0},
		"head_orientation": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
		"landmarks": [],
		"skeleton": {}
	}
