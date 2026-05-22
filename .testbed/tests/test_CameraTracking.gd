extends GutTest

func test_config_normalization_preserves_contract_shape() -> void:
	var normalized := CameraTrackingConfig.normalize({
		"source": {"camera_id": "/dev/video7"},
		"preview": {"flip_horizontal": false}
	})
	assert_eq(normalized.get("backend"), "mediapipe_python")
	assert_eq(normalized.get("source", {}).get("kind"), "live_camera")
	assert_eq(normalized.get("source", {}).get("camera_id"), "/dev/video7")
	assert_eq(normalized.get("tracking", {}).get("quality"), "optimized")
	assert_false(normalized.get("preview", {}).get("flip_horizontal"))

func test_camera_tracking_defaults_expose_contract_shell() -> void:
	var tracker := CameraTracking.new()
	assert_eq(CameraTracking.VERSION, "0.1.0")
	assert_eq(tracker.get_state().get("state"), CameraTracking.STATE_IDLE)
	assert_eq(tracker.get_state().get("detail", {}).keys().size(), 4)
	assert_eq(tracker.get_tracking_frame().get("tracking_state"), "idle")
	assert_eq(tracker.get_tracking_frame().get("preview_transform", {}).get("space"), "gameplay_normalized")
	assert_false(tracker.get_preview_descriptor().get("attached"))
	tracker.free()

func test_attach_and_detach_preview_surface_updates_descriptor() -> void:
	var tracker := CameraTracking.new()
	var parent := Node.new()
	parent.name = "Parent"
	var slot := Node.new()
	slot.name = "PreviewSlot"
	parent.add_child(slot)

	tracker.attach_preview_surface(slot)
	assert_true(tracker.get_preview_descriptor().get("attached"))
	assert_eq(tracker.get_preview_descriptor().get("surface_path"), NodePath("PreviewSlot"))

	tracker.detach_preview_surface()
	assert_false(tracker.get_preview_descriptor().get("attached"))
	parent.free()
	tracker.free()

func test_start_without_backend_raises_structured_error() -> void:
	var tracker := CameraTracking.new()
	tracker.start({"backend": "mediapipe_python"})
	assert_eq(tracker.get_state().get("state"), CameraTracking.STATE_ERROR)
	assert_eq(tracker.get_last_error().get("code"), "backend_missing")
	tracker.free()

func test_fake_backend_drives_state_preview_and_tracking_contracts() -> void:
	var tracker := CameraTracking.new()
	var backend := CameraTrackingFakeBackend.new([
		{"id": "/dev/video0", "label": "Front Camera"}
	])
	var state_events: Array = []
	var preview_events: Array = []
	var tracking_events: Array = []
	tracker.state_changed.connect(func(state: String, detail: Dictionary): state_events.append({"state": state, "detail": detail}))
	tracker.preview_changed.connect(func(descriptor: Dictionary): preview_events.append(descriptor))
	tracker.tracking_updated.connect(func(frame: Dictionary): tracking_events.append(frame))
	tracker.set_backend(backend)

	tracker.start({
		"backend": "mediapipe_python",
		"source": {"kind": "live_camera", "camera_id": "/dev/video0"},
		"preview": {"enabled": true, "flip_horizontal": true}
	})

	assert_eq(tracker.get_state().get("state"), CameraTracking.STATE_RUNNING)
	assert_true(tracker.is_running())
	assert_eq(tracker.get_active_config().get("source", {}).get("camera_id"), "/dev/video0")
	assert_eq(tracker.list_cameras().size(), 1)
	assert_eq(tracker.get_preview_descriptor().get("backend"), "fake")
	assert_eq(tracker.get_tracking_frame().get("tracking_state"), "tracked")
	assert_eq(state_events.back().get("state"), CameraTracking.STATE_RUNNING)
	assert_eq(preview_events.back().get("backend"), "fake")
	assert_eq(tracking_events.back().get("backend"), "fake")

	backend.emit_tracking_frame({
		"timestamp_ms": 42,
		"backend": "fake",
		"source_kind": "live_camera",
		"source_id": "/dev/video0",
		"tracking_state": "tracked",
		"confidence": 0.99,
		"frame_size": {"x": 1920, "y": 1080},
		"preview_transform": {"flip_horizontal": true, "space": "gameplay_normalized"},
		"head_position": {"x": 0.1, "y": 0.2, "z": 0.3},
		"head_velocity": {"x": 0.0, "y": 0.0, "z": 0.0},
		"head_orientation": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
		"landmarks": [],
		"skeleton": {}
	})
	assert_eq(tracker.get_tracking_frame().get("timestamp_ms"), 42)
	assert_eq(tracking_events.back().get("confidence"), 0.99)
	tracker.free()
