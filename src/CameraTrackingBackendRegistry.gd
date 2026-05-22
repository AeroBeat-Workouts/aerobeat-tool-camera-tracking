class_name CameraTrackingBackendRegistry
extends RefCounted

static var _backend_factories: Dictionary = {}

static func register_factory(backend_id: String, factory: Callable) -> void:
	var normalized_backend_id := str(backend_id).strip_edges()
	if normalized_backend_id == "":
		push_error("CameraTrackingBackendRegistry.register_factory() requires a non-empty backend_id")
		return
	if factory.is_valid() == false:
		push_error("CameraTrackingBackendRegistry.register_factory() requires a valid factory Callable")
		return
	_backend_factories[normalized_backend_id] = factory

static func unregister_factory(backend_id: String) -> void:
	_backend_factories.erase(str(backend_id).strip_edges())

static func clear() -> void:
	_backend_factories.clear()

static func has_factory(backend_id: String) -> bool:
	return _backend_factories.has(str(backend_id).strip_edges())

static func registered_backend_ids() -> Array:
	var backend_ids: Array = []
	for backend_id in _backend_factories.keys():
		backend_ids.append(str(backend_id))
	backend_ids.sort()
	return backend_ids

static func create_backend(backend_id: String, config: Dictionary = {}) -> CameraTrackingBackend:
	var normalized_backend_id := str(backend_id).strip_edges()
	if has_factory(normalized_backend_id) == false:
		return null
	var backend_candidate: Variant = _backend_factories[normalized_backend_id].call(config.duplicate(true))
	if backend_candidate is CameraTrackingBackend:
		return backend_candidate
	push_error("CameraTrackingBackendRegistry factory for '%s' did not return a CameraTrackingBackend" % normalized_backend_id)
	return null
