class_name CameraTrackingFrame
extends RefCounted

static func empty(config: Dictionary = {}) -> Dictionary:
	var normalized := CameraTrackingConfig.normalize(config)
	var source: Dictionary = normalized.get("source", {})
	var preview: Dictionary = normalized.get("preview", {})
	var source_kind := str(source.get("kind", CameraTrackingConfig.DEFAULT_SOURCE_KIND))
	var camera_id := str(source.get("camera_id", ""))
	var source_path := str(source.get("path", ""))
	var source_id := source_path if source_kind == "video_file" else camera_id
	if source_id == "":
		source_id = camera_id if camera_id != "" else source_path
	return {
		"timestamp_ms": 0,
		"backend": normalized.get("backend", CameraTrackingConfig.DEFAULT_BACKEND),
		"source_kind": source_kind,
		"source_id": source_id,
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
