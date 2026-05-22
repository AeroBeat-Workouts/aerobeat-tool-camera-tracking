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

	var preview: Dictionary = CameraTrackingConfig.normalize(config).get("preview", {})
	if frame.has("timestamp_ms"):
		normalized["timestamp_ms"] = int(frame.get("timestamp_ms", 0))
	if frame.has("backend"):
		normalized["backend"] = str(frame.get("backend", normalized.get("backend", CameraTrackingConfig.DEFAULT_BACKEND)))
	if frame.has("source_kind"):
		normalized["source_kind"] = str(frame.get("source_kind", normalized.get("source_kind", CameraTrackingConfig.DEFAULT_SOURCE_KIND)))
	if frame.has("source_id"):
		normalized["source_id"] = str(frame.get("source_id", normalized.get("source_id", "")))
	if frame.has("frame_size") and frame.get("frame_size") is Dictionary:
		normalized["frame_size"] = _normalize_size(frame.get("frame_size", {}), normalized.get("frame_size", {}))
	if frame.has("landmarks") and frame.get("landmarks") is Array:
		normalized["landmarks"] = _normalize_landmarks(
			frame.get("landmarks", []),
			bool(preview.get("flip_horizontal", true))
		)
	if frame.has("tracking_state"):
		normalized["tracking_state"] = _normalize_tracking_state(
			frame.get("tracking_state", "idle"),
			normalized.get("landmarks", [])
		)
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

static func _normalize_landmarks(landmarks: Array, flip_horizontal: bool) -> Array:
	var normalized: Array = []
	for landmark_variant in landmarks:
		if not landmark_variant is Dictionary:
			continue
		var landmark: Dictionary = landmark_variant
		if landmark.has("id") == false:
			continue
		normalized.append(_normalize_landmark(landmark, flip_horizontal))
	return normalized

static func _normalize_landmark(landmark: Dictionary, flip_horizontal: bool) -> Dictionary:
	var x := _normalize_unit_coordinate(float(landmark.get("x", 0.0)))
	if flip_horizontal:
		x = 1.0 - x
	return {
		"id": int(landmark.get("id", -1)),
		"x": x,
		"y": _normalize_unit_coordinate(float(landmark.get("y", 0.0))),
		"z": float(landmark.get("z", 0.0)),
		"v": _normalize_visibility(landmark)
	}

static func _normalize_visibility(landmark: Dictionary) -> float:
	if landmark.has("v"):
		return float(landmark.get("v", 0.0))
	if landmark.has("visibility"):
		return float(landmark.get("visibility", 0.0))
	return 0.0

static func _normalize_unit_coordinate(value: float) -> float:
	return clampf(value, 0.0, 1.0)

static func _normalize_tracking_state(state: Variant, landmarks: Array) -> String:
	var normalized_state := str(state).strip_edges().to_lower()
	if normalized_state == "tracked":
		return "tracked" if landmarks.is_empty() == false else "idle"
	if normalized_state == "idle":
		return "idle"
	return normalized_state
