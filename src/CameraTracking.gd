class_name CameraTracking
extends Node

signal state_changed(state: String, detail: Dictionary)
signal tracking_updated(frame: Dictionary)
signal preview_changed(descriptor: Dictionary)
signal cameras_changed(cameras: Array)
signal error_raised(error_info: Dictionary)

const VERSION := "0.3.0"

const TRANSPORT_MODE_EXACT_DECODED_FRAME := CameraTrackingBackend.TRANSPORT_MODE_EXACT_DECODED_FRAME
const TRANSPORT_MODE_EXACT_OWNED_FRAME_INDEX := CameraTrackingBackend.TRANSPORT_MODE_EXACT_OWNED_FRAME_INDEX
const TRANSPORT_MODE_APPROX_TIME_SEEK := CameraTrackingBackend.TRANSPORT_MODE_APPROX_TIME_SEEK
const REPLAY_TRANSPORT_UNSUPPORTED_CODE := CameraTrackingBackend.TRANSPORT_UNSUPPORTED_CODE
const REPLAY_TRANSPORT_INACTIVE_CODE := CameraTrackingBackend.REPLAY_TRANSPORT_INACTIVE_CODE

const STATE_IDLE := "idle"
const STATE_STARTING := "starting"
const STATE_RUNNING := "running"
const STATE_RESTARTING := "restarting"
const STATE_STOPPING := "stopping"
const STATE_ERROR := "error"
const STATES := [
	STATE_IDLE,
	STATE_STARTING,
	STATE_RUNNING,
	STATE_RESTARTING,
	STATE_STOPPING,
	STATE_ERROR,
]

const DETAIL_BACKEND_READY := "backend_ready"
const DETAIL_PREVIEW_READY := "preview_ready"
const DETAIL_TRACKING_READY := "tracking_ready"
const DETAIL_SOURCE_READY := "source_ready"
const READINESS_KEYS := [
	DETAIL_BACKEND_READY,
	DETAIL_PREVIEW_READY,
	DETAIL_TRACKING_READY,
	DETAIL_SOURCE_READY,
]

const _BACKEND_RESOLUTION_MANUAL := "manual"
const _BACKEND_RESOLUTION_REGISTRY := "registry"

const CameraTrackingCameraOptions = preload("CameraTrackingCameraOptions.gd")
const CameraTrackingPreviewPresenter = preload("CameraTrackingPreviewPresenter.gd")

const _MEDIAPIPE_PYTHON_BACKEND_ID := "mediapipe_python"
const _MEDIAPIPE_PYTHON_BACKEND_SCRIPT_PATH := "res://addons/aerobeat-vendor-mediapipe-python/src/MediaPipePythonCameraTrackingBackend.gd"
const _MEDIAPIPE_PYTHON_RUNTIME_BRIDGE_SCRIPT_PATH := "res://addons/aerobeat-vendor-mediapipe-python/src/MediaPipePythonRuntimeBridge.gd"

class _MediaPipePythonBackendFactory:
	extends RefCounted

	func create(_config: Dictionary) -> CameraTrackingBackend:
		var backend_script: Variant = load(CameraTracking._MEDIAPIPE_PYTHON_BACKEND_SCRIPT_PATH)
		var runtime_bridge_script: Variant = load(CameraTracking._MEDIAPIPE_PYTHON_RUNTIME_BRIDGE_SCRIPT_PATH)
		if backend_script == null or runtime_bridge_script == null:
			return null
		var backend_candidate: Variant = backend_script.new()
		if backend_candidate == null or not (backend_candidate is CameraTrackingBackend):
			return null
		backend_candidate.set_runtime_bridge(runtime_bridge_script.new())
		return backend_candidate

static var _mediapipe_python_backend_factory := _MediaPipePythonBackendFactory.new()

var _state: String = STATE_IDLE
var _state_detail: Dictionary = CameraTrackingConfig.make_state_detail()
var _active_config: Dictionary = CameraTrackingConfig.defaults()
var _tracking_frame: Dictionary = CameraTrackingFrame.empty(_active_config)
var _preview_descriptor: Dictionary = CameraTrackingPreview.detached(_active_config)
var _camera_options: Dictionary = CameraTrackingCameraOptions.empty(_active_config)
var _playback_status: Dictionary = {}
var _replay_transport_capabilities: Dictionary = {}
var _replay_transport_status: Dictionary = {}
var _last_error: Dictionary = {}
var _backend: CameraTrackingBackend = null
var _attached_preview_surfaces: Array = []
var _backend_resolution_mode: String = ""
var _requested_backend_id: String = ""
var _resolved_backend_id: String = ""
var _last_cameras: Array = []
var _close_request_window: Window = null
var _tree_exit_connected := false
var _teardown_fallback_in_progress := false

func _ready() -> void:
	set_process(false)
	_connect_teardown_fallbacks()

static func register_backend_factory(backend_id: String, factory: Callable) -> void:
	CameraTrackingBackendRegistry.register_factory(backend_id, factory)

static func unregister_backend_factory(backend_id: String) -> void:
	CameraTrackingBackendRegistry.unregister_factory(backend_id)

static func clear_backend_factories() -> void:
	CameraTrackingBackendRegistry.clear()

static func get_registered_backend_ids() -> Array:
	return CameraTrackingBackendRegistry.registered_backend_ids()

func set_backend(backend: CameraTrackingBackend, backend_id: String = "") -> void:
	var normalized_backend_id := _normalize_backend_id(backend_id)
	if normalized_backend_id == "" and backend != null:
		normalized_backend_id = _normalize_backend_id(backend.get_backend_id())
	var requested_backend_id := CameraTrackingConfig.normalize_requested_backend(normalized_backend_id)
	_set_backend_internal(backend, normalized_backend_id, _BACKEND_RESOLUTION_MANUAL, requested_backend_id)

func start(config: Dictionary = {}) -> void:
	_active_config = CameraTrackingConfig.normalize(config)
	_tracking_frame = CameraTrackingFrame.empty(_active_config)
	_camera_options = CameraTrackingCameraOptions.empty(_active_config)
	_playback_status = {}
	_replay_transport_capabilities = {}
	_replay_transport_status = {}
	_last_error = {}
	if _ensure_backend_for_config(_active_config) == false:
		_preview_descriptor = _compose_preview_descriptor(_backend.get_preview_descriptor() if _backend != null else {})
		return
	_preview_descriptor = _compose_preview_descriptor(_backend.get_preview_descriptor() if _backend != null else {})
	_set_state(STATE_STARTING, CameraTrackingConfig.make_state_detail())
	_backend.start(_active_config)
	if _backend != null and str(_backend.get_state().get("state", STATE_IDLE)) == STATE_RUNNING:
		_sync_from_backend()

func stop() -> void:
	_request_backend_stop(false)

func change(config: Dictionary) -> void:
	_active_config = CameraTrackingConfig.normalize(config)
	_tracking_frame = CameraTrackingFrame.empty(_active_config)
	_camera_options = CameraTrackingCameraOptions.empty(_active_config)
	_playback_status = {}
	_replay_transport_capabilities = {}
	_replay_transport_status = {}
	_last_error = {}
	if _ensure_backend_for_config(_active_config) == false:
		_preview_descriptor = _compose_preview_descriptor(_backend.get_preview_descriptor() if _backend != null else {})
		return
	_set_state(STATE_RESTARTING, CameraTrackingConfig.make_state_detail({
		DETAIL_SOURCE_READY: true,
	}))
	_backend.change(_active_config)

func list_cameras() -> Array:
	if _backend != null and _last_cameras.is_empty() and _state == STATE_RUNNING:
		_last_cameras = _backend.list_cameras().duplicate(true)
	return _last_cameras.duplicate(true)

func get_state() -> Dictionary:
	return {
		"state": _state,
		"detail": _state_detail.duplicate(true)
	}

func get_active_config() -> Dictionary:
	return _active_config.duplicate(true)

func get_tracking_frame() -> Dictionary:
	return _tracking_frame.duplicate(true)

func get_preview_descriptor() -> Dictionary:
	return _preview_descriptor.duplicate(true)

func get_camera_options(camera_id: String = "") -> Dictionary:
	var effective_camera_id := str(camera_id).strip_edges()
	if _backend == null and _ensure_backend_for_config(_active_config) == false:
		return CameraTrackingCameraOptions.empty(_active_config, effective_camera_id)
	if effective_camera_id == "" and not _camera_options.is_empty() and not _should_refresh_cached_camera_options():
		return _camera_options.duplicate(true)
	var backend_snapshot := _backend.get_camera_options(effective_camera_id) if _backend != null else {}
	var normalized_config := _active_config.duplicate(true)
	if effective_camera_id != "":
		normalized_config["source"] = normalized_config.get("source", {}).duplicate(true)
		normalized_config["source"]["camera_id"] = effective_camera_id
	var normalized_options := CameraTrackingCameraOptions.normalize(backend_snapshot, normalized_config, effective_camera_id)
	if effective_camera_id == "":
		_camera_options = normalized_options.duplicate(true)
	return normalized_options

func get_playback_status() -> Dictionary:
	if _backend == null:
		return _playback_status.duplicate(true)
	if _state == STATE_RUNNING:
		_refresh_from_backend_if_running(false)
	return _playback_status.duplicate(true)

func get_replay_transport_capabilities() -> Dictionary:
	if _backend == null:
		return _replay_transport_capabilities.duplicate(true)
	if _state == STATE_RUNNING:
		_refresh_from_backend_if_running(false)
	return _replay_transport_capabilities.duplicate(true)

func get_replay_transport_status() -> Dictionary:
	if _backend == null:
		return _replay_transport_status.duplicate(true)
	if _state == STATE_RUNNING:
		_refresh_from_backend_if_running(false)
	return _replay_transport_status.duplicate(true)

func step_replay_frames(delta_frames: int) -> Dictionary:
	if _backend == null:
		return _replay_transport_failure(REPLAY_TRANSPORT_INACTIVE_CODE, "step_replay_frames requires an active replay backend.", {
			"delta_frames": delta_frames
		})
	var result: Dictionary = _backend.step_replay_frames(delta_frames)
	_sync_replay_transport_from_backend()
	if _state == STATE_RUNNING and bool(result.get(CameraTrackingBackend.RESULT_SUCCESS, false)):
		_refresh_from_backend_if_running(true)
	return result.duplicate(true)

func seek_replay_to_frame(frame_index: int) -> Dictionary:
	if _backend == null:
		return _replay_transport_failure(REPLAY_TRANSPORT_INACTIVE_CODE, "seek_replay_to_frame requires an active replay backend.", {
			"frame_index": frame_index
		})
	var result: Dictionary = _backend.seek_replay_to_frame(frame_index)
	_sync_replay_transport_from_backend()
	if _state == STATE_RUNNING and bool(result.get(CameraTrackingBackend.RESULT_SUCCESS, false)):
		_refresh_from_backend_if_running(true)
	return result.duplicate(true)

func _should_refresh_cached_camera_options() -> bool:
	if _backend == null:
		return false
	if _state != STATE_RUNNING:
		return false
	var source: Dictionary = _active_config.get("source", {})
	if str(source.get("kind", "")) != CameraTrackingConfig.DEFAULT_SOURCE_KIND:
		return false
	return _camera_options == CameraTrackingCameraOptions.empty(_active_config)

func create_preview_presenter(options: Dictionary = {}) -> CameraTrackingPreviewPresenter:
	var presenter := CameraTrackingPreviewPresenter.new(options)
	presenter.bind_tracking_session(self)
	return presenter

func mount_preview_presenter(parent: Node, options: Dictionary = {}) -> CameraTrackingPreviewPresenter:
	if parent == null or not is_instance_valid(parent):
		return null
	var presenter := CameraTrackingPreviewPresenter.new(options)
	parent.add_child(presenter)
	if presenter is Control and parent is Control and not bool(options.get("preserve_layout", false)):
		presenter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	presenter.bind_tracking_session(self)
	return presenter

func attach_preview_surface(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	_prune_preview_surfaces()
	var existing_index := _preview_surface_index(node)
	if existing_index >= 0:
		_attached_preview_surfaces.remove_at(existing_index)
	_attached_preview_surfaces.append(node)
	_preview_descriptor = _compose_preview_descriptor(_backend.get_preview_descriptor() if _backend != null else {})
	preview_changed.emit(_preview_descriptor.duplicate(true))

func detach_preview_surface() -> void:
	_prune_preview_surfaces()
	if _attached_preview_surfaces.is_empty():
		_preview_descriptor = _compose_preview_descriptor(_backend.get_preview_descriptor() if _backend != null else {})
		preview_changed.emit(_preview_descriptor.duplicate(true))
		return
	_attached_preview_surfaces.remove_at(_attached_preview_surfaces.size() - 1)
	_preview_descriptor = _compose_preview_descriptor(_backend.get_preview_descriptor() if _backend != null else {})
	preview_changed.emit(_preview_descriptor.duplicate(true))

func get_last_error() -> Dictionary:
	return _last_error.duplicate(true)

func is_running() -> bool:
	return _state == STATE_RUNNING

func _ensure_backend_for_config(config: Dictionary) -> bool:
	var requested_backend_id := CameraTrackingConfig.normalize_requested_backend(config.get("backend", CameraTrackingConfig.DEFAULT_BACKEND))
	var resolved_backend_id := CameraTrackingConfig.resolve_backend_id(requested_backend_id)
	if _backend != null:
		if _backend_resolution_mode == _BACKEND_RESOLUTION_MANUAL:
			_requested_backend_id = requested_backend_id
			return true
		if _resolved_backend_id == resolved_backend_id:
			_requested_backend_id = requested_backend_id
			return true
	if CameraTrackingBackendRegistry.has_factory(resolved_backend_id) == false:
		_try_auto_register_backend_factory(resolved_backend_id)
	if CameraTrackingBackendRegistry.has_factory(resolved_backend_id) == false:
		_fail_with({
			"code": "backend_unregistered",
			"message": "No camera tracking backend factory is registered for '%s'" % resolved_backend_id,
			"backend": resolved_backend_id,
			"backend_request": requested_backend_id,
			"backend_impl": resolved_backend_id,
			"registered_backends": CameraTrackingBackendRegistry.registered_backend_ids()
		})
		return false
	var resolved_backend := CameraTrackingBackendRegistry.create_backend(resolved_backend_id, config)
	if resolved_backend == null:
		_fail_with({
			"code": "backend_factory_failed",
			"message": "Camera tracking backend factory for '%s' did not return a usable backend" % resolved_backend_id,
			"backend": resolved_backend_id,
			"backend_request": requested_backend_id,
			"backend_impl": resolved_backend_id
		})
		return false
	_set_backend_internal(resolved_backend, resolved_backend_id, _BACKEND_RESOLUTION_REGISTRY, requested_backend_id)
	return true

func _set_backend_internal(backend: CameraTrackingBackend, backend_id: String, resolution_mode: String, requested_backend_id: String = "") -> void:
	var normalized_backend_id := _normalize_backend_id(backend_id)
	var normalized_requested_backend_id := CameraTrackingConfig.normalize_requested_backend(requested_backend_id if requested_backend_id != "" else normalized_backend_id)
	if _backend == backend and _resolved_backend_id == normalized_backend_id and _requested_backend_id == normalized_requested_backend_id and _backend_resolution_mode == resolution_mode:
		return
	if _backend != null:
		_disconnect_backend(_backend)
	_backend = backend
	_requested_backend_id = normalized_requested_backend_id if backend != null else ""
	_resolved_backend_id = normalized_backend_id if backend != null else ""
	_backend_resolution_mode = resolution_mode if backend != null else ""
	if _backend != null:
		_connect_backend(_backend)
		_sync_from_backend()
	else:
		_preview_descriptor = CameraTrackingPreview.detached(_active_config)
		_camera_options = CameraTrackingCameraOptions.empty(_active_config)
		_playback_status = {}
		_replay_transport_capabilities = {}
		_replay_transport_status = {}

func _normalize_backend_id(backend_id: Variant) -> String:
	return str(backend_id).strip_edges()

func _try_auto_register_backend_factory(resolved_backend_id: String) -> void:
	match resolved_backend_id:
		_MEDIAPIPE_PYTHON_BACKEND_ID:
			_register_mediapipe_python_backend_factory()

func _register_mediapipe_python_backend_factory() -> void:
	if CameraTrackingBackendRegistry.has_factory(_MEDIAPIPE_PYTHON_BACKEND_ID):
		return
	var backend_script: Variant = load(_MEDIAPIPE_PYTHON_BACKEND_SCRIPT_PATH)
	var runtime_bridge_script: Variant = load(_MEDIAPIPE_PYTHON_RUNTIME_BRIDGE_SCRIPT_PATH)
	if backend_script == null or runtime_bridge_script == null:
		return
	CameraTrackingBackendRegistry.register_factory(
		_MEDIAPIPE_PYTHON_BACKEND_ID,
		Callable(_mediapipe_python_backend_factory, "create")
	)

func _connect_backend(backend: CameraTrackingBackend) -> void:
	backend.state_changed.connect(_on_backend_state_changed)
	backend.tracking_updated.connect(_on_backend_tracking_updated)
	backend.preview_changed.connect(_on_backend_preview_changed)
	backend.cameras_changed.connect(_on_backend_cameras_changed)
	backend.error_raised.connect(_on_backend_error_raised)

func _disconnect_backend(backend: CameraTrackingBackend) -> void:
	if backend.state_changed.is_connected(_on_backend_state_changed):
		backend.state_changed.disconnect(_on_backend_state_changed)
	if backend.tracking_updated.is_connected(_on_backend_tracking_updated):
		backend.tracking_updated.disconnect(_on_backend_tracking_updated)
	if backend.preview_changed.is_connected(_on_backend_preview_changed):
		backend.preview_changed.disconnect(_on_backend_preview_changed)
	if backend.cameras_changed.is_connected(_on_backend_cameras_changed):
		backend.cameras_changed.disconnect(_on_backend_cameras_changed)
	if backend.error_raised.is_connected(_on_backend_error_raised):
		backend.error_raised.disconnect(_on_backend_error_raised)

func _sync_from_backend() -> void:
	if _backend == null:
		_last_cameras = []
		return
	var backend_state: Dictionary = _backend.get_state()
	_set_state(
		str(backend_state.get("state", STATE_IDLE)),
		backend_state.get("detail", CameraTrackingConfig.make_state_detail())
	)
	_tracking_frame = CameraTrackingFrame.normalize(_backend.get_tracking_frame(), _active_config, _tracking_frame)
	_preview_descriptor = _compose_preview_descriptor(_backend.get_preview_descriptor())
	_camera_options = CameraTrackingCameraOptions.normalize(_backend.get_camera_options(), _active_config)
	_playback_status = _backend.get_playback_status().duplicate(true)
	_sync_replay_transport_from_backend()
	_last_cameras = _backend.list_cameras().duplicate(true)
	_sync_process_state()

func _set_state(next_state: String, detail: Dictionary) -> void:
	_state = next_state
	_state_detail = CameraTrackingConfig.make_state_detail(detail)
	state_changed.emit(_state, _state_detail.duplicate(true))

func _compose_preview_descriptor(backend_descriptor: Dictionary) -> Dictionary:
	_prune_preview_surfaces()
	var attached_surface := _get_attached_preview_surface()
	var attachment_count := _attached_preview_surfaces.size()
	var descriptor := CameraTrackingPreview.attached(attached_surface, _active_config, backend_descriptor, attachment_count)
	if backend_descriptor.is_empty() and attached_surface == null:
		descriptor = CameraTrackingPreview.detached(_active_config, attachment_count)
	if backend_descriptor.has("backend"):
		descriptor["backend"] = backend_descriptor["backend"]
	return descriptor

func _get_attached_preview_surface() -> Node:
	_prune_preview_surfaces()
	if _attached_preview_surfaces.is_empty():
		return null
	var surface: Variant = _attached_preview_surfaces.back()
	return surface if is_instance_valid(surface) and surface is Node else null

func _preview_surface_index(node: Node) -> int:
	for i in range(_attached_preview_surfaces.size()):
		var surface: Variant = _attached_preview_surfaces[i]
		if is_instance_valid(surface) and surface == node:
			return i
	return -1

func _prune_preview_surfaces() -> void:
	var retained: Array = []
	for surface: Variant in _attached_preview_surfaces:
		if is_instance_valid(surface) and surface is Node:
			retained.append(surface)
	_attached_preview_surfaces = retained

func _fail_with(error_info: Dictionary) -> void:
	_last_error = error_info.duplicate(true)
	_set_state(STATE_ERROR, CameraTrackingConfig.make_state_detail())
	error_raised.emit(_last_error.duplicate(true))

func _process(_delta: float) -> void:
	_refresh_from_backend_if_running(true)

func _refresh_from_backend_if_running(emit_updates: bool) -> void:
	if _backend == null:
		return
	if _state != STATE_RUNNING:
		return

	var next_frame := CameraTrackingFrame.normalize(_backend.get_tracking_frame(), _active_config, _tracking_frame)
	var frame_changed_now := next_frame != _tracking_frame
	_tracking_frame = next_frame
	_playback_status = _backend.get_playback_status().duplicate(true)
	_sync_replay_transport_from_backend()
	_sync_process_state()

	if emit_updates and frame_changed_now:
		tracking_updated.emit(_tracking_frame.duplicate(true))

func _sync_process_state() -> void:
	set_process(_backend != null and _state == STATE_RUNNING and is_inside_tree())


func _sync_replay_transport_from_backend() -> void:
	if _backend == null:
		_replay_transport_capabilities = {}
		_replay_transport_status = {}
		return
	_replay_transport_capabilities = _backend.get_replay_transport_capabilities().duplicate(true)
	_replay_transport_status = _backend.get_replay_transport_status().duplicate(true)

func _replay_transport_failure(code: String, message: String, detail: Dictionary = {}) -> Dictionary:
	return {
		CameraTrackingBackend.RESULT_SUCCESS: false,
		CameraTrackingBackend.RESULT_CODE: code,
		CameraTrackingBackend.RESULT_MESSAGE: message,
		CameraTrackingBackend.RESULT_DETAIL: detail.duplicate(true),
	}

func _connect_teardown_fallbacks() -> void:
	var tree := get_tree()
	if tree == null:
		return
	if tree.has_signal("tree_exiting") and not tree.is_connected("tree_exiting", Callable(self, "_on_tree_exiting")):
		tree.connect("tree_exiting", Callable(self, "_on_tree_exiting"))
		_tree_exit_connected = true
	var root := tree.root
	if root == null or not root.has_signal("close_requested"):
		return
	if not root.is_connected("close_requested", Callable(self, "_on_close_requested")):
		root.connect("close_requested", Callable(self, "_on_close_requested"))
	_close_request_window = root

func _disconnect_teardown_fallbacks() -> void:
	var tree := get_tree()
	if _tree_exit_connected and tree != null and tree.is_connected("tree_exiting", Callable(self, "_on_tree_exiting")):
		tree.disconnect("tree_exiting", Callable(self, "_on_tree_exiting"))
	_tree_exit_connected = false
	if _close_request_window != null and _close_request_window.is_connected("close_requested", Callable(self, "_on_close_requested")):
		_close_request_window.disconnect("close_requested", Callable(self, "_on_close_requested"))
	_close_request_window = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_request_backend_stop(true)

func _exit_tree() -> void:
	_request_backend_stop(true)
	_disconnect_teardown_fallbacks()

func _request_backend_stop(from_teardown_fallback: bool) -> void:
	_last_error = {}
	if _backend == null:
		_set_state(STATE_IDLE, CameraTrackingConfig.make_state_detail())
		return
	if from_teardown_fallback and _teardown_fallback_in_progress:
		return
	if _state == STATE_IDLE:
		return
	if from_teardown_fallback:
		_teardown_fallback_in_progress = true
	if _state != STATE_STOPPING:
		_set_state(STATE_STOPPING, CameraTrackingConfig.make_state_detail())
	_backend.stop()
	if from_teardown_fallback:
		_teardown_fallback_in_progress = false

func _on_backend_state_changed(state: String, detail: Dictionary) -> void:
	if state != STATE_ERROR:
		_last_error = {}
	_set_state(state, detail)
	_sync_process_state()

func _on_backend_tracking_updated(frame: Dictionary) -> void:
	_tracking_frame = CameraTrackingFrame.normalize(frame, _active_config, _tracking_frame)
	if _backend != null:
		_playback_status = _backend.get_playback_status().duplicate(true)
		_sync_replay_transport_from_backend()
	tracking_updated.emit(_tracking_frame.duplicate(true))

func _on_backend_preview_changed(descriptor: Dictionary) -> void:
	_preview_descriptor = _compose_preview_descriptor(descriptor)
	preview_changed.emit(_preview_descriptor.duplicate(true))

func _on_backend_cameras_changed(cameras: Array) -> void:
	_last_cameras = cameras.duplicate(true)
	cameras_changed.emit(_last_cameras.duplicate(true))

func _on_backend_error_raised(error_info: Dictionary) -> void:
	_last_error = error_info.duplicate(true)
	_set_state(STATE_ERROR, CameraTrackingConfig.make_state_detail(_state_detail))
	error_raised.emit(_last_error.duplicate(true))

func _on_tree_exiting() -> void:
	_request_backend_stop(true)

func _on_close_requested() -> void:
	_request_backend_stop(true)
