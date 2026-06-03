class_name CameraTrackingCameraOptions
extends RefCounted

const _SELECTION_POLICY_MAP := {
	"framerate_first_resolution_second_format_backend": "framerate_first_resolution_second_format"
}

const _REPORTED_SOURCE_MAP := {
	"reported_v4l2": "device_report",
	"v4l2_empty": "device_report_empty",
	"v4l2_failed": "device_report_failed",
	"fallback_probe_sweep": "probe_sweep",
	"unavailable": "unknown"
}

const _PROBE_STRATEGY_MAP := {
	"reported_v4l2_ranked_shortlist": "reported_shortlist",
	"fallback_probe_sweep": "probe_sweep"
}

static func empty(config: Dictionary = {}, camera_id: String = "") -> Dictionary:
	var normalized := CameraTrackingConfig.normalize(config)
	var source: Dictionary = normalized.get("source", {})
	var requested_camera_id := camera_id if camera_id != "" else str(source.get("camera_id", ""))
	var backend_request := CameraTrackingConfig.normalize_requested_backend(normalized.get("backend", CameraTrackingConfig.DEFAULT_BACKEND))
	var backend_impl := CameraTrackingConfig.resolve_backend_id(backend_request)
	return {
		"camera_id": requested_camera_id,
		"backend_request": backend_request,
		"backend_impl": backend_impl,
		"selection_policy": "framerate_first_resolution_second_format",
		"reported_source": "unknown",
		"probe_strategy": "none",
		"requested_mode": _empty_mode(),
		"reported_modes": [],
		"probed_modes": [],
		"selected_mode": {},
		"actual_mode": {},
		"notes": []
	}

static func normalize(camera_options: Dictionary, config: Dictionary = {}, camera_id: String = "") -> Dictionary:
	var normalized := empty(config, camera_id)
	if camera_options.is_empty():
		return normalized

	var requested: Dictionary = camera_options.get("requested", {}) if camera_options.get("requested", {}) is Dictionary else {}
	if normalized["camera_id"] == "":
		normalized["camera_id"] = str(requested.get("camera_id", normalized.get("camera_id", "")))
	normalized["selection_policy"] = _normalize_selection_policy(camera_options.get("selection_policy", normalized.get("selection_policy", "")))
	normalized["reported_source"] = _normalize_reported_source(camera_options.get("reported_source", normalized.get("reported_source", "unknown")))
	normalized["probe_strategy"] = _normalize_probe_strategy(camera_options.get("probe_strategy", normalized.get("probe_strategy", "none")))
	normalized["requested_mode"] = _normalize_mode(requested, true)
	normalized["reported_modes"] = _normalize_reported_modes(camera_options.get("reported_options", []))
	normalized["probed_modes"] = _normalize_probed_modes(camera_options.get("probed_options", []))
	normalized["selected_mode"] = _normalize_optional_mode(camera_options.get("selected", {}))
	normalized["actual_mode"] = _normalize_optional_mode(camera_options.get("actual", {}))
	normalized["notes"] = _normalize_notes(camera_options.get("notes", []))
	return normalized

static func _normalize_selection_policy(value: Variant) -> String:
	var normalized := str(value).strip_edges()
	if normalized == "":
		return "framerate_first_resolution_second_format"
	return str(_SELECTION_POLICY_MAP.get(normalized, normalized))

static func _normalize_reported_source(value: Variant) -> String:
	var normalized := str(value).strip_edges()
	if normalized == "":
		return "unknown"
	return str(_REPORTED_SOURCE_MAP.get(normalized, normalized))

static func _normalize_probe_strategy(value: Variant) -> String:
	var normalized := str(value).strip_edges()
	if normalized == "":
		return "none"
	return str(_PROBE_STRATEGY_MAP.get(normalized, normalized))

static func _normalize_reported_modes(reported_options: Variant) -> Array:
	var normalized: Array = []
	if not (reported_options is Array):
		return normalized
	for option_variant in reported_options:
		if not (option_variant is Dictionary):
			continue
		normalized.append(_normalize_mode(option_variant))
	return normalized

static func _normalize_probed_modes(probed_options: Variant) -> Array:
	var normalized: Array = []
	if not (probed_options is Array):
		return normalized
	for option_variant in probed_options:
		if not (option_variant is Dictionary):
			continue
		var option: Dictionary = option_variant
		normalized.append({
			"requested_mode": _normalize_mode(option.get("requested", {}), true),
			"selected_mode": _normalize_optional_mode(option.get("selected", {})),
			"actual_mode": _normalize_optional_mode(option.get("actual", {})),
			"fulfilled": bool(option.get("fulfilled_request", false))
		})
	return normalized

static func _normalize_optional_mode(mode_variant: Variant) -> Dictionary:
	if not (mode_variant is Dictionary):
		return {}
	var normalized := _normalize_mode(mode_variant)
	if normalized == _empty_mode():
		return {}
	return normalized

static func _normalize_mode(mode_variant: Variant, keep_empty: bool = false) -> Dictionary:
	if not (mode_variant is Dictionary):
		return _empty_mode() if keep_empty else {}
	var mode: Dictionary = mode_variant
	var normalized := {
		"width": int(mode.get("width", 0)),
		"height": int(mode.get("height", 0)),
		"fps": float(mode.get("fps", 0.0)),
		"pixel_format": _normalize_pixel_format(mode)
	}
	if keep_empty:
		return normalized
	if normalized == _empty_mode():
		return {}
	return normalized

static func _normalize_pixel_format(mode: Dictionary) -> String:
	var pixel_format := str(mode.get("pixel_format", mode.get("fourcc", mode.get("format", "")))).strip_edges()
	return pixel_format.to_upper()

static func _normalize_notes(notes_variant: Variant) -> Array:
	var normalized: Array = []
	if not (notes_variant is Array):
		return normalized
	for note_variant in notes_variant:
		var note := str(note_variant).strip_edges()
		if note != "":
			normalized.append(note)
	return normalized

static func _empty_mode() -> Dictionary:
	return {
		"width": 0,
		"height": 0,
		"fps": 0.0,
		"pixel_format": ""
	}
