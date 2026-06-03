extends GutTest

const MediaPipePythonCameraTrackingBackend = preload("res://addons/aerobeat-vendor-mediapipe-python/src/MediaPipePythonCameraTrackingBackend.gd")
const MediaPipePythonRuntimeBridge = preload("res://addons/aerobeat-vendor-mediapipe-python/src/MediaPipePythonRuntimeBridge.gd")

var _fixture_root := ""

class PollingFakeBackend extends CameraTrackingBackend:
	var _phase: int = 0
	var _preview_descriptor: Dictionary = {
		"backend": "polling_fake",
		"attached": false,
		"enabled": true,
		"flip_horizontal": true,
		"surface_path": NodePath(""),
		"space": "gameplay_normalized"
	}
	var _cameras: Array = [{"id": "/dev/video0", "camera_id": "/dev/video0", "label": "Polling Camera"}]

	func get_backend_id() -> String:
		return "polling_fake"

	func start(_config: Dictionary) -> void:
		_phase = 0
		emit_signal("state_changed", CameraTracking.STATE_RUNNING, _current_detail())
		emit_signal("preview_changed", _preview_descriptor.duplicate(true))
		emit_signal("cameras_changed", _cameras.duplicate(true))
		emit_signal("tracking_updated", get_tracking_frame())

	func stop() -> void:
		emit_signal("state_changed", CameraTracking.STATE_IDLE, CameraTrackingConfig.make_state_detail())

	func change(config: Dictionary) -> void:
		start(config)

	func list_cameras() -> Array:
		return _cameras.duplicate(true)

	func get_state() -> Dictionary:
		return {
			"state": CameraTracking.STATE_RUNNING,
			"detail": _current_detail()
		}

	func advance() -> void:
		_phase = min(_phase + 1, 2)

	func get_tracking_frame() -> Dictionary:
		var timestamp_ms := 1000
		var landmarks: Array = [{"id": 0, "x": 0.2, "y": 0.3, "z": -0.1, "visibility": 0.9}]
		if _phase >= 2:
			timestamp_ms = 1200
			landmarks = [{"id": 0, "x": 0.8, "y": 0.1, "z": -0.2, "visibility": 0.8}]
		elif _phase == 1:
			timestamp_ms = 1100
			landmarks = []
		return {
			"timestamp_ms": timestamp_ms,
			"backend": "polling_fake",
			"source_kind": "live_camera",
			"source_id": "/dev/video0",
			"tracking_state": "reacquiring",
			"frame_size": {"x": 640, "y": 480},
			"landmarks": landmarks,
			"head_position": {"x": 9.0, "y": 8.0, "z": 7.0},
			"skeleton": {"hips": {"x": 0.5}}
		}

	func get_preview_descriptor() -> Dictionary:
		return _preview_descriptor.duplicate(true)

	func _current_detail() -> Dictionary:
		return CameraTrackingConfig.make_state_detail({
			"backend_ready": true,
			"preview_ready": true,
			"tracking_ready": true,
			"source_ready": true
		})

class CountingPollingBackend extends PollingFakeBackend:
	var get_state_calls := 0
	var get_tracking_frame_calls := 0
	var get_preview_descriptor_calls := 0
	var list_cameras_calls := 0

	func get_state() -> Dictionary:
		get_state_calls += 1
		return super.get_state()

	func get_tracking_frame() -> Dictionary:
		get_tracking_frame_calls += 1
		return super.get_tracking_frame()

	func get_preview_descriptor() -> Dictionary:
		get_preview_descriptor_calls += 1
		return super.get_preview_descriptor()

	func list_cameras() -> Array:
		list_cameras_calls += 1
		return super.list_cameras()

	func reset_counts() -> void:
		get_state_calls = 0
		get_tracking_frame_calls = 0
		get_preview_descriptor_calls = 0
		list_cameras_calls = 0

class TeardownCountingBackend extends CameraTrackingFakeBackend:
	var stop_calls := 0

	func stop() -> void:
		stop_calls += 1
		super.stop()

class CameraOptionsFakeBackend extends CameraTrackingFakeBackend:
	var describe_calls: Array = []
	var raw_camera_options := {
		"selection_policy": "framerate_first_resolution_second_format_backend",
		"requested": {"width": 960, "height": 540, "fps": 30.0, "fourcc": "MJPG"},
		"reported_source": "reported_v4l2",
		"probe_strategy": "reported_v4l2_ranked_shortlist",
		"reported_options": [
			{"width": 1280, "height": 720, "fps": 30.0, "fourcc": "MJPG"},
			{"width": 960, "height": 540, "fps": 15.0, "fourcc": "YUYV"}
		],
		"probed_options": [
			{
				"requested": {"width": 1280, "height": 720, "fps": 30.0, "fourcc": "MJPG"},
				"selected": {"width": 1280, "height": 720, "fps": 30.0, "fourcc": "MJPG"},
				"actual": {"width": 1280, "height": 720, "fps": 30.0, "fourcc": "MJPG"},
				"fulfilled_request": true
			}
		],
		"selected": {"width": 1280, "height": 720, "fps": 30.0, "fourcc": "MJPG"},
		"actual": {"width": 1280, "height": 720, "fps": 30.0, "fourcc": "MJPG"},
		"notes": ["reported options captured"]
	}

	func get_camera_options(camera_id: String = "") -> Dictionary:
		describe_calls.append(camera_id)
		var snapshot := raw_camera_options.duplicate(true)
		snapshot["requested"]["camera_id"] = camera_id if camera_id != "" else str(last_config.get("source", {}).get("camera_id", ""))
		return snapshot

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
	assert_eq(normalized.get("backend"), "camera_tracking_default")
	assert_eq(normalized.get("source", {}).get("kind"), "live_camera")
	assert_eq(normalized.get("source", {}).get("camera_id"), "/dev/video7")
	assert_eq(normalized.get("tracking", {}).get("quality"), "optimized")
	assert_false(normalized.get("preview", {}).get("flip_horizontal"))

func test_backend_request_defaults_to_neutral_alias_and_resolves_to_vendor_backend() -> void:
	assert_eq(CameraTrackingConfig.defaults().get("backend"), "camera_tracking_default")
	assert_eq(CameraTrackingConfig.normalize_requested_backend(""), "camera_tracking_default")
	assert_eq(CameraTrackingConfig.resolve_backend_id(""), "mediapipe_python")
	assert_eq(CameraTrackingConfig.resolve_backend_id("camera_tracking_default"), "mediapipe_python")
	assert_eq(CameraTrackingConfig.resolve_backend_id("mediapipe_python"), "mediapipe_python")

func test_camera_tracking_defaults_expose_contract_shell() -> void:
	var tracker := CameraTracking.new()
	assert_eq(CameraTracking.VERSION, "0.2.0")
	assert_eq(tracker.get_state().get("state"), CameraTracking.STATE_IDLE)
	assert_eq(tracker.get_state().get("detail", {}).keys().size(), 4)
	assert_eq(tracker.get_tracking_frame().get("tracking_state"), "idle")
	assert_eq(tracker.get_tracking_frame().get("preview_transform", {}).get("space"), "gameplay_normalized")
	assert_false(tracker.get_preview_descriptor().get("attached"))
	assert_eq(int(tracker.get_preview_descriptor().get("attached_surface_count", -1)), 0)
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
	assert_eq(frame.get("backend_request"), "mediapipe_python")
	assert_eq(frame.get("backend_impl"), "mediapipe_python")
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
	assert_eq(int(tracker.get_preview_descriptor().get("attached_surface_count", -1)), 1)

	tracker.detach_preview_surface()
	assert_false(tracker.get_preview_descriptor().get("attached"))
	assert_eq(int(tracker.get_preview_descriptor().get("attached_surface_count", -1)), 0)
	parent.free()
	tracker.free()

func test_preview_surface_stack_restores_previous_attachment_when_latest_detaches() -> void:
	var tracker := CameraTracking.new()
	var parent := Node.new()
	parent.name = "Parent"
	var slot_a := Node.new()
	slot_a.name = "PreviewSlotA"
	var slot_b := Node.new()
	slot_b.name = "PreviewSlotB"
	parent.add_child(slot_a)
	parent.add_child(slot_b)

	tracker.attach_preview_surface(slot_a)
	tracker.attach_preview_surface(slot_b)
	assert_true(tracker.get_preview_descriptor().get("attached"))
	assert_eq(tracker.get_preview_descriptor().get("surface_path"), NodePath("PreviewSlotB"))
	assert_eq(int(tracker.get_preview_descriptor().get("attached_surface_count", -1)), 2)

	tracker.detach_preview_surface()
	assert_true(tracker.get_preview_descriptor().get("attached"))
	assert_eq(tracker.get_preview_descriptor().get("surface_path"), NodePath("PreviewSlotA"))
	assert_eq(int(tracker.get_preview_descriptor().get("attached_surface_count", -1)), 1)

	tracker.detach_preview_surface()
	assert_false(tracker.get_preview_descriptor().get("attached"))
	assert_eq(int(tracker.get_preview_descriptor().get("attached_surface_count", -1)), 0)
	parent.free()
	tracker.free()

func test_start_auto_bootstraps_default_vendor_backend_when_mounted() -> void:
	var tracker := CameraTracking.new()
	tracker.start(_make_live_config({
		"source": {"camera_id": _fixture_root.path_join("video2")}
	}))
	assert_eq(tracker.get_state().get("state"), CameraTracking.STATE_RUNNING)
	assert_true(CameraTracking.get_registered_backend_ids().has("mediapipe_python"))
	assert_eq(tracker.get_tracking_frame().get("backend"), "mediapipe_python")
	assert_eq(tracker.get_tracking_frame().get("source_id"), _fixture_root.path_join("video2"))
	tracker.free()

func test_start_without_registered_backend_raises_structured_error() -> void:
	var tracker := CameraTracking.new()
	tracker.start({"backend": "missing_backend"})
	assert_eq(tracker.get_state().get("state"), CameraTracking.STATE_ERROR)
	assert_eq(tracker.get_last_error().get("code"), "backend_unregistered")
	assert_eq(tracker.get_last_error().get("backend"), "missing_backend")
	assert_eq(tracker.get_last_error().get("backend_request"), "missing_backend")
	assert_eq(tracker.get_last_error().get("backend_impl"), "missing_backend")
	tracker.free()

func test_camera_tracking_surfaces_vendor_agnostic_camera_options_contract() -> void:
	var tracker := CameraTracking.new()
	var backend := CameraOptionsFakeBackend.new()
	tracker.set_backend(backend, "fake")
	tracker.start({
		"backend": "fake",
		"source": {"kind": "live_camera", "camera_id": "/dev/video0"}
	})

	var options := tracker.get_camera_options()
	assert_eq(options.get("camera_id"), "/dev/video0")
	assert_eq(options.get("backend_request"), "fake")
	assert_eq(options.get("backend_impl"), "fake")
	assert_eq(options.get("selection_policy"), "framerate_first_resolution_second_format")
	assert_eq(options.get("reported_source"), "device_report")
	assert_eq(options.get("probe_strategy"), "reported_shortlist")
	assert_eq(options.get("requested_mode", {}).get("pixel_format"), "MJPG")
	assert_eq(options.get("reported_modes", [])[1].get("pixel_format"), "YUYV")
	assert_true(options.get("probed_modes", [])[0].get("fulfilled"))
	assert_eq(options.get("probed_modes", [])[0].get("actual_mode", {}).get("width"), 1280)
	assert_eq(options.get("selected_mode", {}).get("fps"), 30.0)
	assert_eq(options.get("actual_mode", {}).get("pixel_format"), "MJPG")
	assert_eq(options.get("notes", [])[0], "reported options captured")
	tracker.free()

func test_camera_tracking_camera_options_query_accepts_explicit_camera_id() -> void:
	var tracker := CameraTracking.new()
	var backend := CameraOptionsFakeBackend.new()
	tracker.set_backend(backend, "fake")
	tracker.start({
		"backend": "fake",
		"source": {"kind": "live_camera", "camera_id": "/dev/video0"}
	})

	var explicit := tracker.get_camera_options("/dev/video2")
	assert_eq(explicit.get("camera_id"), "/dev/video2")
	assert_eq(explicit.get("requested_mode", {}).get("width"), 960)
	assert_eq(backend.describe_calls[-1], "/dev/video2")

	var cached := tracker.get_camera_options()
	assert_eq(cached.get("camera_id"), "/dev/video0")
	tracker.free()

func test_camera_tracking_camera_options_refreshes_stale_unknown_shell_while_running_live_camera() -> void:
	var tracker := CameraTracking.new()
	var backend := CameraOptionsFakeBackend.new()
	tracker.set_backend(backend, "fake")
	tracker.start({
		"backend": "fake",
		"source": {"kind": "live_camera", "camera_id": "/dev/video0"}
	})

	tracker._camera_options = CameraTrackingCameraOptions.empty(tracker.get_active_config())
	backend.describe_calls.clear()

	var refreshed := tracker.get_camera_options()
	assert_eq(backend.describe_calls, [""])
	assert_eq(refreshed.get("reported_source"), "device_report")
	assert_eq(refreshed.get("selected_mode", {}).get("fps"), 30.0)
	assert_eq(tracker._camera_options.get("reported_source"), "device_report")
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

func test_camera_tracking_refreshes_continuous_backend_updates_over_time() -> void:
	var tracker := CameraTracking.new()
	var backend := PollingFakeBackend.new()
	var tracking_events: Array = []
	var state_events: Array = []
	get_tree().root.add_child(tracker)
	tracker.tracking_updated.connect(func(frame: Dictionary): tracking_events.append(frame))
	tracker.state_changed.connect(func(state: String, detail: Dictionary): state_events.append({"state": state, "detail": detail}))
	tracker.set_backend(backend)

	tracker.start({
		"backend": "polling_fake",
		"source": {"kind": "live_camera", "camera_id": "/dev/video0"},
		"preview": {"enabled": true, "flip_horizontal": true}
	})
	assert_eq(tracker.get_state().get("state"), CameraTracking.STATE_RUNNING)
	assert_true(tracker.get_state().get("detail", {}).get("tracking_ready"))

	backend.advance()
	tracker._process(0.0)
	backend.advance()
	tracker._process(0.0)

	assert_true(tracking_events.size() >= 3)
	assert_eq(tracker.get_tracking_frame().get("timestamp_ms"), 1200)
	assert_eq(tracker.get_tracking_frame().get("tracking_state"), "tracked")
	assert_eq(tracker.get_tracking_frame().get("landmarks", []).size(), 1)
	assert_true(absf(float(tracker.get_tracking_frame().get("landmarks", [])[0].get("x")) - 0.2) < 0.0001)
	assert_eq(float(tracker.get_tracking_frame().get("landmarks", [])[0].get("v")), 0.8)
	assert_eq(tracking_events[1].get("tracking_state"), "idle")
	assert_eq(tracking_events[1].get("landmarks", []).size(), 0)
	assert_true(state_events.back().get("detail", {}).get("tracking_ready"))
	assert_eq(tracker.get_tracking_frame().get("head_position", {}).get("z"), 0.0)
	assert_eq(tracker.get_tracking_frame().get("skeleton", {}).size(), 0)
	assert_eq(tracker.get_tracking_frame().get("preview_transform", {}).get("space"), "gameplay_normalized")
	assert_true(tracker.is_running())

	tracker.stop()
	tracker.queue_free()
	await get_tree().process_frame

func test_camera_tracking_uses_cached_public_getters_between_process_ticks() -> void:
	var tracker := CameraTracking.new()
	var backend := CountingPollingBackend.new()
	get_tree().root.add_child(tracker)
	tracker.set_backend(backend)
	tracker.start({
		"backend": "polling_fake",
		"source": {"kind": "live_camera", "camera_id": "/dev/video0"},
		"preview": {"enabled": true, "flip_horizontal": true}
	})
	backend.reset_counts()

	tracker.get_state()
	tracker.get_tracking_frame()
	tracker.get_preview_descriptor()
	tracker.list_cameras()
	assert_eq(backend.get_state_calls, 0)
	assert_eq(backend.get_tracking_frame_calls, 0)
	assert_eq(backend.get_preview_descriptor_calls, 0)
	assert_eq(backend.list_cameras_calls, 0)

	tracker._process(0.0)
	assert_eq(backend.get_state_calls, 0)
	assert_eq(backend.get_tracking_frame_calls, 1)
	assert_eq(backend.get_preview_descriptor_calls, 0)
	assert_eq(backend.list_cameras_calls, 0)

	tracker.queue_free()
	await get_tree().process_frame

func test_camera_tracking_teardown_fallback_stops_running_backend_on_free() -> void:
	var tracker := CameraTracking.new()
	var backend := TeardownCountingBackend.new()
	get_tree().root.add_child(tracker)
	tracker.set_backend(backend)
	tracker.start({
		"backend": "fake",
		"source": {"kind": "live_camera", "camera_id": "/dev/video0"}
	})
	assert_eq(tracker.get_state().get("state"), CameraTracking.STATE_RUNNING)

	tracker.queue_free()
	await get_tree().process_frame

	assert_eq(backend.stop_calls, 1)
	assert_eq(backend.get_state().get("state"), CameraTracking.STATE_IDLE)

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
	assert_true(tracker.get_state().get("detail", {}).get("tracking_ready"))
	assert_true(tracker.get_state().get("detail", {}).get("source_ready"))
	assert_eq(tracker.list_cameras().size(), 2)
	assert_eq(tracker.list_cameras()[1].get("camera_id"), selected_camera_id)
	assert_eq(tracker.get_preview_descriptor().get("backend"), "mediapipe_python")
	assert_true(tracker.get_preview_descriptor().get("attached"))
	assert_eq(tracker.get_preview_descriptor().get("surface_path"), NodePath("PreviewSlot"))
	assert_eq(int(tracker.get_preview_descriptor().get("attached_surface_count", -1)), 1)
	assert_false(tracker.get_preview_descriptor().get("flip_horizontal"))
	assert_eq(tracker.get_tracking_frame().get("backend"), "mediapipe_python")
	assert_eq(tracker.get_tracking_frame().get("source_kind"), "live_camera")
	assert_eq(tracker.get_tracking_frame().get("source_id"), selected_camera_id)
	assert_eq(tracker.get_tracking_frame().get("tracking_state"), "tracked")
	assert_true(int(tracker.get_tracking_frame().get("timestamp_ms", 0)) > 0)
	assert_eq(tracker.get_tracking_frame().get("frame_size", {}).get("x"), 640)
	assert_eq(tracker.get_tracking_frame().get("frame_size", {}).get("y"), 480)
	assert_eq(tracker.get_tracking_frame().get("confidence"), 0.0)
	assert_eq(tracker.get_tracking_frame().get("landmarks", []).size(), 2)
	assert_eq(int(tracker.get_tracking_frame().get("landmarks", [])[0].get("id")), 0)
	assert_eq(float(tracker.get_tracking_frame().get("landmarks", [])[0].get("x")), 0.25)
	assert_eq(float(tracker.get_tracking_frame().get("landmarks", [])[0].get("v")), 0.95)
	assert_eq(tracker.get_tracking_frame().get("skeleton", {}).size(), 0)
	assert_true(tracker.is_running())

	var inset_slot := Node.new()
	inset_slot.name = "InsetPreviewSlot"
	parent.add_child(inset_slot)
	tracker.attach_preview_surface(inset_slot)
	assert_eq(tracker.get_preview_descriptor().get("surface_path"), NodePath("InsetPreviewSlot"))
	assert_eq(int(tracker.get_preview_descriptor().get("attached_surface_count", -1)), 2)
	tracker.detach_preview_surface()
	assert_eq(tracker.get_preview_descriptor().get("surface_path"), NodePath("PreviewSlot"))
	assert_eq(int(tracker.get_preview_descriptor().get("attached_surface_count", -1)), 1)

	parent.free()
	tracker.free()

func test_registered_vendor_backend_change_surfaces_truthful_restart_into_replay_and_public_stop() -> void:
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
	assert_true(int(tracker.get_tracking_frame().get("timestamp_ms", 0)) > 0)
	assert_eq(tracker.get_tracking_frame().get("frame_size", {}).get("x"), 640)
	assert_eq(tracker.get_tracking_frame().get("frame_size", {}).get("y"), 480)
	assert_eq(tracker.get_tracking_frame().get("tracking_state"), "tracked")
	assert_eq(tracker.get_tracking_frame().get("landmarks", []).size(), 2)
	assert_false(tracker.get_preview_descriptor().get("flip_horizontal"))
	assert_true(tracker.get_state().get("detail", {}).get("tracking_ready"))

	var replay_path := _write_fixture_video("gesture_replay.mp4")
	tracker.change(_make_replay_config(replay_path, {
		"preview": {"flip_horizontal": false}
	}))
	assert_eq(tracker.get_state().get("state"), CameraTracking.STATE_RUNNING)
	assert_true(tracker.get_state().get("detail", {}).get("backend_ready"))
	assert_true(tracker.get_state().get("detail", {}).get("preview_ready"))
	assert_true(tracker.get_state().get("detail", {}).get("tracking_ready"))
	assert_true(tracker.get_state().get("detail", {}).get("source_ready"))
	assert_eq(tracker.get_active_config().get("source", {}).get("kind"), "video_file")
	assert_eq(tracker.get_active_config().get("source", {}).get("path"), replay_path)
	assert_eq(tracker.get_tracking_frame().get("source_kind"), "video_file")
	assert_eq(tracker.get_tracking_frame().get("source_id"), replay_path)
	assert_eq(tracker.get_tracking_frame().get("tracking_state"), "tracked")
	assert_eq(int(tracker.get_tracking_frame().get("frame_size", {}).get("x", 0)), 960)
	assert_eq(int(tracker.get_tracking_frame().get("frame_size", {}).get("y", 0)), 540)
	assert_true(int(tracker.get_tracking_frame().get("timestamp_ms", 0)) >= 101)
	assert_eq(tracker.get_tracking_frame().get("landmarks", []).size(), 1)
	assert_eq(int(tracker.get_tracking_frame().get("landmarks", [])[0].get("id", -1)), 4)
	assert_eq(tracker.get_preview_descriptor().get("backend"), "mediapipe_python")
	assert_false(tracker.get_preview_descriptor().get("flip_horizontal"))

	OS.delay_msec(120)
	tracker._process(0.0)
	var replay_frame_after_poll := tracker.get_tracking_frame()
	assert_eq(replay_frame_after_poll.get("source_kind"), "video_file")
	assert_eq(replay_frame_after_poll.get("source_id"), replay_path)
	assert_true(
		int(replay_frame_after_poll.get("timestamp_ms", 0)) >= 202
		or replay_frame_after_poll.get("tracking_state") == "idle"
	)

	tracker.stop()
	assert_eq(tracker.get_state().get("state"), CameraTracking.STATE_IDLE)
	assert_false(tracker.get_state().get("detail", {}).get("backend_ready"))
	assert_false(tracker.get_state().get("detail", {}).get("preview_ready"))
	assert_false(tracker.get_state().get("detail", {}).get("tracking_ready"))
	assert_false(tracker.get_state().get("detail", {}).get("source_ready"))
	assert_eq(tracker.get_tracking_frame().get("source_kind"), "video_file")
	assert_eq(tracker.get_tracking_frame().get("source_id"), replay_path)
	assert_eq(tracker.get_tracking_frame().get("tracking_state"), "idle")
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

func _make_replay_config(replay_path: String, overrides: Dictionary = {}) -> Dictionary:
	var config := {
		"backend": "mediapipe_python",
		"source": {
			"kind": "video_file",
			"path": replay_path
		},
		"runtime": {
			"environment": {
				"AEROBEAT_CAMERA_ROOT": _fixture_root,
				"AEROBEAT_CAMERA_PATTERN": "video*",
				"AEROBEAT_CAMERA_SAMPLE_FIXTURES_JSON": JSON.stringify({
					replay_path: {
						"sequence": [
							{
								"width": 960,
								"height": 540,
								"timestamp_ms": 101,
								"landmarks": [
									{"id": 4, "x": 0.2, "y": 0.3, "z": -0.1, "visibility": 0.9}
								]
							},
							{
								"width": 960,
								"height": 540,
								"timestamp_ms": 202
							},
							{
								"width": 960,
								"height": 540,
								"timestamp_ms": 303
							}
						]
					}
				}),
				"AEROBEAT_CAMERA_REPLAY_FRAME_DELAY_MS": "100"
			}
		}
	}
	_deep_merge(config, overrides)
	return config

func _write_fixture_camera(name: String) -> void:
	var file := FileAccess.open(_fixture_root.path_join(name), FileAccess.WRITE)
	file.store_string("fixture")
	file.close()

func _write_fixture_video(name: String) -> String:
	var path := _fixture_root.path_join(name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("fixture-video")
	file.close()
	return path

func _deep_merge(base: Dictionary, incoming: Dictionary) -> void:
	for key in incoming.keys():
		var incoming_value: Variant = incoming[key]
		if base.has(key) and base[key] is Dictionary and incoming_value is Dictionary:
			_deep_merge(base[key], incoming_value)
		else:
			base[key] = incoming_value
