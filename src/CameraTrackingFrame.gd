class_name CameraTrackingFrame
extends RefCounted

const _HAND_SIDE_LEFT := "left"
const _HAND_SIDE_RIGHT := "right"
const _HAND_SIDES := [_HAND_SIDE_LEFT, _HAND_SIDE_RIGHT]
const _POSE_LEFT_WRIST_ID := 15
const _POSE_RIGHT_WRIST_ID := 16
const _HAND_WRIST_ID := 0
const _HAND_BBOX_AREA_UNIT := "normalized_frame_area"

static func empty(config: Dictionary = {}) -> Dictionary:
	var normalized := CameraTrackingConfig.normalize(config)
	var source: Dictionary = normalized.get("source", {})
	var preview: Dictionary = normalized.get("preview", {})
	var hand_tracking := _normalize_hand_tracking_meta({}, normalized)
	var source_kind := str(source.get("kind", CameraTrackingConfig.DEFAULT_SOURCE_KIND))
	var camera_id := str(source.get("camera_id", ""))
	var source_path := str(source.get("path", ""))
	var source_id := source_path if source_kind == "video_file" else camera_id
	if source_id == "":
		source_id = camera_id if camera_id != "" else source_path
	var backend_request := CameraTrackingConfig.normalize_requested_backend(normalized.get("backend", CameraTrackingConfig.DEFAULT_BACKEND))
	var backend_impl := CameraTrackingConfig.resolve_backend_id(backend_request)
	return {
		"timestamp_ms": 0,
		"timestamp_seconds": 0.0,
		"frame_index": 0,
		"backend": backend_impl,
		"backend_request": backend_request,
		"backend_impl": backend_impl,
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
		"skeleton": {},
		"hand_tracking": hand_tracking,
		"hands": _empty_hands_payload(hand_tracking)
	}

static func normalize(frame: Dictionary, config: Dictionary = {}, previous_frame: Dictionary = {}) -> Dictionary:
	var normalized_config := CameraTrackingConfig.normalize(config)
	var normalized := empty(normalized_config)
	if frame.is_empty():
		return normalized

	var preview: Dictionary = normalized_config.get("preview", {})
	var flip_horizontal := bool(preview.get("flip_horizontal", true))
	if frame.has("timestamp_ms"):
		normalized["timestamp_ms"] = int(frame.get("timestamp_ms", 0))
	if frame.has("timestamp_seconds"):
		normalized["timestamp_seconds"] = float(frame.get("timestamp_seconds", 0.0))
	else:
		normalized["timestamp_seconds"] = float(normalized.get("timestamp_ms", 0)) / 1000.0
	if frame.has("frame_index"):
		normalized["frame_index"] = int(frame.get("frame_index", 0))
	else:
		var previous_frame_index := int(previous_frame.get("frame_index", 0))
		normalized["frame_index"] = previous_frame_index + 1 if previous_frame_index > 0 else 1
	if frame.has("backend"):
		normalized["backend"] = str(frame.get("backend", normalized.get("backend", CameraTrackingConfig.DEFAULT_BACKEND_IMPL)))
	if frame.has("backend_request"):
		normalized["backend_request"] = CameraTrackingConfig.normalize_requested_backend(frame.get("backend_request", normalized.get("backend_request", CameraTrackingConfig.DEFAULT_BACKEND)))
	if frame.has("backend_impl"):
		normalized["backend_impl"] = str(frame.get("backend_impl", normalized.get("backend_impl", CameraTrackingConfig.DEFAULT_BACKEND_IMPL)))
	if not frame.has("backend_impl") and frame.has("backend"):
		normalized["backend_impl"] = str(normalized.get("backend", CameraTrackingConfig.DEFAULT_BACKEND_IMPL))
	if frame.has("source_kind"):
		normalized["source_kind"] = str(frame.get("source_kind", normalized.get("source_kind", CameraTrackingConfig.DEFAULT_SOURCE_KIND)))
	if frame.has("source_id"):
		normalized["source_id"] = str(frame.get("source_id", normalized.get("source_id", "")))
	if frame.has("frame_size") and frame.get("frame_size") is Dictionary:
		normalized["frame_size"] = _normalize_size(frame.get("frame_size", {}), normalized.get("frame_size", {}))
	if frame.has("landmarks") and frame.get("landmarks") is Array:
		normalized["landmarks"] = _normalize_landmarks(
			frame.get("landmarks", []),
			flip_horizontal,
			0.0
		)

	normalized["hand_tracking"] = _normalize_hand_tracking_meta(frame, normalized_config)
	normalized["hands"] = _normalize_hands_by_side(
		frame.get("hands", []) if frame.get("hands", []) is Array else [],
		normalized.get("landmarks", []),
		normalized.get("hand_tracking", {}),
		flip_horizontal,
		normalized.get("frame_index", 0),
		normalized.get("timestamp_seconds", 0.0),
		previous_frame.get("hands", {}) if previous_frame.get("hands", {}) is Dictionary else {}
	)
	if frame.has("tracking_state"):
		normalized["tracking_state"] = _normalize_tracking_state(
			frame.get("tracking_state", "idle"),
			normalized.get("landmarks", []),
			normalized.get("hands", {})
		)
	else:
		normalized["tracking_state"] = _normalize_tracking_state(
			"idle",
			normalized.get("landmarks", []),
			normalized.get("hands", {})
		)
	return normalized

static func _normalize_hand_tracking_meta(frame: Dictionary, config: Dictionary) -> Dictionary:
	var tracking: Dictionary = config.get("tracking", {})
	var hands_config: Dictionary = tracking.get("hands", {}) if tracking.get("hands", {}) is Dictionary else {}
	var validity: Dictionary = hands_config.get("validity", {}) if hands_config.get("validity", {}) is Dictionary else {}
	var association: Dictionary = hands_config.get("association", {}) if hands_config.get("association", {}) is Dictionary else {}
	var bbox: Dictionary = hands_config.get("bbox", {}) if hands_config.get("bbox", {}) is Dictionary else {}
	var grace: Dictionary = hands_config.get("grace", {}) if hands_config.get("grace", {}) is Dictionary else {}
	var vendor_meta: Dictionary = frame.get("vendor_hand_tracking", {}) if frame.get("vendor_hand_tracking", {}) is Dictionary else {}
	var hands_enabled := bool(hands_config.get("enabled", false))
	var raw_hands := frame.get("hands", []) if frame.get("hands", []) is Array else []
	var has_vendor_meta := not vendor_meta.is_empty()
	var available := hands_enabled
	if has_vendor_meta:
		available = bool(vendor_meta.get("available", false)) or raw_hands.size() > 0
	var inference_backend := str(vendor_meta.get("inference_backend", "configured" if hands_enabled else "disabled"))
	if inference_backend == "":
		inference_backend = "configured" if hands_enabled else "disabled"
	var constraints := vendor_meta.get("constraints", []) if vendor_meta.get("constraints", []) is Array else []
	var reported_unavailable := hands_enabled and has_vendor_meta and not available
	return {
		"enabled": hands_enabled,
		"available": available,
		"reported_unavailable": reported_unavailable,
		"landmark_mode": str(vendor_meta.get("landmark_mode", hands_config.get("landmark_mode", CameraTrackingConfig.DEFAULT_HAND_LANDMARK_MODE))),
		"inference_interval_frames": int(vendor_meta.get("inference_interval_frames", hands_config.get("inference_interval_frames", CameraTrackingConfig.DEFAULT_HAND_INFERENCE_INTERVAL_FRAMES))),
		"bbox_recompute_interval_frames": int(vendor_meta.get("bbox_recompute_interval_frames", hands_config.get("bbox_recompute_interval_frames", CameraTrackingConfig.DEFAULT_HAND_BBOX_RECOMPUTE_INTERVAL_FRAMES))),
		"bbox_enabled": bool(vendor_meta.get("bbox_enabled", bbox.get("enabled", true))),
		"max_stale_frames": int(vendor_meta.get("max_stale_frames", validity.get("max_stale_frames", CameraTrackingConfig.DEFAULT_HAND_VALIDITY_MAX_STALE_FRAMES))),
		"reacquire_stable_frames": int(vendor_meta.get("reacquire_stable_frames", validity.get("reacquire_stable_frames", CameraTrackingConfig.DEFAULT_HAND_VALIDITY_REACQUIRE_STABLE_FRAMES))),
		"grace": {
			"enabled": bool(grace.get("enabled", CameraTrackingConfig.DEFAULT_HAND_GRACE_ENABLED)),
			"position_decay": clampf(float(grace.get("position_decay", CameraTrackingConfig.DEFAULT_HAND_GRACE_POSITION_DECAY)), 0.0, 1.0),
			"size_decay": clampf(float(grace.get("size_decay", CameraTrackingConfig.DEFAULT_HAND_GRACE_SIZE_DECAY)), 0.0, 1.0)
		},
		"association": {
			"prefer_existing_pose_side_binding": bool(association.get("prefer_existing_pose_side_binding", true)),
			"nearest_wrist_fallback": bool(association.get("nearest_wrist_fallback", true))
		},
		"inference_backend": inference_backend,
		"constraints": constraints,
		"error_info": vendor_meta.get("error_info", {}) if vendor_meta.get("error_info", {}) is Dictionary else {}
	}

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

static func _normalize_landmarks(landmarks: Array, flip_horizontal: bool, default_visibility: float = 0.0) -> Array:
	var normalized: Array = []
	for landmark_variant in landmarks:
		if not landmark_variant is Dictionary:
			continue
		var landmark: Dictionary = landmark_variant
		if landmark.has("id") == false:
			continue
		normalized.append(_normalize_landmark(landmark, flip_horizontal, default_visibility))
	return normalized

static func _normalize_landmark(landmark: Dictionary, flip_horizontal: bool, default_visibility: float = 0.0) -> Dictionary:
	var x := _normalize_unit_coordinate(float(landmark.get("x", 0.0)))
	if flip_horizontal:
		x = 1.0 - x
	return {
		"id": int(landmark.get("id", -1)),
		"x": x,
		"y": _normalize_unit_coordinate(float(landmark.get("y", 0.0))),
		"z": float(landmark.get("z", 0.0)),
		"v": _normalize_visibility(landmark, default_visibility)
	}

static func _normalize_visibility(landmark: Dictionary, default_visibility: float = 0.0) -> float:
	if landmark.has("v"):
		return float(landmark.get("v", default_visibility))
	if landmark.has("visibility"):
		return float(landmark.get("visibility", default_visibility))
	return default_visibility

static func _normalize_unit_coordinate(value: float) -> float:
	return clampf(value, 0.0, 1.0)

static func _normalize_tracking_state(_state: Variant, landmarks: Array, hands: Dictionary = {}) -> String:
	if landmarks.is_empty() == false:
		return "tracked"
	for side in _HAND_SIDES:
		var payload: Dictionary = hands.get(side, {}) if hands.get(side, {}) is Dictionary else {}
		var hand_state := str(payload.get("tracking_state", "idle"))
		if ["tracked", "grace", "stale", "reacquiring"].has(hand_state):
			return "tracked"
	return "idle"

static func _empty_hands_payload(hand_tracking: Dictionary) -> Dictionary:
	return {
		_HAND_SIDE_LEFT: _empty_hand_payload(_HAND_SIDE_LEFT, hand_tracking),
		_HAND_SIDE_RIGHT: _empty_hand_payload(_HAND_SIDE_RIGHT, hand_tracking)
	}

static func _empty_hand_payload(side: String, hand_tracking: Dictionary) -> Dictionary:
	var state := "disabled" if not bool(hand_tracking.get("enabled", false)) else "idle"
	return {
		"tracking_valid": false,
		"tracking_state": state,
		"landmark_mode": str(hand_tracking.get("landmark_mode", CameraTrackingConfig.DEFAULT_HAND_LANDMARK_MODE)),
		"frame_index": 0,
		"timestamp_seconds": 0.0,
		"stale_frames": 0,
		"grace_frames": 0,
		"predicted": false,
		"association": _empty_association(side),
		"landmarks": [],
		"bbox": _empty_bbox(),
		"_stable_valid_frames": 0,
		"_bbox_position_delta": {"x": 0.0, "y": 0.0},
		"_bbox_size_delta": {"width": 0.0, "height": 0.0}
	}

static func _empty_association(side: String) -> Dictionary:
	return {
		"side": side,
		"assigned": false,
		"method": "none",
		"source_hand_index": -1,
		"source_label": "",
		"source_score": 0.0
	}

static func _empty_bbox() -> Dictionary:
	return {
		"x": 0.0,
		"y": 0.0,
		"width": 0.0,
		"height": 0.0,
		"area": 0.0,
		"area_unit": _HAND_BBOX_AREA_UNIT
	}

static func _normalize_hands_by_side(
	raw_hands: Array,
	pose_landmarks: Array,
	hand_tracking: Dictionary,
	flip_horizontal: bool,
	frame_index: int,
	timestamp_seconds: float,
	previous_hands: Dictionary
) -> Dictionary:
	var normalized := _empty_hands_payload(hand_tracking)
	for side in _HAND_SIDES:
		normalized[side]["frame_index"] = frame_index
		normalized[side]["timestamp_seconds"] = timestamp_seconds
	if not bool(hand_tracking.get("enabled", false)):
		return normalized
	if bool(hand_tracking.get("reported_unavailable", false)):
		for side in _HAND_SIDES:
			normalized[side]["tracking_state"] = "unavailable"
		return normalized

	var candidates := _normalize_hand_candidates(raw_hands, flip_horizontal, bool(hand_tracking.get("bbox_enabled", true)))
	var assignments := _assign_hand_candidates(candidates, pose_landmarks, hand_tracking, previous_hands)
	for side in _HAND_SIDES:
		var assignment: Dictionary = assignments.get(side, {}) if assignments.get(side, {}) is Dictionary else {}
		var previous_payload: Dictionary = previous_hands.get(side, {}) if previous_hands.get(side, {}) is Dictionary else {}
		if assignment.has("candidate"):
			var candidate: Dictionary = assignment.get("candidate", {})
			normalized[side] = _tracked_hand_payload_from_candidate(
				side,
				candidate,
				assignment,
				hand_tracking,
				previous_payload,
				frame_index,
				timestamp_seconds
			)
			continue
		var stale_frames: int = int(previous_payload.get("stale_frames", 0)) + 1
		var max_stale_frames: int = max(0, int(hand_tracking.get("max_stale_frames", 0)))
		var grace: Dictionary = hand_tracking.get("grace", {}) if hand_tracking.get("grace", {}) is Dictionary else {}
		if _has_prior_hand_sample(previous_payload) and stale_frames <= max_stale_frames:
			if bool(grace.get("enabled", CameraTrackingConfig.DEFAULT_HAND_GRACE_ENABLED)):
				normalized[side] = _predict_grace_hand_payload(side, previous_payload, hand_tracking, frame_index, timestamp_seconds, stale_frames)
			else:
				normalized[side] = {
					"tracking_valid": true,
					"tracking_state": "stale",
					"landmark_mode": str(previous_payload.get("landmark_mode", hand_tracking.get("landmark_mode", CameraTrackingConfig.DEFAULT_HAND_LANDMARK_MODE))),
					"frame_index": frame_index,
					"timestamp_seconds": timestamp_seconds,
					"stale_frames": stale_frames,
					"grace_frames": 0,
					"predicted": false,
					"association": previous_payload.get("association", _empty_association(side)).duplicate(true),
					"landmarks": previous_payload.get("landmarks", []).duplicate(true),
					"bbox": previous_payload.get("bbox", _empty_bbox()).duplicate(true),
					"_stable_valid_frames": int(previous_payload.get("_stable_valid_frames", 0)),
					"_pose_side_locked": bool(previous_payload.get("_pose_side_locked", false)),
					"_bbox_position_delta": previous_payload.get("_bbox_position_delta", {"x": 0.0, "y": 0.0}).duplicate(true),
					"_bbox_size_delta": previous_payload.get("_bbox_size_delta", {"width": 0.0, "height": 0.0}).duplicate(true)
				}
		elif _has_prior_hand_sample(previous_payload):
			normalized[side]["tracking_state"] = "tracking_lost"
			normalized[side]["stale_frames"] = stale_frames
			normalized[side]["grace_frames"] = 0
			normalized[side]["predicted"] = false
			normalized[side]["_pose_side_locked"] = bool(previous_payload.get("_pose_side_locked", false))
	return normalized

static func _normalize_hand_candidates(raw_hands: Array, flip_horizontal: bool, bbox_enabled: bool) -> Array:
	var candidates: Array = []
	for index in range(raw_hands.size()):
		var raw_hand: Variant = raw_hands[index]
		if not raw_hand is Dictionary:
			continue
		var hand: Dictionary = raw_hand
		var score := float(hand.get("score", 1.0))
		var landmarks := _normalize_landmarks(hand.get("landmarks", []) if hand.get("landmarks", []) is Array else [], flip_horizontal, score)
		var bbox := _empty_bbox()
		if bbox_enabled and hand.get("bbox", {}) is Dictionary:
			bbox = _normalize_bbox(hand.get("bbox", {}), flip_horizontal)
		candidates.append({
			"source_hand_index": index,
			"source_label": _normalize_hand_label(hand.get("label", "")),
			"source_score": score,
			"landmarks": landmarks,
			"bbox": bbox,
			"anchor": _hand_candidate_anchor(landmarks, bbox)
		})
	return candidates

static func _normalize_bbox(raw_bbox: Dictionary, flip_horizontal: bool) -> Dictionary:
	var x0 := _normalize_unit_coordinate(float(raw_bbox.get("x", 0.0)))
	var y0 := _normalize_unit_coordinate(float(raw_bbox.get("y", 0.0)))
	var width := maxf(0.0, float(raw_bbox.get("width", 0.0)))
	var height := maxf(0.0, float(raw_bbox.get("height", 0.0)))
	var x1 := clampf(x0 + width, 0.0, 1.0)
	var y1 := clampf(y0 + height, 0.0, 1.0)
	x0 = clampf(x0, 0.0, x1)
	y0 = clampf(y0, 0.0, y1)
	if flip_horizontal:
		var flipped_x0 := 1.0 - x1
		var flipped_x1 := 1.0 - x0
		x0 = minf(flipped_x0, flipped_x1)
		x1 = maxf(flipped_x0, flipped_x1)
	var normalized_width := maxf(0.0, x1 - x0)
	var normalized_height := maxf(0.0, y1 - y0)
	return {
		"x": x0,
		"y": y0,
		"width": normalized_width,
		"height": normalized_height,
		"area": normalized_width * normalized_height,
		"area_unit": _HAND_BBOX_AREA_UNIT
	}

static func _normalize_hand_label(value: Variant) -> String:
	var normalized := str(value).strip_edges().to_lower()
	if normalized == "left" or normalized == "right":
		return normalized
	return normalized

static func _hand_candidate_anchor(landmarks: Array, bbox: Dictionary) -> Dictionary:
	for landmark_variant in landmarks:
		if not landmark_variant is Dictionary:
			continue
		var landmark: Dictionary = landmark_variant
		if int(landmark.get("id", -1)) == _HAND_WRIST_ID:
			return {"x": float(landmark.get("x", 0.0)), "y": float(landmark.get("y", 0.0))}
	if float(bbox.get("width", 0.0)) > 0.0 or float(bbox.get("height", 0.0)) > 0.0:
		return {
			"x": float(bbox.get("x", 0.0)) + (float(bbox.get("width", 0.0)) * 0.5),
			"y": float(bbox.get("y", 0.0)) + (float(bbox.get("height", 0.0)) * 0.5)
		}
	return {}

static func _assign_hand_candidates(candidates: Array, pose_landmarks: Array, hand_tracking: Dictionary, previous_hands: Dictionary) -> Dictionary:
	var assignments := {}
	var pose_wrists := _extract_pose_wrists(pose_landmarks)
	var unassigned_indices: Array = []
	for index in range(candidates.size()):
		unassigned_indices.append(index)
	var association: Dictionary = hand_tracking.get("association", {}) if hand_tracking.get("association", {}) is Dictionary else {}
	if bool(association.get("prefer_existing_pose_side_binding", true)):
		var preferred_requests: Array[Dictionary] = []
		for side in _HAND_SIDES:
			var previous_payload: Dictionary = previous_hands.get(side, {}) if previous_hands.get(side, {}) is Dictionary else {}
			var wrist_anchor := pose_wrists.get(side, {}) if pose_wrists.get(side, {}) is Dictionary else {}
			var match_anchor := {}
			var pose_side_locked := bool(previous_payload.get("_pose_side_locked", false))
			if pose_side_locked and wrist_anchor.is_empty() == false:
				match_anchor = wrist_anchor
			else:
				match_anchor = _hand_payload_anchor(previous_payload)
			if match_anchor.is_empty():
				continue
			preferred_requests.append({
				"side": side,
				"anchor": match_anchor,
				"method": "prefer_existing_pose_side_binding",
				"pose_side_locked": pose_side_locked or wrist_anchor.is_empty() == false,
			})
		_assign_requests_by_nearest_distance(assignments, candidates, unassigned_indices, preferred_requests)
	if bool(association.get("nearest_wrist_fallback", true)):
		var fallback_requests: Array[Dictionary] = []
		for side in _HAND_SIDES:
			if assignments.has(side):
				continue
			var wrist_anchor := pose_wrists.get(side, {}) if pose_wrists.get(side, {}) is Dictionary else {}
			if wrist_anchor.is_empty():
				continue
			fallback_requests.append({
				"side": side,
				"anchor": wrist_anchor,
				"method": "nearest_wrist_fallback",
				"pose_side_locked": true,
			})
		_assign_requests_by_nearest_distance(assignments, candidates, unassigned_indices, fallback_requests)
	return assignments

static func _assign_requests_by_nearest_distance(assignments: Dictionary, candidates: Array, unassigned_indices: Array, requests: Array[Dictionary]) -> void:
	var pending_requests := requests.duplicate(true)
	while not pending_requests.is_empty() and not unassigned_indices.is_empty():
		var best_request_index := -1
		var best_candidate_index := -1
		var best_distance := INF
		for request_index in range(pending_requests.size()):
			var request: Dictionary = pending_requests[request_index]
			var target: Dictionary = request.get("anchor", {}) if request.get("anchor", {}) is Dictionary else {}
			if target.is_empty():
				continue
			var match_index := _nearest_candidate_index(candidates, unassigned_indices, target)
			if match_index < 0:
				continue
			var distance := _distance_between_points(target, candidates[match_index].get("anchor", {}))
			if distance < best_distance:
				best_distance = distance
				best_request_index = request_index
				best_candidate_index = match_index
		if best_request_index < 0 or best_candidate_index < 0:
			break
		var winning_request: Dictionary = pending_requests[best_request_index]
		var winning_side := str(winning_request.get("side", ""))
		assignments[winning_side] = {
			"candidate": candidates[best_candidate_index],
			"method": str(winning_request.get("method", "none")),
			"distance": best_distance,
			"pose_side_locked": bool(winning_request.get("pose_side_locked", false))
		}
		unassigned_indices.erase(best_candidate_index)
		pending_requests.remove_at(best_request_index)

static func _extract_pose_wrists(pose_landmarks: Array) -> Dictionary:
	var wrists := {
		_HAND_SIDE_LEFT: {},
		_HAND_SIDE_RIGHT: {}
	}
	for landmark_variant in pose_landmarks:
		if not landmark_variant is Dictionary:
			continue
		var landmark: Dictionary = landmark_variant
		var landmark_id := int(landmark.get("id", -1))
		if landmark_id == _POSE_LEFT_WRIST_ID:
			wrists[_HAND_SIDE_LEFT] = {"x": float(landmark.get("x", 0.0)), "y": float(landmark.get("y", 0.0))}
		elif landmark_id == _POSE_RIGHT_WRIST_ID:
			wrists[_HAND_SIDE_RIGHT] = {"x": float(landmark.get("x", 0.0)), "y": float(landmark.get("y", 0.0))}
	return wrists

static func _nearest_candidate_index(candidates: Array, candidate_indices: Array, target: Dictionary) -> int:
	var best_index := -1
	var best_distance := INF
	for candidate_index_variant in candidate_indices:
		var candidate_index := int(candidate_index_variant)
		if candidate_index < 0 or candidate_index >= candidates.size():
			continue
		var candidate: Dictionary = candidates[candidate_index]
		var anchor: Dictionary = candidate.get("anchor", {}) if candidate.get("anchor", {}) is Dictionary else {}
		if anchor.is_empty():
			continue
		var distance := _distance_between_points(target, anchor)
		if distance < best_distance:
			best_distance = distance
			best_index = candidate_index
	return best_index

static func _distance_between_points(a: Dictionary, b: Dictionary) -> float:
	if a.is_empty() or b.is_empty():
		return INF
	var dx := float(a.get("x", 0.0)) - float(b.get("x", 0.0))
	var dy := float(a.get("y", 0.0)) - float(b.get("y", 0.0))
	return sqrt((dx * dx) + (dy * dy))

static func _association_from_candidate(side: String, candidate: Dictionary, assignment: Dictionary) -> Dictionary:
	var association := _empty_association(side)
	association["assigned"] = true
	association["method"] = str(assignment.get("method", "none"))
	association["source_hand_index"] = int(candidate.get("source_hand_index", -1))
	association["source_label"] = str(candidate.get("source_label", ""))
	association["source_score"] = float(candidate.get("source_score", 0.0))
	if assignment.has("distance"):
		association["distance"] = float(assignment.get("distance", 0.0))
	return association

static func _hand_payload_anchor(payload: Dictionary) -> Dictionary:
	var landmarks := payload.get("landmarks", []) if payload.get("landmarks", []) is Array else []
	var bbox := payload.get("bbox", {}) if payload.get("bbox", {}) is Dictionary else _empty_bbox()
	return _hand_candidate_anchor(landmarks, bbox)

static func _has_prior_hand_sample(payload: Dictionary) -> bool:
	var landmarks := payload.get("landmarks", []) if payload.get("landmarks", []) is Array else []
	if landmarks.is_empty() == false:
		return true
	var bbox := payload.get("bbox", {}) if payload.get("bbox", {}) is Dictionary else {}
	return float(bbox.get("area", 0.0)) > 0.0


static func _tracked_hand_payload_from_candidate(
	side: String,
	candidate: Dictionary,
	assignment: Dictionary,
	hand_tracking: Dictionary,
	previous_payload: Dictionary,
	frame_index: int,
	timestamp_seconds: float
) -> Dictionary:
	var stable_valid_frames: int = 1
	if _has_prior_hand_sample(previous_payload):
		stable_valid_frames = int(previous_payload.get("_stable_valid_frames", 0)) + 1
	var reacquire_frames: int = max(1, int(hand_tracking.get("reacquire_stable_frames", 1)))
	var tracking_valid: bool = stable_valid_frames >= reacquire_frames
	var tracking_state: String = "tracked" if tracking_valid else "reacquiring"
	var bbox: Dictionary = candidate.get("bbox", _empty_bbox()).duplicate(true)
	return {
		"tracking_valid": tracking_valid,
		"tracking_state": tracking_state,
		"landmark_mode": str(hand_tracking.get("landmark_mode", CameraTrackingConfig.DEFAULT_HAND_LANDMARK_MODE)),
		"frame_index": frame_index,
		"timestamp_seconds": timestamp_seconds,
		"stale_frames": 0,
		"grace_frames": 0,
		"predicted": false,
		"association": _association_from_candidate(side, candidate, assignment),
		"landmarks": candidate.get("landmarks", []).duplicate(true),
		"bbox": bbox,
		"_stable_valid_frames": stable_valid_frames,
		"_pose_side_locked": bool(assignment.get("pose_side_locked", false)),
		"_bbox_position_delta": _bbox_position_delta(previous_payload, bbox),
		"_bbox_size_delta": _bbox_size_delta(previous_payload, bbox)
	}

static func _predict_grace_hand_payload(
	side: String,
	previous_payload: Dictionary,
	hand_tracking: Dictionary,
	frame_index: int,
	timestamp_seconds: float,
	stale_frames: int
) -> Dictionary:
	var grace: Dictionary = hand_tracking.get("grace", {}) if hand_tracking.get("grace", {}) is Dictionary else {}
	var previous_bbox: Dictionary = previous_payload.get("bbox", {}) if previous_payload.get("bbox", {}) is Dictionary else _empty_bbox()
	var position_delta := previous_payload.get("_bbox_position_delta", {"x": 0.0, "y": 0.0}) if previous_payload.get("_bbox_position_delta", {"x": 0.0, "y": 0.0}) is Dictionary else {"x": 0.0, "y": 0.0}
	var size_delta := previous_payload.get("_bbox_size_delta", {"width": 0.0, "height": 0.0}) if previous_payload.get("_bbox_size_delta", {"width": 0.0, "height": 0.0}) is Dictionary else {"width": 0.0, "height": 0.0}
	var predicted_bbox := _predict_bbox(previous_bbox, position_delta, size_delta)
	return {
		"tracking_valid": true,
		"tracking_state": "grace",
		"landmark_mode": str(previous_payload.get("landmark_mode", hand_tracking.get("landmark_mode", CameraTrackingConfig.DEFAULT_HAND_LANDMARK_MODE))),
		"frame_index": frame_index,
		"timestamp_seconds": timestamp_seconds,
		"stale_frames": stale_frames,
		"grace_frames": stale_frames,
		"predicted": true,
		"association": previous_payload.get("association", _empty_association(side)).duplicate(true),
		"landmarks": _predict_landmarks(previous_payload.get("landmarks", []) if previous_payload.get("landmarks", []) is Array else [], previous_bbox, predicted_bbox),
		"bbox": predicted_bbox,
		"_stable_valid_frames": int(previous_payload.get("_stable_valid_frames", 0)),
		"_pose_side_locked": bool(previous_payload.get("_pose_side_locked", false)),
		"_bbox_position_delta": _decay_bbox_position_delta(position_delta, float(grace.get("position_decay", CameraTrackingConfig.DEFAULT_HAND_GRACE_POSITION_DECAY))),
		"_bbox_size_delta": _decay_bbox_size_delta(size_delta, float(grace.get("size_decay", CameraTrackingConfig.DEFAULT_HAND_GRACE_SIZE_DECAY)))
	}

static func _bbox_position_delta(previous_payload: Dictionary, bbox: Dictionary) -> Dictionary:
	var previous_bbox: Dictionary = previous_payload.get("bbox", {}) if previous_payload.get("bbox", {}) is Dictionary else {}
	if float(previous_bbox.get("area", 0.0)) <= 0.0:
		return {"x": 0.0, "y": 0.0}
	return {
		"x": float(bbox.get("x", 0.0)) - float(previous_bbox.get("x", 0.0)),
		"y": float(bbox.get("y", 0.0)) - float(previous_bbox.get("y", 0.0))
	}

static func _bbox_size_delta(previous_payload: Dictionary, bbox: Dictionary) -> Dictionary:
	var previous_bbox: Dictionary = previous_payload.get("bbox", {}) if previous_payload.get("bbox", {}) is Dictionary else {}
	if float(previous_bbox.get("area", 0.0)) <= 0.0:
		return {"width": 0.0, "height": 0.0}
	return {
		"width": float(bbox.get("width", 0.0)) - float(previous_bbox.get("width", 0.0)),
		"height": float(bbox.get("height", 0.0)) - float(previous_bbox.get("height", 0.0))
	}

static func _predict_bbox(previous_bbox: Dictionary, position_delta: Dictionary, size_delta: Dictionary) -> Dictionary:
	return _normalize_bbox({
		"x": float(previous_bbox.get("x", 0.0)) + float(position_delta.get("x", 0.0)),
		"y": float(previous_bbox.get("y", 0.0)) + float(position_delta.get("y", 0.0)),
		"width": maxf(0.0, float(previous_bbox.get("width", 0.0)) + float(size_delta.get("width", 0.0))),
		"height": maxf(0.0, float(previous_bbox.get("height", 0.0)) + float(size_delta.get("height", 0.0)))
	}, false)

static func _predict_landmarks(landmarks: Array, previous_bbox: Dictionary, predicted_bbox: Dictionary) -> Array:
	if landmarks.is_empty():
		return []
	if float(previous_bbox.get("area", 0.0)) <= 0.0 or float(predicted_bbox.get("area", 0.0)) <= 0.0:
		return landmarks.duplicate(true)
	var previous_center_x := float(previous_bbox.get("x", 0.0)) + (float(previous_bbox.get("width", 0.0)) * 0.5)
	var previous_center_y := float(previous_bbox.get("y", 0.0)) + (float(previous_bbox.get("height", 0.0)) * 0.5)
	var predicted_center_x := float(predicted_bbox.get("x", 0.0)) + (float(predicted_bbox.get("width", 0.0)) * 0.5)
	var predicted_center_y := float(predicted_bbox.get("y", 0.0)) + (float(predicted_bbox.get("height", 0.0)) * 0.5)
	var scale_x := float(predicted_bbox.get("width", 0.0)) / maxf(float(previous_bbox.get("width", 0.0)), 0.000001)
	var scale_y := float(predicted_bbox.get("height", 0.0)) / maxf(float(previous_bbox.get("height", 0.0)), 0.000001)
	var predicted: Array = []
	for landmark_variant in landmarks:
		if not landmark_variant is Dictionary:
			continue
		var landmark: Dictionary = (landmark_variant as Dictionary).duplicate(true)
		landmark["x"] = _normalize_unit_coordinate(predicted_center_x + ((float(landmark.get("x", 0.0)) - previous_center_x) * scale_x))
		landmark["y"] = _normalize_unit_coordinate(predicted_center_y + ((float(landmark.get("y", 0.0)) - previous_center_y) * scale_y))
		predicted.append(landmark)
	return predicted

static func _decay_bbox_position_delta(position_delta: Dictionary, decay: float) -> Dictionary:
	return {
		"x": float(position_delta.get("x", 0.0)) * clampf(decay, 0.0, 1.0),
		"y": float(position_delta.get("y", 0.0)) * clampf(decay, 0.0, 1.0)
	}

static func _decay_bbox_size_delta(size_delta: Dictionary, decay: float) -> Dictionary:
	return {
		"width": float(size_delta.get("width", 0.0)) * clampf(decay, 0.0, 1.0),
		"height": float(size_delta.get("height", 0.0)) * clampf(decay, 0.0, 1.0)
	}
