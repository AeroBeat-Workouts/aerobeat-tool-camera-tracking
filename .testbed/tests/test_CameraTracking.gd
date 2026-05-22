extends GutTest

const MediaPipePythonCameraTrackingBackend = preload("res://addons/aerobeat-vendor-mediapipe-python/src/MediaPipePythonCameraTrackingBackend.gd")
const MediaPipePythonRuntimeBridge = preload("res://addons/aerobeat-vendor-mediapipe-python/src/MediaPipePythonRuntimeBridge.gd")

var _fixture_root := ""

func before_each() -> void:
	CameraTracking.clear_backend_factories()
	_fixture_root = ProjectSettings.globalize_path("user://camera-tracking-fixture-%s" % str(Time.get_unix_time_from_system()))
	DirAccess.make_dir_recursive_absolute(_fixture_root)
	_write_fixture_camera("video0")
	_write_fixture_camera("video2")

func after_each() -> void:
	CameraTracking.clear_backend_factories()
	if _fixture_root != "":
		var dir := DirAccess.open(_fixture_root)
		if dir != null:
			dir.list_dir_begin()
			var entry := dir.get_next()
			while entry != "":
				if dir.current_is_dir() == false:
					dir.remove(entry)
				entry = dir.get_next()
			dir.list_dir_end()
		DirAccess.remove_absolute(_fixture_root)

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
	assert_eq(CameraTracking.VERSION, "0.2.0")
	assert_eq(tracker.get_state().get("state"), CameraTracking.STATE_IDLE)
	assert_eq(tracker.get_state().get("detail", {}).keys().size(), 4)
	assert_eq(tracker.get_tracking_frame().get("tracking_state"), "idle")
	assert_eq(tracker.get_tracking_frame().get("preview_transform", {}).get("space"), "gameplay_normalized")
	assert_false(tracker.get_preview_descriptor().get("attached"))
	tracker.free()

func test_frame_normalization_preserves_tool_defaults_for_unproven_fields() -> void:
	var frame := CameraTrackingFrame.normalize({
		"timestamp_ms": 42,
		"backend": "mediapipe_python",
		"source_kind": "live_camera",
		"source_id": "/dev/video0",
		"tracking_state": "idle",
		"confidence": 0.91,
		"frame_size": {"x": 640, "y": 480},
		"head_position": {"x": 9.0, "y": 8.0, "z": 7.0},
		"skeleton": {"hips": {"x": 0.5}}
	}, {
		"backend": "mediapipe_python",
		"source": {"kind": "live_camera", "camera_id": "/dev/video0"},
		"preview": {"flip_horizontal": false}
	})
	assert_eq(frame.get("timestamp_ms"), 42)
	assert_eq(frame.get("frame_size", {}).get("x"), 640)
	assert_eq(frame.get("frame_size", {}).get("y"), 480)
	assert_eq(frame.get("confidence"), 0.0)
	assert_eq(frame.get("head_position", {}).get("z"), 0.0)
	assert_eq(frame.get("landmarks", []).size(), 0)
	assert_eq(frame.get("skeleton", {}).size(), 0)
	assert_false(frame.get("preview_transform", {}).get("flip_horizontal"))
	assert_eq(frame.get("preview_transform", {}).get("space"), "gameplay_normalized")

func test_frame_normalization_maps_vendor_landmarks_into_public_contract() -> void:
	var frame := CameraTrackingFrame.normalize({
		"timestamp_ms": 99,
		"backend": "mediapipe_python",
		"source_kind": "live_camera",
		"source_id": "/dev/video0",
		"tracking_state": "tracked",
		"landmarks": [
			{"id": 0, "x": 0.25, "y": 0.4, "z": -0.15, "visibility": 0.95},
			{"id": 12, "x": 1.4, "y": -0.2, "z": -0.09, "v": 0.88},
			{"x": 0.5, "y": 0.5, "z": 0.0, "visibility": 1.0}
		]
	}, {
		"backend": "mediapipe_python",
		"source": {"kind": "live_camera", "camera_id": "/dev/video0"},
		"preview": {"flip_horizontal": true}
	})
	assert_eq(frame.get("tracking_state"), "tracked")
	assert_eq(frame.get("landmarks", []).size(), 2)
	assert_eq(int(frame["landmarks"][0]["id"]), 0)
	assert_eq(float(frame["landmarks"][0]["x"]), 0.75)
	assert_eq(float(frame["landmarks"][0]["y"]), 0.4)
	assert_eq(float(frame["landmarks"][0]["z"]), -0.15)
	assert_eq(float(frame["landmarks"][0]["v"]), 0.95)
	assert_eq(float(frame["landmarks"][1]["x"]), 0.0)
	assert_eq(float(frame["landmarks"][1]["y"]), 0.0)
	assert_false(frame["landmarks"][0].has("visibility"))

func test_frame_normalization_keeps_tracking_idle_when_no_public_landmarks_exist() -> void:
	var frame := CameraTrackingFrame.normalize({
		"tracking_state": "tracked",
		"landmarks": [
			{"x": 0.5, "y": 0.5, "z": 0.0, "visibility": 1.0}
		]
	}, {
		"backend": "mediapipe_python",
		"source": {"kind": "live_camera", "camera_id": "/dev/video0"}
	})
	assert_eq(frame.get("tracking_state"), "idle")
	assert_eq(frame.get("landmarks", []).size(), 0)

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

func test_start_without_registered_backend_raises_structured_error() -> void:
	var tracker := CameraTracking.new()
	tracker.start({"backend": "mediapipe_python"})
	assert_eq(tracker.get_state().get("state"), CameraTracking.STATE_ERROR)
	assert_eq(tracker.get_last_error().get("code"), "backend_unregistered")
	assert_eq(tracker.get_last_error().get("backend"), "mediapipe_python")
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
		"landmarks": [
			{"id": 15, "x": 0.2, "y": 0.3, "z": -0.1, "visibility": 0.9}
		],
		"skeleton": {"hips": {"x": 0.5}}
	})
	assert_eq(tracker.get_tracking_frame().get("timestamp_ms"), 42)
	assert_eq(tracking_events.back().get("confidence"), 0.0)
	assert_eq(tracking_events.back().get("head_position", {}).get("z"), 0.0)
	assert_eq(tracking_events.back().get("landmarks", []).size(), 1)
	assert_eq(tracking_events.back().get("preview_transform", {}).get("flip_horizontal"), true)
	assert_eq(tracking_events.back().get("preview_transform", {}).get("space"), "gameplay_normalized")
	tracker.free()

func test_registered_vendor_backend_starts_live_camera_truthfully_and_preserves_preview_ownership() -> void:
	_register_vendor_backend()
	var tracker := CameraTracking.new()
	var parent := Node.new()
	parent.name = "Parent"
	var slot := Node.new()
	slot.name = "PreviewSlot"
	parent.add_child(slot)
	tracker.attach_preview_surface(slot)

	var selected_camera_id := _fixture_root.path_join("video2")
	tracker.start(_make_live_config({
		"source": {"camera_id": selected_camera_id},
		"preview": {"flip_horizontal": false}
	}))

	assert_eq(tracker.get_state().get("state"), CameraTracking.STATE_RUNNING)
	assert_true(tracker.get_state().get("detail", {}).get("backend_ready"))
	assert_true(tracker.get_state().get("detail", {}).get("preview_ready"))
	assert_false(tracker.get_state().get("detail", {}).get("tracking_ready"))
	assert_true(tracker.get_state().get("detail", {}).get("source_ready"))
	assert_eq(tracker.list_cameras().size(), 2)
	assert_eq(tracker.list_cameras()[1].get("camera_id"), selected_camera_id)
	assert_eq(tracker.get_preview_descriptor().get("backend"), "mediapipe_python")
	assert_true(tracker.get_preview_descriptor().get("attached"))
	assert_eq(tracker.get_preview_descriptor().get("surface_path"), NodePath("PreviewSlot"))
	assert_false(tracker.get_preview_descriptor().get("flip_horizontal"))
	assert_eq(tracker.get_tracking_frame().get("backend"), "mediapipe_python")
	assert_eq(tracker.get_tracking_frame().get("source_kind"), "live_camera")
	assert_eq(tracker.get_tracking_frame().get("source_id"), selected_camera_id)
	assert_eq(tracker.get_tracking_frame().get("tracking_state"), "tracked")
	assert_eq(tracker.get_tracking_frame().get("timestamp_ms"), 1710000000456)
	assert_eq(tracker.get_tracking_frame().get("frame_size", {}).get("x"), 640)
	assert_eq(tracker.get_tracking_frame().get("frame_size", {}).get("y"), 480)
	assert_eq(tracker.get_tracking_frame().get("confidence"), 0.0)
	assert_eq(tracker.get_tracking_frame().get("landmarks", []).size(), 2)
	assert_eq(int(tracker.get_tracking_frame().get("landmarks", [])[0].get("id")), 0)
	assert_eq(float(tracker.get_tracking_frame().get("landmarks", [])[0].get("x")), 0.25)
	assert_eq(float(tracker.get_tracking_frame().get("landmarks", [])[0].get("v")), 0.95)
	assert_eq(tracker.get_tracking_frame().get("skeleton", {}).size(), 0)
	assert_true(tracker.is_running())

	parent.free()
	tracker.free()

func test_registered_vendor_backend_change_surfaces_truthful_restart_and_unsupported_source_error() -> void:
	_register_vendor_backend()
	var tracker := CameraTracking.new()
	tracker.start(_make_live_config({
		"source": {"camera_id": _fixture_root.path_join("video0")}
	}))
	assert_eq(tracker.get_state().get("state"), CameraTracking.STATE_RUNNING)
	assert_eq(tracker.get_tracking_frame().get("tracking_state"), "idle")
	assert_eq(tracker.get_tracking_frame().get("landmarks", []).size(), 0)

	tracker.change(_make_live_config({
		"source": {"camera_id": _fixture_root.path_join("video2")},
		"preview": {"flip_horizontal": false}
	}))
	assert_eq(tracker.get_state().get("state"), CameraTracking.STATE_RUNNING)
	assert_eq(tracker.get_active_config().get("source", {}).get("camera_id"), _fixture_root.path_join("video2"))
	assert_eq(tracker.get_tracking_frame().get("source_id"), _fixture_root.path_join("video2"))
	assert_eq(tracker.get_tracking_frame().get("timestamp_ms"), 1710000000456)
	assert_eq(tracker.get_tracking_frame().get("frame_size", {}).get("x"), 640)
	assert_eq(tracker.get_tracking_frame().get("frame_size", {}).get("y"), 480)
	assert_eq(tracker.get_tracking_frame().get("tracking_state"), "tracked")
	assert_eq(tracker.get_tracking_frame().get("landmarks", []).size(), 2)
	assert_false(tracker.get_state().get("detail", {}).get("tracking_ready"))

	tracker.change({
		"backend": "mediapipe_python",
		"source": {"kind": "video_file", "path": "res://clips/demo.mp4"},
		"runtime": {
			"environment": {
				"AEROBEAT_CAMERA_ROOT": _fixture_root,
				"AEROBEAT_CAMERA_PATTERN": "video*"
			}
		}
	})
	assert_eq(tracker.get_state().get("state"), CameraTracking.STATE_ERROR)
	assert_eq(tracker.get_last_error().get("code"), "unsupported_source_kind")
	assert_eq(tracker.get_tracking_frame().get("source_kind"), "video_file")
	assert_eq(tracker.get_tracking_frame().get("source_id"), "res://clips/demo.mp4")
	assert_eq(tracker.get_preview_descriptor().get("backend"), "mediapipe_python")
	tracker.free()

func _register_vendor_backend() -> void:
	CameraTracking.register_backend_factory("mediapipe_python", func(_config: Dictionary):
		var backend = MediaPipePythonCameraTrackingBackend.new()
		backend.set_runtime_bridge(MediaPipePythonRuntimeBridge.new())
		return backend
	)

func _make_live_config(overrides: Dictionary = {}) -> Dictionary:
	var config := {
		"backend": "mediapipe_python",
		"source": {
			"kind": "live_camera",
			"camera_id": ""
		},
		"runtime": {
			"environment": {
				"AEROBEAT_CAMERA_ROOT": _fixture_root,
				"AEROBEAT_CAMERA_PATTERN": "video*",
				"AEROBEAT_CAMERA_SAMPLE_FIXTURES_JSON": JSON.stringify({
					_fixture_root.path_join("video0"): {"width": 1280, "height": 720, "timestamp_ms": 1710000000123},
					_fixture_root.path_join("video2"): {
						"width": 640,
						"height": 480,
						"timestamp_ms": 1710000000456,
						"landmarks": [
							{"id": 0, "x": 0.25, "y": 0.4, "z": -0.15, "visibility": 0.95},
							{"id": 12, "x": 0.61, "y": 0.52, "z": -0.09, "visibility": 0.88}
						]
					}
				})
			}
		}
	}
	_deep_merge(config, overrides)
	return config

func _write_fixture_camera(name: String) -> void:
	var file := FileAccess.open(_fixture_root.path_join(name), FileAccess.WRITE)
	file.store_string("fixture")
	file.close()

func _deep_merge(base: Dictionary, incoming: Dictionary) -> void:
	for key in incoming.keys():
		var incoming_value: Variant = incoming[key]
		if base.has(key) and base[key] is Dictionary and incoming_value is Dictionary:
			_deep_merge(base[key], incoming_value)
		else:
			base[key] = incoming_value
