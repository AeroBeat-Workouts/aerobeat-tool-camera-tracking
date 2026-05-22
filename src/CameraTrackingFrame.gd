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

static func normalize(frame: Dictionary, config: Dictionary = {}) -> Dictionary:
	var normalized := empty(config)
	if frame.is_empty():
		return normalized

	if frame.has("timestamp_ms"):
		normalized["timestamp_ms"] = int(frame.get("timestamp_ms", 0))
	if frame.has("backend"):
		normalized["backend"] = str(frame.get("backend", normalized.get("backend", CameraTrackingConfig.DEFAULT_BACKEND)))
	if frame.has("source_kind"):
		normalized["source_kind"] = str(frame.get("source_kind", normalized.get("source_kind", CameraTrackingConfig.DEFAULT_SOURCE_KIND)))
	if frame.has("source_id"):
		normalized["source_id"] = str(frame.get("source_id", normalized.get("source_id", "")))
	if frame.has("tracking_state"):
		normalized["tracking_state"] = str(frame.get("tracking_state", "idle"))
	if frame.has("confidence"):
		normalized["confidence"] = float(frame.get("confidence", 0.0))
	if frame.has("frame_size") and frame.get("frame_size") is Dictionary:
		normalized["frame_size"] = _normalize_size(frame.get("frame_size", {}), normalized.get("frame_size", {}))
	if frame.has("head_position") and frame.get("head_position") is Dictionary:
		normalized["head_position"] = _normalize_vec3(frame.get("head_position", {}), normalized.get("head_position", {}))
	if frame.has("head_velocity") and frame.get("head_velocity") is Dictionary:
		normalized["head_velocity"] = _normalize_vec3(frame.get("head_velocity", {}), normalized.get("head_velocity", {}))
	if frame.has("head_orientation") and frame.get("head_orientation") is Dictionary:
		normalized["head_orientation"] = _normalize_quat(frame.get("head_orientation", {}), normalized.get("head_orientation", {}))
	if frame.has("landmarks") and frame.get("landmarks") is Array:
		normalized["landmarks"] = frame.get("landmarks", []).duplicate(true)
	if frame.has("skeleton") and frame.get("skeleton") is Dictionary:
		normalized["skeleton"] = frame.get("skeleton", {}).duplicate(true)
	return normalized

static func _normalize_size(size: Dictionary, fallback: Dictionary) -> Dictionary:
	return {
		"x": int(size.get("x", fallback.get("x", 0))),
		"y": int(size.get("y", fallback.get("y", 0)))
	}

static func _normalize_vec3(vector: Dictionary, fallback: Dictionary) -> Dictionary:
	return {
		"x": float(vector.get("x", fallback.get("x", 0.0))),
		"y": float(vector.get("y", fallback.get("y", 0.0))),
		"z": float(vector.get("z", fallback.get("z", 0.0)))
	}

static func _normalize_quat(quaternion: Dictionary, fallback: Dictionary) -> Dictionary:
	return {
		"x": float(quaternion.get("x", fallback.get("x", 0.0))),
		"y": float(quaternion.get("y", fallback.get("y", 0.0))),
		"z": float(quaternion.get("z", fallback.get("z", 0.0))),
		"w": float(quaternion.get("w", fallback.get("w", 1.0)))
	}
