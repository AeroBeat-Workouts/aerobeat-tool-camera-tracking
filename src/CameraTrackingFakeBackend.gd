class_name CameraTrackingFakeBackend
extends CameraTrackingBackend

var cameras: Array = []
var state: String = CameraTracking.STATE_IDLE
var detail: Dictionary = CameraTrackingConfig.make_state_detail()
var tracking_frame: Dictionary = CameraTrackingFrame.empty()
var preview_descriptor: Dictionary = CameraTrackingPreview.detached()
var last_config: Dictionary = CameraTrackingConfig.defaults()

func _init(seed_cameras: Array = []) -> void:
	cameras = seed_cameras.duplicate(true)
	preview_descriptor["backend"] = "fake"
	tracking_frame["backend"] = "fake"

func start(config: Dictionary) -> void:
	last_config = CameraTrackingConfig.normalize(config)
	state = CameraTracking.STATE_RUNNING
	detail = CameraTrackingConfig.make_state_detail({
		"backend_ready": true,
		"preview_ready": bool(last_config.get("preview", {}).get("enabled", true)),
		"tracking_ready": true,
		"source_ready": true
	})
	preview_descriptor = CameraTrackingPreview.detached(last_config)
	preview_descriptor["backend"] = "fake"
	tracking_frame = CameraTrackingFrame.empty(last_config)
	tracking_frame["backend"] = "fake"
	tracking_frame["tracking_state"] = "tracked"
	emit_signal("state_changed", state, detail.duplicate(true))
	emit_signal("preview_changed", preview_descriptor.duplicate(true))
	emit_signal("tracking_updated", tracking_frame.duplicate(true))
	emit_signal("cameras_changed", cameras.duplicate(true))

func stop() -> void:
	state = CameraTracking.STATE_IDLE
	detail = CameraTrackingConfig.make_state_detail()
	emit_signal("state_changed", state, detail.duplicate(true))

func change(config: Dictionary) -> void:
	last_config = CameraTrackingConfig.normalize(config)
	tracking_frame = CameraTrackingFrame.empty(last_config)
	tracking_frame["backend"] = "fake"
	tracking_frame["tracking_state"] = "tracked"
	preview_descriptor = CameraTrackingPreview.detached(last_config)
	preview_descriptor["backend"] = "fake"
	emit_signal("state_changed", CameraTracking.STATE_RESTARTING, CameraTrackingConfig.make_state_detail({
		"backend_ready": true,
		"preview_ready": false,
		"tracking_ready": false,
		"source_ready": true
	}))
	emit_signal("preview_changed", preview_descriptor.duplicate(true))
	emit_signal("tracking_updated", tracking_frame.duplicate(true))
	emit_signal("state_changed", CameraTracking.STATE_RUNNING, detail.duplicate(true))

func list_cameras() -> Array:
	return cameras.duplicate(true)

func get_state() -> Dictionary:
	return {
		"state": state,
		"detail": detail.duplicate(true)
	}

func get_tracking_frame() -> Dictionary:
	return tracking_frame.duplicate(true)

func get_preview_descriptor() -> Dictionary:
	return preview_descriptor.duplicate(true)

func emit_tracking_frame(frame: Dictionary) -> void:
	tracking_frame = frame.duplicate(true)
	emit_signal("tracking_updated", tracking_frame.duplicate(true))

func emit_preview_descriptor(descriptor: Dictionary) -> void:
	preview_descriptor = descriptor.duplicate(true)
	emit_signal("preview_changed", preview_descriptor.duplicate(true))

func emit_error(error_info: Dictionary) -> void:
	emit_signal("error_raised", error_info.duplicate(true))

func set_cameras(next_cameras: Array) -> void:
	cameras = next_cameras.duplicate(true)
	emit_signal("cameras_changed", cameras.duplicate(true))
