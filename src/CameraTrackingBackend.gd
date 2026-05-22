class_name CameraTrackingBackend
extends RefCounted

signal state_changed(state: String, detail: Dictionary)
signal tracking_updated(frame: Dictionary)
signal preview_changed(descriptor: Dictionary)
signal cameras_changed(cameras: Array)
signal error_raised(error_info: Dictionary)

func start(_config: Dictionary) -> void:
	push_error("CameraTrackingBackend.start() must be implemented by a concrete backend")

func stop() -> void:
	push_error("CameraTrackingBackend.stop() must be implemented by a concrete backend")

func change(_config: Dictionary) -> void:
	push_error("CameraTrackingBackend.change() must be implemented by a concrete backend")

func list_cameras() -> Array:
	return []

func get_state() -> Dictionary:
	return {
		"state": CameraTracking.STATE_IDLE,
		"detail": CameraTrackingConfig.make_state_detail()
	}

func get_tracking_frame() -> Dictionary:
	return CameraTrackingFrame.empty()

func get_preview_descriptor() -> Dictionary:
	return CameraTrackingPreview.detached()
