class_name CameraTrackingConfig
extends RefCounted

const DEFAULT_BACKEND := "camera_tracking_default"
const DEFAULT_BACKEND_IMPL := "mediapipe_python"
const DEFAULT_SOURCE_KIND := "live_camera"
const DEFAULT_TRACKING_QUALITY := "optimized"
const DEFAULT_OVERLAY_MODE := "optimized"
const DEFAULT_MIN_VISIBILITY := 0.35
const DEFAULT_GESTURE_EVAL_INTERVAL_FRAMES := 1
const DEFAULT_TRACKING_MAX_FPS := 15
const DEFAULT_STATE_UPDATE_MAX_FPS := 15
const DEFAULT_SURFACE_MODE := "attach"
const DEFAULT_PREVIEW_MAX_FPS := 10
const DEFAULT_PREVIEW_WIDTH := 960
const DEFAULT_PREVIEW_HEIGHT := 540
const DEFAULT_PREVIEW_QUALITY := 75
const DEFAULT_PREVIEW_POSE_SKELETON_VISIBLE := true
const DEFAULT_PREVIEW_HAND_BBOX_VISIBLE := true
const DEFAULT_LIVE_CAMERA_REQUESTED_WIDTH := 960
const DEFAULT_LIVE_CAMERA_REQUESTED_HEIGHT := 540
const DEFAULT_LIVE_CAMERA_REQUESTED_FPS := 15
const DEFAULT_POSE_ENABLED := true
const DEFAULT_POSE_INFERENCE_INTERVAL_FRAMES := 1
const DEFAULT_POSE_SMOOTHING_STYLE := "lite_filtered"
const DEFAULT_HANDS_ENABLED := false
const DEFAULT_HAND_LANDMARK_MODE := "lite"
const DEFAULT_HAND_INFERENCE_INTERVAL_FRAMES := 1
const DEFAULT_HAND_BBOX_ENABLED := true
const DEFAULT_HAND_ASSOCIATION_PREFER_EXISTING_POSE_SIDE_BINDING := true
const DEFAULT_HAND_ASSOCIATION_NEAREST_WRIST_FALLBACK := true
const DEFAULT_HAND_VALIDITY_MAX_STALE_MS := 80
const DEFAULT_HAND_VALIDITY_REACQUIRE_STABLE_MS := 40
const DEFAULT_HAND_GRACE_ENABLED := true
const DEFAULT_HAND_GRACE_POSITION_DECAY := 1.0
const DEFAULT_HAND_GRACE_SIZE_DECAY := 1.0

static func defaults() -> Dictionary:
	return {
		"backend": DEFAULT_BACKEND,
		"source": {
			"kind": DEFAULT_SOURCE_KIND,
			"camera_id": "",
			"path": "",
			"live_camera": {
				"requested_width": DEFAULT_LIVE_CAMERA_REQUESTED_WIDTH,
				"requested_height": DEFAULT_LIVE_CAMERA_REQUESTED_HEIGHT,
				"requested_fps": DEFAULT_LIVE_CAMERA_REQUESTED_FPS,
			}
		},
		"tracking": {
			"quality": DEFAULT_TRACKING_QUALITY,
			"overlay_mode": DEFAULT_OVERLAY_MODE,
			"gesture_eval_interval_frames": DEFAULT_GESTURE_EVAL_INTERVAL_FRAMES,
			"min_visibility": DEFAULT_MIN_VISIBILITY,
			"max_fps": DEFAULT_TRACKING_MAX_FPS,
			"state_update_max_fps": DEFAULT_STATE_UPDATE_MAX_FPS,
			"pose": {
				"enabled": DEFAULT_POSE_ENABLED,
				"inference_interval_frames": DEFAULT_POSE_INFERENCE_INTERVAL_FRAMES,
				"smoothing_style": DEFAULT_POSE_SMOOTHING_STYLE
			},
			"hands": {
				"enabled": DEFAULT_HANDS_ENABLED,
				"landmark_mode": DEFAULT_HAND_LANDMARK_MODE,
				"inference_interval_frames": DEFAULT_HAND_INFERENCE_INTERVAL_FRAMES,
				"bbox": {
					"enabled": DEFAULT_HAND_BBOX_ENABLED
				},
				"association": {
					"prefer_existing_pose_side_binding": DEFAULT_HAND_ASSOCIATION_PREFER_EXISTING_POSE_SIDE_BINDING,
					"nearest_wrist_fallback": DEFAULT_HAND_ASSOCIATION_NEAREST_WRIST_FALLBACK
				},
				"validity": {
					"max_stale_ms": DEFAULT_HAND_VALIDITY_MAX_STALE_MS,
					"reacquire_stable_ms": DEFAULT_HAND_VALIDITY_REACQUIRE_STABLE_MS
				},
				"grace": {
					"enabled": DEFAULT_HAND_GRACE_ENABLED,
					"position_decay": DEFAULT_HAND_GRACE_POSITION_DECAY,
					"size_decay": DEFAULT_HAND_GRACE_SIZE_DECAY
				}
			}
		},
		"preview": {
			"enabled": true,
			"surface_mode": DEFAULT_SURFACE_MODE,
			"flip_horizontal": true,
			"max_fps": DEFAULT_PREVIEW_MAX_FPS,
			"width": DEFAULT_PREVIEW_WIDTH,
			"height": DEFAULT_PREVIEW_HEIGHT,
			"quality": DEFAULT_PREVIEW_QUALITY,
			"live": {
				"enabled": true,
				"max_fps": DEFAULT_PREVIEW_MAX_FPS,
				"width": DEFAULT_PREVIEW_WIDTH,
				"height": DEFAULT_PREVIEW_HEIGHT,
				"quality": DEFAULT_PREVIEW_QUALITY,
			},
			"replay": {
				"enabled": true,
				"max_fps": DEFAULT_PREVIEW_MAX_FPS,
				"width": DEFAULT_PREVIEW_WIDTH,
				"height": DEFAULT_PREVIEW_HEIGHT,
				"quality": DEFAULT_PREVIEW_QUALITY,
			},
			"overlays": {
				"pose_skeleton_visible": DEFAULT_PREVIEW_POSE_SKELETON_VISIBLE,
				"hand_bbox_visible": DEFAULT_PREVIEW_HAND_BBOX_VISIBLE,
			}
		}
	}

static func normalize(config: Dictionary = {}) -> Dictionary:
	var normalized := defaults()
	_deep_merge(normalized, config)
	normalized["backend"] = normalize_requested_backend(normalized.get("backend", DEFAULT_BACKEND))
	normalized["source"] = _normalize_source_config(normalized.get("source", {}))
	normalized["tracking"] = _normalize_tracking_config(normalized.get("tracking", {}))
	normalized["preview"] = _normalize_preview_config(normalized.get("preview", {}), normalized.get("source", {}))
	_apply_runtime_compatibility(normalized)
	return normalized

static func preferred_backend_id() -> String:
	return DEFAULT_BACKEND_IMPL

static func normalize_requested_backend(backend_id: Variant) -> String:
	var normalized := str(backend_id).strip_edges()
	return normalized if normalized != "" else DEFAULT_BACKEND

static func resolve_backend_id(backend_id: Variant) -> String:
	var requested_backend_id := normalize_requested_backend(backend_id)
	if requested_backend_id == DEFAULT_BACKEND:
		return preferred_backend_id()
	return requested_backend_id

static func make_state_detail(overrides: Dictionary = {}) -> Dictionary:
	var detail := {
		"backend_ready": false,
		"preview_ready": false,
		"tracking_ready": false,
		"source_ready": false
	}
	_deep_merge(detail, overrides)
	return detail

static func _normalize_source_config(value: Variant) -> Dictionary:
	var source: Dictionary = defaults().get("source", {}).duplicate(true)
	if value is Dictionary:
		_deep_merge(source, value)
	source["kind"] = str(source.get("kind", DEFAULT_SOURCE_KIND)).strip_edges()
	if source["kind"] == "":
		source["kind"] = DEFAULT_SOURCE_KIND
	source["camera_id"] = str(source.get("camera_id", "")).strip_edges()
	source["path"] = str(source.get("path", "")).strip_edges()
	source["live_camera"] = _normalize_live_camera_source_config(source.get("live_camera", {}))
	return source

static func _normalize_live_camera_source_config(value: Variant) -> Dictionary:
	var live_camera: Dictionary = defaults().get("source", {}).get("live_camera", {}).duplicate(true)
	if value is Dictionary:
		_deep_merge(live_camera, value)
	live_camera["requested_width"] = _normalize_positive_int(
		live_camera.get("requested_width", DEFAULT_LIVE_CAMERA_REQUESTED_WIDTH),
		DEFAULT_LIVE_CAMERA_REQUESTED_WIDTH
	)
	live_camera["requested_height"] = _normalize_positive_int(
		live_camera.get("requested_height", DEFAULT_LIVE_CAMERA_REQUESTED_HEIGHT),
		DEFAULT_LIVE_CAMERA_REQUESTED_HEIGHT
	)
	live_camera["requested_fps"] = _normalize_nonnegative_int(
		live_camera.get("requested_fps", DEFAULT_LIVE_CAMERA_REQUESTED_FPS),
		DEFAULT_LIVE_CAMERA_REQUESTED_FPS
	)
	return live_camera

static func _normalize_tracking_config(value: Variant) -> Dictionary:
	var tracking: Dictionary = defaults().get("tracking", {}).duplicate(true)
	if value is Dictionary:
		_deep_merge(tracking, value)
	tracking["quality"] = str(tracking.get("quality", DEFAULT_TRACKING_QUALITY)).strip_edges().to_lower()
	if tracking["quality"] == "":
		tracking["quality"] = DEFAULT_TRACKING_QUALITY
	tracking["overlay_mode"] = str(tracking.get("overlay_mode", DEFAULT_OVERLAY_MODE)).strip_edges().to_lower()
	if tracking["overlay_mode"] == "":
		tracking["overlay_mode"] = DEFAULT_OVERLAY_MODE
	tracking["gesture_eval_interval_frames"] = _normalize_positive_int(
		tracking.get("gesture_eval_interval_frames", DEFAULT_GESTURE_EVAL_INTERVAL_FRAMES),
		DEFAULT_GESTURE_EVAL_INTERVAL_FRAMES
	)
	tracking["min_visibility"] = clampf(float(tracking.get("min_visibility", DEFAULT_MIN_VISIBILITY)), 0.0, 1.0)
	tracking["max_fps"] = _normalize_nonnegative_int(
		tracking.get("max_fps", DEFAULT_TRACKING_MAX_FPS),
		DEFAULT_TRACKING_MAX_FPS
	)
	tracking["state_update_max_fps"] = _normalize_nonnegative_int(
		tracking.get("state_update_max_fps", DEFAULT_STATE_UPDATE_MAX_FPS),
		DEFAULT_STATE_UPDATE_MAX_FPS
	)
	tracking["pose"] = _normalize_pose_config(tracking.get("pose", {}))
	tracking["hands"] = _normalize_hands_config(tracking.get("hands", {}))
	return tracking

static func _normalize_pose_config(value: Variant) -> Dictionary:
	var pose: Dictionary = defaults().get("tracking", {}).get("pose", {}).duplicate(true)
	if value is Dictionary:
		_deep_merge(pose, value)
	pose["enabled"] = bool(pose.get("enabled", DEFAULT_POSE_ENABLED))
	pose["inference_interval_frames"] = _normalize_positive_int(
		pose.get("inference_interval_frames", DEFAULT_POSE_INFERENCE_INTERVAL_FRAMES),
		DEFAULT_POSE_INFERENCE_INTERVAL_FRAMES
	)
	pose["smoothing_style"] = _normalize_pose_smoothing_style(
		pose.get("smoothing_style", DEFAULT_POSE_SMOOTHING_STYLE)
	)
	return pose

static func _normalize_hands_config(value: Variant) -> Dictionary:
	var hands: Dictionary = defaults().get("tracking", {}).get("hands", {}).duplicate(true)
	if value is Dictionary:
		_deep_merge(hands, value)
	hands["enabled"] = bool(hands.get("enabled", DEFAULT_HANDS_ENABLED))
	hands["landmark_mode"] = _normalize_hand_landmark_mode(hands.get("landmark_mode", DEFAULT_HAND_LANDMARK_MODE))
	hands["inference_interval_frames"] = _normalize_positive_int(
		hands.get("inference_interval_frames", DEFAULT_HAND_INFERENCE_INTERVAL_FRAMES),
		DEFAULT_HAND_INFERENCE_INTERVAL_FRAMES
	)
	hands.erase("bbox_recompute_interval_frames")
	var bbox: Dictionary = hands.get("bbox", {}) if hands.get("bbox", {}) is Dictionary else {}
	bbox["enabled"] = bool(bbox.get("enabled", DEFAULT_HAND_BBOX_ENABLED))
	hands["bbox"] = bbox
	hands["association"] = _normalize_hand_association_config(hands.get("association", {}))
	hands["validity"] = _normalize_hand_validity_config(hands.get("validity", {}))
	hands["grace"] = _normalize_hand_grace_config(hands.get("grace", {}))
	return hands

static func _normalize_hand_association_config(value: Variant) -> Dictionary:
	var association: Dictionary = defaults().get("tracking", {}).get("hands", {}).get("association", {}).duplicate(true)
	if value is Dictionary:
		_deep_merge(association, value)
	association["prefer_existing_pose_side_binding"] = bool(
		association.get(
			"prefer_existing_pose_side_binding",
			DEFAULT_HAND_ASSOCIATION_PREFER_EXISTING_POSE_SIDE_BINDING
		)
	)
	association["nearest_wrist_fallback"] = bool(
		association.get("nearest_wrist_fallback", DEFAULT_HAND_ASSOCIATION_NEAREST_WRIST_FALLBACK)
	)
	return association

static func _normalize_hand_validity_config(value: Variant) -> Dictionary:
	var validity: Dictionary = defaults().get("tracking", {}).get("hands", {}).get("validity", {}).duplicate(true)
	if value is Dictionary:
		_deep_merge(validity, value)
	validity["max_stale_ms"] = _normalize_nonnegative_int(
		validity.get("max_stale_ms", validity.get("max_stale_frames", DEFAULT_HAND_VALIDITY_MAX_STALE_MS)),
		DEFAULT_HAND_VALIDITY_MAX_STALE_MS
	)
	validity["reacquire_stable_ms"] = _normalize_nonnegative_int(
		validity.get("reacquire_stable_ms", validity.get("reacquire_stable_frames", DEFAULT_HAND_VALIDITY_REACQUIRE_STABLE_MS)),
		DEFAULT_HAND_VALIDITY_REACQUIRE_STABLE_MS
	)
	validity.erase("max_stale_frames")
	validity.erase("reacquire_stable_frames")
	return validity

static func _normalize_hand_grace_config(value: Variant) -> Dictionary:
	var grace: Dictionary = defaults().get("tracking", {}).get("hands", {}).get("grace", {}).duplicate(true)
	if value is Dictionary:
		_deep_merge(grace, value)
	grace["enabled"] = bool(grace.get("enabled", DEFAULT_HAND_GRACE_ENABLED))
	grace["position_decay"] = clampf(float(grace.get("position_decay", DEFAULT_HAND_GRACE_POSITION_DECAY)), 0.0, 1.0)
	grace["size_decay"] = clampf(float(grace.get("size_decay", DEFAULT_HAND_GRACE_SIZE_DECAY)), 0.0, 1.0)
	return grace

static func _normalize_preview_config(value: Variant, source: Dictionary = {}) -> Dictionary:
	var preview: Dictionary = defaults().get("preview", {}).duplicate(true)
	if value is Dictionary:
		_deep_merge(preview, value)
	preview["surface_mode"] = str(preview.get("surface_mode", DEFAULT_SURFACE_MODE)).strip_edges()
	if preview["surface_mode"] == "":
		preview["surface_mode"] = DEFAULT_SURFACE_MODE
	preview["flip_horizontal"] = bool(preview.get("flip_horizontal", true))
	var legacy_mode_defaults := {
		"enabled": bool(preview.get("enabled", true)),
		"max_fps": preview.get("max_fps", DEFAULT_PREVIEW_MAX_FPS),
		"width": preview.get("width", DEFAULT_PREVIEW_WIDTH),
		"height": preview.get("height", DEFAULT_PREVIEW_HEIGHT),
		"quality": preview.get("quality", DEFAULT_PREVIEW_QUALITY),
	}
	preview["live"] = _normalize_preview_feed_config(preview.get("live", {}), legacy_mode_defaults)
	preview["replay"] = _normalize_preview_feed_config(preview.get("replay", {}), legacy_mode_defaults)
	preview["overlays"] = _normalize_preview_overlays_config(preview.get("overlays", {}))
	var selected_preview: Dictionary = _resolve_active_preview_mode_config(source, preview)
	preview["enabled"] = bool(selected_preview.get("enabled", true))
	preview["max_fps"] = int(selected_preview.get("max_fps", DEFAULT_PREVIEW_MAX_FPS))
	preview["width"] = int(selected_preview.get("width", DEFAULT_PREVIEW_WIDTH))
	preview["height"] = int(selected_preview.get("height", DEFAULT_PREVIEW_HEIGHT))
	preview["quality"] = int(selected_preview.get("quality", DEFAULT_PREVIEW_QUALITY))
	return preview

static func _normalize_preview_feed_config(value: Variant, fallback: Dictionary = {}) -> Dictionary:
	var feed := {
		"enabled": bool(fallback.get("enabled", true)),
		"max_fps": _normalize_nonnegative_int(fallback.get("max_fps", DEFAULT_PREVIEW_MAX_FPS), DEFAULT_PREVIEW_MAX_FPS),
		"width": _normalize_positive_int(fallback.get("width", DEFAULT_PREVIEW_WIDTH), DEFAULT_PREVIEW_WIDTH),
		"height": _normalize_positive_int(fallback.get("height", DEFAULT_PREVIEW_HEIGHT), DEFAULT_PREVIEW_HEIGHT),
		"quality": _normalize_quality(fallback.get("quality", DEFAULT_PREVIEW_QUALITY), DEFAULT_PREVIEW_QUALITY),
	}
	if value is Dictionary:
		_deep_merge(feed, value)
	feed["enabled"] = bool(feed.get("enabled", true))
	feed["max_fps"] = _normalize_nonnegative_int(feed.get("max_fps", DEFAULT_PREVIEW_MAX_FPS), DEFAULT_PREVIEW_MAX_FPS)
	feed["width"] = _normalize_positive_int(feed.get("width", DEFAULT_PREVIEW_WIDTH), DEFAULT_PREVIEW_WIDTH)
	feed["height"] = _normalize_positive_int(feed.get("height", DEFAULT_PREVIEW_HEIGHT), DEFAULT_PREVIEW_HEIGHT)
	feed["quality"] = _normalize_quality(feed.get("quality", DEFAULT_PREVIEW_QUALITY), DEFAULT_PREVIEW_QUALITY)
	return feed

static func _normalize_preview_overlays_config(value: Variant) -> Dictionary:
	var overlays: Dictionary = defaults().get("preview", {}).get("overlays", {}).duplicate(true)
	if value is Dictionary:
		_deep_merge(overlays, value)
	overlays["pose_skeleton_visible"] = bool(overlays.get("pose_skeleton_visible", DEFAULT_PREVIEW_POSE_SKELETON_VISIBLE))
	overlays["hand_bbox_visible"] = bool(overlays.get("hand_bbox_visible", DEFAULT_PREVIEW_HAND_BBOX_VISIBLE))
	return overlays

static func _resolve_active_preview_mode_config(source: Dictionary, preview: Dictionary) -> Dictionary:
	var source_kind := str(source.get("kind", DEFAULT_SOURCE_KIND)).strip_edges().to_lower()
	var key := "replay" if source_kind == "video_file" or source_kind == "session_manifest" else "live"
	var resolved: Variant = preview.get(key, {})
	return resolved.duplicate(true) if resolved is Dictionary else {}

static func _apply_runtime_compatibility(normalized: Dictionary) -> void:
	var runtime: Dictionary = normalized.get("runtime", {}) if normalized.get("runtime", {}) is Dictionary else {}
	var source: Dictionary = normalized.get("source", {}) if normalized.get("source", {}) is Dictionary else {}
	var live_camera: Dictionary = source.get("live_camera", {}) if source.get("live_camera", {}) is Dictionary else {}
	var tracking: Dictionary = normalized.get("tracking", {})
	var pose: Dictionary = tracking.get("pose", {}) if tracking.get("pose", {}) is Dictionary else {}
	var hands: Dictionary = tracking.get("hands", {}) if tracking.get("hands", {}) is Dictionary else {}
	var validity: Dictionary = hands.get("validity", {}) if hands.get("validity", {}) is Dictionary else {}
	var bbox: Dictionary = hands.get("bbox", {}) if hands.get("bbox", {}) is Dictionary else {}
	var grace: Dictionary = hands.get("grace", {}) if hands.get("grace", {}) is Dictionary else {}
	var preview: Dictionary = normalized.get("preview", {}) if normalized.get("preview", {}) is Dictionary else {}

	runtime["pose_enabled"] = bool(pose.get("enabled", DEFAULT_POSE_ENABLED))
	runtime["pose_inference_interval_frames"] = int(
		pose.get("inference_interval_frames", DEFAULT_POSE_INFERENCE_INTERVAL_FRAMES)
	)
	runtime["pose_smoothing_style"] = str(
		pose.get("smoothing_style", DEFAULT_POSE_SMOOTHING_STYLE)
	)
	if not runtime.has("filter_enabled") and not runtime.has("no_filter"):
		runtime["no_filter"] = runtime["pose_smoothing_style"] == "lite_raw"
	runtime["hand_tracking_enabled"] = bool(hands.get("enabled", DEFAULT_HANDS_ENABLED))
	if not runtime.has("hand_landmark_mode"):
		runtime["hand_landmark_mode"] = str(hands.get("landmark_mode", DEFAULT_HAND_LANDMARK_MODE))
	if not runtime.has("hand_inference_interval_frames"):
		runtime["hand_inference_interval_frames"] = int(
			hands.get("inference_interval_frames", DEFAULT_HAND_INFERENCE_INTERVAL_FRAMES)
		)
	runtime.erase("hand_bbox_recompute_interval_frames")
	if not runtime.has("hand_bbox_enabled"):
		runtime["hand_bbox_enabled"] = bool(bbox.get("enabled", DEFAULT_HAND_BBOX_ENABLED))
	if not runtime.has("hand_max_stale_ms"):
		runtime["hand_max_stale_ms"] = int(
			validity.get("max_stale_ms", DEFAULT_HAND_VALIDITY_MAX_STALE_MS)
		)
	if not runtime.has("hand_reacquire_stable_ms"):
		runtime["hand_reacquire_stable_ms"] = int(
			validity.get("reacquire_stable_ms", DEFAULT_HAND_VALIDITY_REACQUIRE_STABLE_MS)
		)
	if not runtime.has("hand_grace_enabled"):
		runtime["hand_grace_enabled"] = bool(grace.get("enabled", DEFAULT_HAND_GRACE_ENABLED))
	if not runtime.has("hand_grace_position_decay"):
		runtime["hand_grace_position_decay"] = float(grace.get("position_decay", DEFAULT_HAND_GRACE_POSITION_DECAY))
	if not runtime.has("hand_grace_size_decay"):
		runtime["hand_grace_size_decay"] = float(grace.get("size_decay", DEFAULT_HAND_GRACE_SIZE_DECAY))
	if not runtime.has("tracking_max_fps"):
		runtime["tracking_max_fps"] = int(tracking.get("max_fps", DEFAULT_TRACKING_MAX_FPS))
	if not runtime.has("state_update_max_fps"):
		runtime["state_update_max_fps"] = int(tracking.get("state_update_max_fps", DEFAULT_STATE_UPDATE_MAX_FPS))
	if not runtime.has("preview_enabled"):
		runtime["preview_enabled"] = bool(preview.get("enabled", true))
	if not runtime.has("preview_max_fps"):
		runtime["preview_max_fps"] = int(preview.get("max_fps", DEFAULT_PREVIEW_MAX_FPS))
	if not runtime.has("preview_width"):
		runtime["preview_width"] = int(preview.get("width", DEFAULT_PREVIEW_WIDTH))
	if not runtime.has("preview_height"):
		runtime["preview_height"] = int(preview.get("height", DEFAULT_PREVIEW_HEIGHT))
	if not runtime.has("preview_quality"):
		runtime["preview_quality"] = int(preview.get("quality", DEFAULT_PREVIEW_QUALITY))
	if not runtime.has("live_camera_width"):
		runtime["live_camera_width"] = int(live_camera.get("requested_width", DEFAULT_LIVE_CAMERA_REQUESTED_WIDTH))
	if not runtime.has("live_camera_height"):
		runtime["live_camera_height"] = int(live_camera.get("requested_height", DEFAULT_LIVE_CAMERA_REQUESTED_HEIGHT))
	if not runtime.has("live_camera_fps"):
		runtime["live_camera_fps"] = int(live_camera.get("requested_fps", DEFAULT_LIVE_CAMERA_REQUESTED_FPS))
	normalized["runtime"] = runtime

static func _normalize_pose_smoothing_style(value: Variant) -> String:
	var normalized := str(value).strip_edges().to_lower()
	match normalized:
		"lite_raw":
			return "lite_raw"
		_:
			return DEFAULT_POSE_SMOOTHING_STYLE

static func _normalize_hand_landmark_mode(value: Variant) -> String:
	var normalized := str(value).strip_edges().to_lower()
	match normalized:
		"full":
			return "full"
		_:
			return DEFAULT_HAND_LANDMARK_MODE

static func _normalize_quality(value: Variant, default_value: int) -> int:
	var parsed := int(value)
	if parsed < 1 or parsed > 100:
		return default_value
	return parsed

static func _normalize_nonnegative_int(value: Variant, default_value: int) -> int:
	var parsed := int(value)
	if parsed < 0:
		return default_value
	return parsed

static func _normalize_positive_int(value: Variant, default_value: int) -> int:
	var parsed := int(value)
	if parsed <= 0:
		return default_value
	return parsed

static func _deep_merge(base: Dictionary, incoming: Dictionary) -> void:
	for key in incoming.keys():
		var incoming_value: Variant = incoming[key]
		if base.has(key) and base[key] is Dictionary and incoming_value is Dictionary:
			_deep_merge(base[key], incoming_value)
		else:
			base[key] = incoming_value
