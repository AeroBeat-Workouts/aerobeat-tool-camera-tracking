class_name SavedSessionReplayBackend
extends CameraTrackingBackend

const SessionManifestV1 = preload("res://addons/aerobeat-tool-camera-recording/src/manifest/SessionManifestV1.gd")
const SavedSessionValidator = preload("res://addons/aerobeat-tool-camera-recording/src/validation/SavedSessionValidator.gd")
const PoseFrameRecord = preload("res://addons/aerobeat-tool-camera-recording/src/pose/PoseFrameRecord.gd")

const BACKEND_ID := "saved_session_replay"
const REPLAY_INPUT_KIND := "session_manifest"
const REPLAY_MODE := "saved_tracking_frames"

var _state: String = CameraTracking.STATE_IDLE
var _detail: Dictionary = CameraTrackingConfig.make_state_detail()
var _active_config: Dictionary = CameraTrackingConfig.defaults()
var _preview_descriptor: Dictionary = CameraTrackingPreview.detached()
var _tracking_frame: Dictionary = CameraTrackingFrame.empty()
var _playback_status: Dictionary = {}
var _manifest: Dictionary = {}
var _manifest_path := ""
var _session_root := ""
var _entrypoint_path := ""
var _source_id := ""
var _frames: Array[Dictionary] = []
var _current_frame_index := 0
var _paused := false
var _playback_anchor_ticks_ms := 0
var _playback_anchor_source_ms := 0
var _nominal_fps := 0.0
var _frame_duration_sec := 0.0

func get_backend_id() -> String:
	return BACKEND_ID

func start(config: Dictionary) -> void:
	_active_config = CameraTrackingConfig.normalize(config)
	var preview: Dictionary = _active_config.get("preview", {}) if _active_config.get("preview", {}) is Dictionary else {}
	preview["flip_horizontal"] = false
	_active_config["preview"] = preview
	_preview_descriptor = CameraTrackingPreview.detached(_active_config)
	_preview_descriptor["backend"] = BACKEND_ID
	var load_result := _load_saved_session(_active_config)
	if not bool(load_result.get("ok", false)):
		_fail_with(load_result.get("error_info", {}))
		return
	_state = CameraTracking.STATE_RUNNING
	_detail = CameraTrackingConfig.make_state_detail({
		"backend_ready": true,
		"preview_ready": bool(_active_config.get("preview", {}).get("enabled", true)),
		"tracking_ready": true,
		"source_ready": true,
	})
	_paused = false
	_set_current_frame_index(0)
	_reset_play_anchor()
	emit_signal("preview_changed", _preview_descriptor.duplicate(true))
	emit_signal("tracking_updated", get_tracking_frame())
	emit_signal("state_changed", _state, _detail.duplicate(true))

func stop() -> void:
	_paused = true
	_state = CameraTracking.STATE_IDLE
	_detail = CameraTrackingConfig.make_state_detail()
	emit_signal("state_changed", _state, _detail.duplicate(true))

func change(config: Dictionary) -> void:
	start(config)

func get_state() -> Dictionary:
	return {
		"state": _state,
		"detail": _detail.duplicate(true)
	}

func get_tracking_frame() -> Dictionary:
	if _state == CameraTracking.STATE_RUNNING:
		_advance_playback_to_now()
	return _tracking_frame.duplicate(true)

func get_preview_descriptor() -> Dictionary:
	return _preview_descriptor.duplicate(true)

func get_playback_status() -> Dictionary:
	if _state == CameraTracking.STATE_RUNNING:
		_advance_playback_to_now()
	return _playback_status.duplicate(true)

func get_replay_transport_capabilities() -> Dictionary:
	return {
		"transport_mode": CameraTracking.TRANSPORT_MODE_EXACT_OWNED_FRAME_INDEX,
		"can_step_forward": true,
		"can_step_backward": true,
		"can_seek_frame": true,
		"nominal_fps": _nominal_fps if _nominal_fps > 0.0 else null,
		"frame_duration_sec": _frame_duration_sec if _frame_duration_sec > 0.0 else null,
		"exactness_note": "Saved-session replay owns an exact frame index backed by tracking/pose_frames.jsonl.",
		"limitation_code": "",
	}

func get_replay_transport_status() -> Dictionary:
	if _state == CameraTracking.STATE_RUNNING:
		_advance_playback_to_now()
	return {
		"transport_mode": CameraTracking.TRANSPORT_MODE_EXACT_OWNED_FRAME_INDEX,
		"can_step_forward": true,
		"can_step_backward": true,
		"can_seek_frame": true,
		"frame_index": _current_frame_index,
		"frame_count": _frames.size(),
		"nominal_fps": _nominal_fps if _nominal_fps > 0.0 else null,
		"frame_duration_sec": _frame_duration_sec if _frame_duration_sec > 0.0 else null,
		"paused": _paused,
		"position_sec": float(_tracking_frame.get("timestamp_seconds", 0.0)),
		"duration_sec": _duration_sec(),
		"exactness_note": "Saved-session replay is served directly from manifest-declared pose frames.",
		"limitation_code": "",
	}

func play_replay() -> Dictionary:
	if _frames.is_empty():
		return _playback_failure("saved_session_empty", "Saved-session replay has no pose frames to play.")
	_advance_playback_to_now()
	_paused = false
	_reset_play_anchor()
	_refresh_playback_status()
	return {
		RESULT_SUCCESS: true,
		"paused": _paused,
		"frame_index": _current_frame_index,
	}

func pause_replay() -> Dictionary:
	if _frames.is_empty():
		return _playback_failure("saved_session_empty", "Saved-session replay has no pose frames to pause.")
	_advance_playback_to_now()
	_paused = true
	_refresh_playback_status()
	return {
		RESULT_SUCCESS: true,
		"paused": _paused,
		"frame_index": _current_frame_index,
	}

func step_replay_frames(delta_frames: int) -> Dictionary:
	if _frames.is_empty():
		return _playback_failure("saved_session_empty", "Saved-session replay has no pose frames to step.")
	var target_index := clampi(_current_frame_index + delta_frames, 0, maxi(_frames.size() - 1, 0))
	return seek_replay_to_frame(target_index)

func seek_replay_to_frame(frame_index: int) -> Dictionary:
	if _frames.is_empty():
		return _playback_failure("saved_session_empty", "Saved-session replay has no pose frames to seek.")
	_paused = true
	_set_current_frame_index(frame_index)
	emit_signal("tracking_updated", _tracking_frame.duplicate(true))
	return {
		RESULT_SUCCESS: true,
		"paused": _paused,
		"frame_index": _current_frame_index,
		"position_sec": float(_tracking_frame.get("timestamp_seconds", 0.0)),
	}

func _load_saved_session(config: Dictionary) -> Dictionary:
	_manifest = {}
	_manifest_path = ""
	_session_root = ""
	_entrypoint_path = ""
	_source_id = ""
	_frames.clear()
	_current_frame_index = 0
	_nominal_fps = 0.0
	_frame_duration_sec = 0.0
	_tracking_frame = CameraTrackingFrame.empty(config)
	_playback_status = {}

	var source: Dictionary = config.get("source", {}) if config.get("source", {}) is Dictionary else {}
	_manifest_path = ProjectSettings.globalize_path(str(source.get("path", "")).strip_edges())
	if _manifest_path == "":
		return _load_failure("session_manifest_path_missing", "Saved-session replay requires source.path to point at session_manifest.json")
	if not FileAccess.file_exists(_manifest_path):
		return _load_failure("session_manifest_missing", "Saved-session manifest not found at '%s'" % _manifest_path)

	_session_root = _manifest_path.get_base_dir()
	var validation := SavedSessionValidator.validate_session_root(_session_root)
	if not bool(validation.get("ok", false)):
		return _load_failure("saved_session_invalid", "Saved-session package failed validation", {
			"validation": validation.duplicate(true),
		})

	var manifest_file := FileAccess.open(_manifest_path, FileAccess.READ)
	if manifest_file == null:
		return _load_failure("session_manifest_unreadable", "Failed to open saved-session manifest '%s'" % _manifest_path)
	var manifest_parse := JSON.new()
	if manifest_parse.parse(manifest_file.get_as_text()) != OK or not (manifest_parse.data is Dictionary):
		return _load_failure("session_manifest_parse_failed", "Saved-session manifest '%s' is not valid JSON" % _manifest_path)
	_manifest = SessionManifestV1.normalize(manifest_parse.data)
	var replay_contract: Dictionary = _manifest.get("replay_contract", {}) if _manifest.get("replay_contract", {}) is Dictionary else {}
	if str(replay_contract.get("replay_mode", "")) != REPLAY_MODE:
		return _load_failure("unsupported_replay_mode", "Saved-session manifest declares replay_mode '%s', but this backend only supports '%s'" % [str(replay_contract.get("replay_mode", "")), REPLAY_MODE])

	_entrypoint_path = _session_root.path_join(str(replay_contract.get("entrypoint", "")))
	_source_id = _resolve_source_id()
	var load_frames := _load_pose_frames(_entrypoint_path)
	if not bool(load_frames.get("ok", false)):
		return load_frames
	_frames = load_frames.get("frames", [])
	_nominal_fps = _infer_nominal_fps(_frames)
	_frame_duration_sec = (1.0 / _nominal_fps) if _nominal_fps > 0.0 else 0.0
	return {"ok": true}

func _load_pose_frames(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _load_failure("pose_frames_missing", "Saved-session replay entrypoint not found at '%s'" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _load_failure("pose_frames_unreadable", "Failed to open pose-frame stream '%s'" % path)
	var frames: Array[Dictionary] = []
	var line_number := 0
	while not file.eof_reached():
		var line := file.get_line()
		line_number += 1
		if line.strip_edges() == "":
			continue
		var parsed := JSON.new()
		if parsed.parse(line) != OK or not (parsed.data is Dictionary):
			return _load_failure("pose_frames_parse_failed", "Failed to parse pose-frame JSONL line %d" % line_number)
		var pose_frame: Dictionary = PoseFrameRecord.normalize(parsed.data)
		frames.append(_map_pose_frame_to_tracking_frame(pose_frame))
	if frames.is_empty():
		return _load_failure("pose_frames_empty", "Saved-session pose-frame stream is empty")
	return {"ok": true, "frames": frames}

func _map_pose_frame_to_tracking_frame(pose_frame: Dictionary) -> Dictionary:
	var frame_size: Dictionary = pose_frame.get("frame_size", {}) if pose_frame.get("frame_size", {}) is Dictionary else {}
	var mapped := {
		"timestamp_ms": int(pose_frame.get("timestamp_ms", 0)),
		"timestamp_seconds": float(pose_frame.get("timestamp_seconds", 0.0)),
		"frame_index": int(pose_frame.get("frame_index", 0)),
		"backend": BACKEND_ID,
		"backend_request": BACKEND_ID,
		"backend_impl": BACKEND_ID,
		"source_kind": str(_manifest.get("source_kind", "fixture_replay")),
		"source_id": _source_id,
		"tracking_state": str(pose_frame.get("tracking_state", "idle")),
		"landmarks": [],
	}
	if not frame_size.is_empty():
		mapped["frame_size"] = {
			"x": int(frame_size.get("width", 0)),
			"y": int(frame_size.get("height", 0)),
		}
	if pose_frame.has("source_timestamp_ms"):
		mapped["source_timestamp_ms"] = int(pose_frame.get("source_timestamp_ms", 0))
	var pose_landmarks: Array = pose_frame.get("landmarks", []) if pose_frame.get("landmarks", []) is Array else []
	for landmark_variant in pose_landmarks:
		if landmark_variant is Dictionary:
			mapped["landmarks"].append((landmark_variant as Dictionary).duplicate(true))
	return mapped

func _resolve_source_id() -> String:
	var source_contract: Dictionary = _manifest.get("source_contract", {}) if _manifest.get("source_contract", {}) is Dictionary else {}
	var source_path := str(source_contract.get("source_path", "")).strip_edges()
	if source_path != "":
		return source_path
	return _manifest_path

func _infer_nominal_fps(frames: Array[Dictionary]) -> float:
	if frames.size() < 2:
		return 0.0
	var total_delta_ms := 0.0
	var interval_count := 0
	for index in range(1, frames.size()):
		var previous_timestamp := int(frames[index - 1].get("timestamp_ms", 0))
		var timestamp_ms := int(frames[index].get("timestamp_ms", 0))
		var delta_ms := timestamp_ms - previous_timestamp
		if delta_ms > 0:
			total_delta_ms += float(delta_ms)
			interval_count += 1
	if interval_count <= 0:
		return 0.0
	var average_delta_ms := total_delta_ms / float(interval_count)
	if average_delta_ms <= 0.0:
		return 0.0
	return 1000.0 / average_delta_ms

func _duration_sec() -> float:
	if _frames.is_empty():
		return 0.0
	return float(_frames.back().get("timestamp_seconds", 0.0))

func _advance_playback_to_now() -> void:
	if _frames.is_empty() or _paused:
		_refresh_playback_status()
		return
	var elapsed_ms := maxi(Time.get_ticks_msec() - _playback_anchor_ticks_ms, 0)
	var target_timestamp_ms := _playback_anchor_source_ms + elapsed_ms
	var target_index := _current_frame_index
	for index in range(_current_frame_index, _frames.size()):
		if int(_frames[index].get("timestamp_ms", 0)) <= target_timestamp_ms:
			target_index = index
			continue
		break
	_set_current_frame_index(target_index)
	if _current_frame_index >= _frames.size() - 1 and target_timestamp_ms > int(_frames.back().get("timestamp_ms", 0)):
		_paused = true
	_refresh_playback_status()

func _set_current_frame_index(frame_index: int) -> void:
	if _frames.is_empty():
		_current_frame_index = 0
		_tracking_frame = CameraTrackingFrame.empty(_active_config)
		_refresh_playback_status()
		return
	_current_frame_index = clampi(frame_index, 0, maxi(_frames.size() - 1, 0))
	_tracking_frame = _frames[_current_frame_index].duplicate(true)
	_refresh_playback_status()

func _reset_play_anchor() -> void:
	_playback_anchor_ticks_ms = Time.get_ticks_msec()
	_playback_anchor_source_ms = int(_tracking_frame.get("timestamp_ms", 0))

func _refresh_playback_status() -> void:
	var current_time_sec := float(_tracking_frame.get("timestamp_seconds", 0.0))
	var duration_sec := _duration_sec()
	var state := "paused" if _paused else "playing"
	if _current_frame_index >= _frames.size() - 1 and _paused:
		state = "ended" if current_time_sec >= duration_sec else "paused"
	var progress := 0.0
	if duration_sec > 0.0:
		progress = minf(maxf(current_time_sec / duration_sec, 0.0), 1.0)
	_playback_status = {
		"source": _manifest_path,
		"state": state,
		"paused": _paused,
		"current_time_sec": current_time_sec,
		"duration_sec": duration_sec,
		"progress": progress,
		"is_file_source": true,
		"replay_input_kind": REPLAY_INPUT_KIND,
		"replay_mode": REPLAY_MODE,
		"manifest_path": _manifest_path,
		"entrypoint": _entrypoint_path,
		"frame_index": _current_frame_index,
		"frame_count": _frames.size(),
		"can_seek": true,
		"can_pause": true,
	}

func _playback_failure(code: String, message: String, detail: Dictionary = {}) -> Dictionary:
	return {
		RESULT_SUCCESS: false,
		RESULT_CODE: code,
		RESULT_MESSAGE: message,
		RESULT_DETAIL: detail.duplicate(true),
	}

func _load_failure(code: String, message: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"error_info": {
			"code": code,
			"message": message,
			"backend": BACKEND_ID,
			"detail": detail.duplicate(true),
		}
	}

func _fail_with(error_info: Dictionary) -> void:
	_state = CameraTracking.STATE_ERROR
	_detail = CameraTrackingConfig.make_state_detail()
	emit_signal("state_changed", _state, _detail.duplicate(true))
	emit_signal("error_raised", error_info.duplicate(true))
