class_name CameraTracking
extends Node

signal state_changed(state: String, detail: Dictionary)
signal tracking_updated(frame: Dictionary)
signal preview_changed(descriptor: Dictionary)
signal cameras_changed(cameras: Array)
signal error_raised(error_info: Dictionary)

const VERSION := "0.2.0"

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

var _state: String = STATE_IDLE
var _state_detail: Dictionary = CameraTrackingConfig.make_state_detail()
var _active_config: Dictionary = CameraTrackingConfig.defaults()
var _tracking_frame: Dictionary = CameraTrackingFrame.empty(_active_config)
var _preview_descriptor: Dictionary = CameraTrackingPreview.detached(_active_config)
var _last_error: Dictionary = {}
var _backend: CameraTrackingBackend = null
var _attached_preview_surface: Node = null
var _backend_resolution_mode: String = ""
var _resolved_backend_id: String = ""

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
	_set_backend_internal(backend, normalized_backend_id, _BACKEND_RESOLUTION_MANUAL)

func start(config: Dictionary = {}) -> void:
	_active_config = CameraTrackingConfig.normalize(config)
	_tracking_frame = CameraTrackingFrame.empty(_active_config)
	_last_error = {}
	if _ensure_backend_for_config(_active_config) == false:
		_preview_descriptor = _compose_preview_descriptor(_backend.get_preview_descriptor() if _backend != null else {})
		return
	_preview_descriptor = _compose_preview_descriptor(_backend.get_preview_descriptor() if _backend != null else {})
	_set_state(STATE_STARTING, CameraTrackingConfig.make_state_detail())
	_backend.start(_active_config)

func stop() -> void:
	_last_error = {}
	if _backend == null:
		_set_state(STATE_IDLE, CameraTrackingConfig.make_state_detail())
		return
	_set_state(STATE_STOPPING, CameraTrackingConfig.make_state_detail())
	_backend.stop()

func change(config: Dictionary) -> void:
	_active_config = CameraTrackingConfig.normalize(config)
	_tracking_frame = CameraTrackingFrame.empty(_active_config)
	_last_error = {}
	if _ensure_backend_for_config(_active_config) == false:
		_preview_descriptor = _compose_preview_descriptor(_backend.get_preview_descriptor() if _backend != null else {})
		return
	_set_state(STATE_RESTARTING, CameraTrackingConfig.make_state_detail({
		DETAIL_SOURCE_READY: true,
	}))
	_backend.change(_active_config)

func list_cameras() -> Array:
	if _backend == null:
		return []
	return _backend.list_cameras()

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

func attach_preview_surface(node: Node) -> void:
	_attached_preview_surface = node
	_preview_descriptor = _compose_preview_descriptor(_backend.get_preview_descriptor() if _backend != null else {})
	preview_changed.emit(_preview_descriptor.duplicate(true))

func detach_preview_surface() -> void:
	_attached_preview_surface = null
	_preview_descriptor = _compose_preview_descriptor(_backend.get_preview_descriptor() if _backend != null else {})
	preview_changed.emit(_preview_descriptor.duplicate(true))

func get_last_error() -> Dictionary:
	return _last_error.duplicate(true)

func is_running() -> bool:
	return _state == STATE_RUNNING

func _ensure_backend_for_config(config: Dictionary) -> bool:
	var requested_backend_id := _normalize_backend_id(config.get("backend", CameraTrackingConfig.DEFAULT_BACKEND))
	if _backend != null:
		if _backend_resolution_mode == _BACKEND_RESOLUTION_MANUAL:
			return true
		if _resolved_backend_id == requested_backend_id:
			return true
	if CameraTrackingBackendRegistry.has_factory(requested_backend_id) == false:
		_fail_with({
			"code": "backend_unregistered",
			"message": "No camera tracking backend factory is registered for '%s'" % requested_backend_id,
			"backend": requested_backend_id,
			"registered_backends": CameraTrackingBackendRegistry.registered_backend_ids()
		})
		return false
	var resolved_backend := CameraTrackingBackendRegistry.create_backend(requested_backend_id, config)
	if resolved_backend == null:
		_fail_with({
			"code": "backend_factory_failed",
			"message": "Camera tracking backend factory for '%s' did not return a usable backend" % requested_backend_id,
			"backend": requested_backend_id
		})
		return false
	_set_backend_internal(resolved_backend, requested_backend_id, _BACKEND_RESOLUTION_REGISTRY)
	return true

func _set_backend_internal(backend: CameraTrackingBackend, backend_id: String, resolution_mode: String) -> void:
	var normalized_backend_id := _normalize_backend_id(backend_id)
	if _backend == backend and _resolved_backend_id == normalized_backend_id and _backend_resolution_mode == resolution_mode:
		return
	if _backend != null:
		_disconnect_backend(_backend)
	_backend = backend
	_resolved_backend_id = normalized_backend_id if backend != null else ""
	_backend_resolution_mode = resolution_mode if backend != null else ""
	if _backend != null:
		_connect_backend(_backend)
		_sync_from_backend()
	else:
		_preview_descriptor = CameraTrackingPreview.detached(_active_config)

func _normalize_backend_id(backend_id: Variant) -> String:
	return str(backend_id).strip_edges()

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
		return
	var backend_state: Dictionary = _backend.get_state()
	_set_state(
		str(backend_state.get("state", STATE_IDLE)),
		backend_state.get("detail", CameraTrackingConfig.make_state_detail())
	)
	_tracking_frame = _backend.get_tracking_frame()
	_preview_descriptor = _compose_preview_descriptor(_backend.get_preview_descriptor())

func _set_state(next_state: String, detail: Dictionary) -> void:
	_state = next_state
	_state_detail = CameraTrackingConfig.make_state_detail(detail)
	state_changed.emit(_state, _state_detail.duplicate(true))

func _compose_preview_descriptor(backend_descriptor: Dictionary) -> Dictionary:
	var descriptor := CameraTrackingPreview.attached(_attached_preview_surface, _active_config, backend_descriptor)
	if backend_descriptor.is_empty() and _attached_preview_surface == null:
		descriptor = CameraTrackingPreview.detached(_active_config)
	if backend_descriptor.has("backend"):
		descriptor["backend"] = backend_descriptor["backend"]
	return descriptor

func _fail_with(error_info: Dictionary) -> void:
	_last_error = error_info.duplicate(true)
	_set_state(STATE_ERROR, CameraTrackingConfig.make_state_detail())
	error_raised.emit(_last_error.duplicate(true))

func _on_backend_state_changed(state: String, detail: Dictionary) -> void:
	if state != STATE_ERROR:
		_last_error = {}
	_set_state(state, detail)

func _on_backend_tracking_updated(frame: Dictionary) -> void:
	_tracking_frame = frame.duplicate(true)
	tracking_updated.emit(_tracking_frame.duplicate(true))

func _on_backend_preview_changed(descriptor: Dictionary) -> void:
	_preview_descriptor = _compose_preview_descriptor(descriptor)
	preview_changed.emit(_preview_descriptor.duplicate(true))

func _on_backend_cameras_changed(cameras: Array) -> void:
	cameras_changed.emit(cameras.duplicate(true))

func _on_backend_error_raised(error_info: Dictionary) -> void:
	_last_error = error_info.duplicate(true)
	_set_state(STATE_ERROR, CameraTrackingConfig.make_state_detail(_state_detail))
	error_raised.emit(_last_error.duplicate(true))
