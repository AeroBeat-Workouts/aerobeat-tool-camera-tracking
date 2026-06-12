class_name SessionManifestReplayBackend
extends CameraTrackingBackend

const SessionManifestV1 = preload("res://addons/aerobeat-tool-camera-recording/src/manifest/SessionManifestV1.gd")
const SavedSessionValidator = preload("res://addons/aerobeat-tool-camera-recording/src/validation/SavedSessionValidator.gd")

const BACKEND_ID := "session_manifest_replay"
const REPLAY_INPUT_KIND := "session_manifest"
const REPLAY_MODE_SAVED_TRACKING_FRAMES := "saved_tracking_frames"
const REPLAY_MODE_VIDEO_REINFERENCE := "video_reinference"
const _MEDIAPIPE_PYTHON_BACKEND_ID := "mediapipe_python"
const _MEDIAPIPE_PYTHON_BACKEND_SCRIPT_PATH := "res://addons/aerobeat-vendor-mediapipe-python/src/MediaPipePythonCameraTrackingBackend.gd"
const _MEDIAPIPE_PYTHON_RUNTIME_BRIDGE_SCRIPT_PATH := "res://addons/aerobeat-vendor-mediapipe-python/src/MediaPipePythonRuntimeBridge.gd"
const _SAVED_SESSION_REPLAY_BACKEND_ID := "saved_session_replay"
const _SAVED_SESSION_REPLAY_BACKEND_SCRIPT_PATH := "res://addons/aerobeat-tool-camera-tracking/src/SavedSessionReplayBackend.gd"

var _delegate: CameraTrackingBackend = null
var _active_config: Dictionary = CameraTrackingConfig.defaults()
var _manifest: Dictionary = {}
var _manifest_path := ""
var _session_root := ""
var _replay_mode := ""
var _entrypoint_path := ""
var _artifacts: Dictionary = {}
var _source_contract: Dictionary = {}
var _truth_contract: Dictionary = {}
var _session_source_kind := ""
var _delegate_backend_id := ""

func get_backend_id() -> String:
	return BACKEND_ID

func start(config: Dictionary) -> void:
	_active_config = CameraTrackingConfig.normalize(config)
	var load_result := _load_manifest(_active_config)
	if not bool(load_result.get("ok", false)):
		_fail_with(load_result.get("error_info", {}))
		return
	var delegate_result := _create_delegate(_active_config)
	if not bool(delegate_result.get("ok", false)):
		_fail_with(delegate_result.get("error_info", {}))
		return
	_connect_delegate(_delegate)
	_delegate.start(delegate_result.get("config", {}))

func stop() -> void:
	if _delegate != null:
		_delegate.stop()

func change(config: Dictionary) -> void:
	_active_config = CameraTrackingConfig.normalize(config)
	var load_result := _load_manifest(_active_config)
	if not bool(load_result.get("ok", false)):
		_fail_with(load_result.get("error_info", {}))
		return
	var delegate_result := _create_delegate(_active_config)
	if not bool(delegate_result.get("ok", false)):
		_fail_with(delegate_result.get("error_info", {}))
		return
	var next_config: Dictionary = delegate_result.get("config", {})
	if _delegate != null and _delegate_backend_id == str(delegate_result.get("delegate_backend_id", "")):
		_delegate.change(next_config)
		return
	_disconnect_delegate(_delegate)
	if _delegate != null:
		_delegate.stop()
	_delegate = null
	_delegate_backend_id = ""
	var recreate_result := _create_delegate(_active_config)
	if not bool(recreate_result.get("ok", false)):
		_fail_with(recreate_result.get("error_info", {}))
		return
	_connect_delegate(_delegate)
	_delegate.start(recreate_result.get("config", {}))

func list_cameras() -> Array:
	return _delegate.list_cameras().duplicate(true) if _delegate != null else []

func get_state() -> Dictionary:
	return _delegate.get_state().duplicate(true) if _delegate != null else {
		"state": CameraTracking.STATE_IDLE,
		"detail": CameraTrackingConfig.make_state_detail(),
	}

func get_tracking_frame() -> Dictionary:
	if _delegate == null:
		return CameraTrackingFrame.empty(_active_config)
	return _overlay_tracking_frame(_delegate.get_tracking_frame())

func get_preview_descriptor() -> Dictionary:
	return _delegate.get_preview_descriptor().duplicate(true) if _delegate != null else CameraTrackingPreview.detached(_active_config)

func get_camera_options(camera_id: String = "") -> Dictionary:
	return _delegate.get_camera_options(camera_id).duplicate(true) if _delegate != null else {}

func get_playback_status() -> Dictionary:
	if _delegate == null:
		return {}
	return _overlay_playback_status(_delegate.get_playback_status())

func get_replay_transport_capabilities() -> Dictionary:
	if _delegate == null:
		return {}
	var capabilities := _delegate.get_replay_transport_capabilities().duplicate(true)
	if _replay_mode == REPLAY_MODE_VIDEO_REINFERENCE:
		capabilities["transport_mode"] = TRANSPORT_MODE_APPROX_TIME_SEEK
		capabilities["can_step_forward"] = false
		capabilities["can_step_backward"] = false
		capabilities["can_seek_frame"] = false
		capabilities["exactness_note"] = "Session-manifest video_reinference routes through the vendor video-file replay lane and only proves approximate time-based transport."
		capabilities["limitation_code"] = TRANSPORT_UNSUPPORTED_CODE
	capabilities["replay_input_kind"] = REPLAY_INPUT_KIND
	capabilities["replay_mode"] = _replay_mode
	capabilities["manifest_path"] = _manifest_path
	capabilities["entrypoint"] = _entrypoint_path
	capabilities["session_source_kind"] = _session_source_kind
	capabilities["delegate_backend"] = _delegate_backend_id
	return capabilities

func get_replay_transport_status() -> Dictionary:
	if _delegate == null:
		return {}
	var playback_status := get_playback_status()
	var capabilities := get_replay_transport_capabilities()
	var status := _delegate.get_replay_transport_status().duplicate(true)
	status["transport_mode"] = str(capabilities.get("transport_mode", TRANSPORT_MODE_APPROX_TIME_SEEK))
	status["can_step_forward"] = bool(capabilities.get("can_step_forward", false))
	status["can_step_backward"] = bool(capabilities.get("can_step_backward", false))
	status["can_seek_frame"] = bool(capabilities.get("can_seek_frame", false))
	status["paused"] = bool(playback_status.get("paused", status.get("paused", false)))
	status["position_sec"] = float(playback_status.get("current_time_sec", status.get("position_sec", 0.0)))
	status["duration_sec"] = float(playback_status.get("duration_sec", status.get("duration_sec", 0.0)))
	status["exactness_note"] = str(capabilities.get("exactness_note", status.get("exactness_note", "")))
	status["limitation_code"] = str(capabilities.get("limitation_code", status.get("limitation_code", REPLAY_TRANSPORT_INACTIVE_CODE)))
	status["replay_input_kind"] = REPLAY_INPUT_KIND
	status["replay_mode"] = _replay_mode
	status["manifest_path"] = _manifest_path
	status["entrypoint"] = _entrypoint_path
	status["session_source_kind"] = _session_source_kind
	status["truth_linked"] = _has_truth_linkage()
	status["source_contract"] = _source_contract.duplicate(true)
	status["truth_contract"] = _truth_contract.duplicate(true)
	status["delegate_backend"] = _delegate_backend_id
	return status

func play_replay() -> Dictionary:
	return _delegate.play_replay().duplicate(true) if _delegate != null else _inactive_transport("play_replay")

func pause_replay() -> Dictionary:
	return _delegate.pause_replay().duplicate(true) if _delegate != null else _inactive_transport("pause_replay")

func step_replay_frames(delta_frames: int) -> Dictionary:
	return _delegate.step_replay_frames(delta_frames).duplicate(true) if _delegate != null else _inactive_transport("step_replay_frames")

func seek_replay_to_frame(frame_index: int) -> Dictionary:
	return _delegate.seek_replay_to_frame(frame_index).duplicate(true) if _delegate != null else _inactive_transport("seek_replay_to_frame")

func _inactive_transport(method_name: String) -> Dictionary:
	return {
		RESULT_SUCCESS: false,
		RESULT_CODE: REPLAY_TRANSPORT_INACTIVE_CODE,
		RESULT_MESSAGE: "%s requires an active session-manifest replay delegate." % method_name,
		RESULT_DETAIL: {
			"replay_input_kind": REPLAY_INPUT_KIND,
			"replay_mode": _replay_mode,
			"manifest_path": _manifest_path,
		}
	}

func _load_manifest(config: Dictionary) -> Dictionary:
	_manifest = {}
	_manifest_path = ""
	_session_root = ""
	_replay_mode = ""
	_entrypoint_path = ""
	_artifacts = {}
	_source_contract = {}
	_truth_contract = {}
	_session_source_kind = ""

	var source: Dictionary = config.get("source", {}) if config.get("source", {}) is Dictionary else {}
	_manifest_path = ProjectSettings.globalize_path(str(source.get("path", "")).strip_edges())
	if _manifest_path == "":
		return _load_failure("session_manifest_path_missing", "Session-manifest replay requires source.path to point at session_manifest.json")
	if not FileAccess.file_exists(_manifest_path):
		return _load_failure("session_manifest_missing", "Session-manifest not found at '%s'" % _manifest_path)

	_session_root = _manifest_path.get_base_dir()
	var validation := SavedSessionValidator.validate_session_root(_session_root)
	if not bool(validation.get("ok", false)):
		return _load_failure("saved_session_invalid", "Saved-session package failed validation", {
			"validation": validation.duplicate(true),
		})

	var manifest_file := FileAccess.open(_manifest_path, FileAccess.READ)
	if manifest_file == null:
		return _load_failure("session_manifest_unreadable", "Failed to open session-manifest '%s'" % _manifest_path)
	var manifest_parse := JSON.new()
	if manifest_parse.parse(manifest_file.get_as_text()) != OK or not (manifest_parse.data is Dictionary):
		return _load_failure("session_manifest_parse_failed", "Session-manifest '%s' is not valid JSON" % _manifest_path)
	_manifest = SessionManifestV1.normalize(manifest_parse.data)
	_artifacts = _manifest.get("artifacts", {}) if _manifest.get("artifacts", {}) is Dictionary else {}
	_source_contract = _manifest.get("source_contract", {}) if _manifest.get("source_contract", {}) is Dictionary else {}
	_truth_contract = _manifest.get("truth_contract", {}) if _manifest.get("truth_contract", {}) is Dictionary else {}
	_session_source_kind = str(_manifest.get("source_kind", "")).strip_edges()
	var replay_contract: Dictionary = _manifest.get("replay_contract", {}) if _manifest.get("replay_contract", {}) is Dictionary else {}
	_replay_mode = str(replay_contract.get("replay_mode", "")).strip_edges()
	if not SessionManifestV1.REPLAY_MODES.has(_replay_mode):
		return _load_failure("unsupported_replay_mode", "Session-manifest replay_mode '%s' is unsupported" % _replay_mode)
	_entrypoint_path = _session_root.path_join(str(replay_contract.get("entrypoint", "")).strip_edges())
	if _entrypoint_path == _session_root.path_join("") or not FileAccess.file_exists(_entrypoint_path):
		return _load_failure("session_manifest_entrypoint_missing", "Session-manifest entrypoint not found at '%s'" % _entrypoint_path, {
			"replay_mode": _replay_mode,
			"manifest_path": _manifest_path,
		})
	return {"ok": true}

func _create_delegate(config: Dictionary) -> Dictionary:
	_disconnect_delegate(_delegate)
	if _delegate != null:
		_delegate = null
	_delegate_backend_id = ""
	match _replay_mode:
		REPLAY_MODE_SAVED_TRACKING_FRAMES:
			var saved_script: Variant = load(_SAVED_SESSION_REPLAY_BACKEND_SCRIPT_PATH)
			if saved_script == null:
				return _load_failure("saved_session_backend_missing", "Saved-session replay backend script was not found", {
					"script_path": _SAVED_SESSION_REPLAY_BACKEND_SCRIPT_PATH,
				})
			var saved_candidate: Variant = saved_script.new()
			if not (saved_candidate is CameraTrackingBackend):
				return _load_failure("saved_session_backend_invalid", "Saved-session replay backend script did not create a CameraTrackingBackend")
			_delegate = saved_candidate
			_delegate_backend_id = _SAVED_SESSION_REPLAY_BACKEND_ID
			return {
				"ok": true,
				"delegate_backend_id": _delegate_backend_id,
				"config": config.duplicate(true),
			}
		REPLAY_MODE_VIDEO_REINFERENCE:
			var backend_script: Variant = load(_MEDIAPIPE_PYTHON_BACKEND_SCRIPT_PATH)
			var runtime_bridge_script: Variant = load(_MEDIAPIPE_PYTHON_RUNTIME_BRIDGE_SCRIPT_PATH)
			if backend_script == null or runtime_bridge_script == null:
				return _load_failure("mediapipe_backend_missing", "MediaPipe Python session-manifest delegate scripts were not found", {
					"backend_script_path": _MEDIAPIPE_PYTHON_BACKEND_SCRIPT_PATH,
					"runtime_bridge_script_path": _MEDIAPIPE_PYTHON_RUNTIME_BRIDGE_SCRIPT_PATH,
				})
			var backend_candidate: Variant = backend_script.new()
			if backend_candidate == null or not (backend_candidate is CameraTrackingBackend):
				return _load_failure("mediapipe_backend_invalid", "MediaPipe Python session-manifest delegate could not be created")
			if backend_candidate.has_method("set_runtime_bridge"):
				backend_candidate.set_runtime_bridge(runtime_bridge_script.new())
			_delegate = backend_candidate
			_delegate_backend_id = _MEDIAPIPE_PYTHON_BACKEND_ID
			var delegate_config := config.duplicate(true)
			delegate_config["backend"] = _MEDIAPIPE_PYTHON_BACKEND_ID
			var source: Dictionary = delegate_config.get("source", {}) if delegate_config.get("source", {}) is Dictionary else {}
			source["kind"] = "video_file"
			source["path"] = _entrypoint_path
			delegate_config["source"] = source
			var runtime: Dictionary = delegate_config.get("runtime", {}) if delegate_config.get("runtime", {}) is Dictionary else {}
			runtime["session_manifest_path"] = _manifest_path
			runtime["session_replay_mode"] = _replay_mode
			delegate_config["runtime"] = runtime
			return {
				"ok": true,
				"delegate_backend_id": _delegate_backend_id,
				"config": delegate_config,
			}
		_:
			return _load_failure("unsupported_replay_mode", "Session-manifest replay_mode '%s' is unsupported" % _replay_mode)

func _connect_delegate(delegate: CameraTrackingBackend) -> void:
	if delegate == null:
		return
	delegate.state_changed.connect(_on_delegate_state_changed)
	delegate.tracking_updated.connect(_on_delegate_tracking_updated)
	delegate.preview_changed.connect(_on_delegate_preview_changed)
	delegate.cameras_changed.connect(_on_delegate_cameras_changed)
	delegate.error_raised.connect(_on_delegate_error_raised)

func _disconnect_delegate(delegate: CameraTrackingBackend) -> void:
	if delegate == null:
		return
	if delegate.state_changed.is_connected(_on_delegate_state_changed):
		delegate.state_changed.disconnect(_on_delegate_state_changed)
	if delegate.tracking_updated.is_connected(_on_delegate_tracking_updated):
		delegate.tracking_updated.disconnect(_on_delegate_tracking_updated)
	if delegate.preview_changed.is_connected(_on_delegate_preview_changed):
		delegate.preview_changed.disconnect(_on_delegate_preview_changed)
	if delegate.cameras_changed.is_connected(_on_delegate_cameras_changed):
		delegate.cameras_changed.disconnect(_on_delegate_cameras_changed)
	if delegate.error_raised.is_connected(_on_delegate_error_raised):
		delegate.error_raised.disconnect(_on_delegate_error_raised)

func _overlay_tracking_frame(frame: Dictionary) -> Dictionary:
	var overlaid := frame.duplicate(true)
	overlaid["replay_input_kind"] = REPLAY_INPUT_KIND
	overlaid["replay_mode"] = _replay_mode
	overlaid["session_manifest_path"] = _manifest_path
	overlaid["session_source_kind"] = _session_source_kind
	overlaid["source_contract"] = _source_contract.duplicate(true)
	overlaid["truth_linked"] = _has_truth_linkage()
	overlaid["truth_contract"] = _truth_contract.duplicate(true)
	overlaid["delegate_backend"] = _delegate_backend_id
	return overlaid

func _overlay_playback_status(status: Dictionary) -> Dictionary:
	var overlaid := status.duplicate(true)
	overlaid["source"] = _manifest_path
	overlaid["manifest_path"] = _manifest_path
	overlaid["entrypoint"] = _entrypoint_path
	overlaid["replay_input_kind"] = REPLAY_INPUT_KIND
	overlaid["replay_mode"] = _replay_mode
	overlaid["source_kind"] = _session_source_kind
	overlaid["session_source_kind"] = _session_source_kind
	overlaid["source_id"] = _resolve_source_id()
	overlaid["source_contract"] = _source_contract.duplicate(true)
	overlaid["truth_linked"] = _has_truth_linkage()
	overlaid["truth_contract"] = _truth_contract.duplicate(true)
	overlaid["delegate_backend"] = _delegate_backend_id
	overlaid["session_root"] = _session_root
	if _replay_mode == REPLAY_MODE_VIDEO_REINFERENCE:
		overlaid["source_video_path"] = _entrypoint_path
	return overlaid

func _resolve_source_id() -> String:
	var source_path := str(_source_contract.get("source_path", "")).strip_edges()
	if source_path != "":
		return source_path
	return _manifest_path

func _has_truth_linkage() -> bool:
	return str(_truth_contract.get("timing_truth_path", "")).strip_edges() != ""

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
	emit_signal("state_changed", CameraTracking.STATE_ERROR, CameraTrackingConfig.make_state_detail())
	emit_signal("error_raised", error_info.duplicate(true))

func _on_delegate_state_changed(state: String, detail: Dictionary) -> void:
	emit_signal("state_changed", state, detail.duplicate(true))

func _on_delegate_tracking_updated(frame: Dictionary) -> void:
	emit_signal("tracking_updated", _overlay_tracking_frame(frame))

func _on_delegate_preview_changed(descriptor: Dictionary) -> void:
	emit_signal("preview_changed", descriptor.duplicate(true))

func _on_delegate_cameras_changed(cameras: Array) -> void:
	emit_signal("cameras_changed", cameras.duplicate(true))

func _on_delegate_error_raised(error_info: Dictionary) -> void:
	var overlaid := error_info.duplicate(true)
	overlaid["manifest_path"] = _manifest_path
	overlaid["replay_input_kind"] = REPLAY_INPUT_KIND
	overlaid["replay_mode"] = _replay_mode
	overlaid["delegate_backend"] = _delegate_backend_id
	emit_signal("error_raised", overlaid)
