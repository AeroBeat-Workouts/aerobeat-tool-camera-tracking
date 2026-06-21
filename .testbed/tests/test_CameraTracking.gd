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

class PlaybackStatusFakeBackend extends CameraTrackingFakeBackend:
	var get_tracking_frame_calls := 0
	var get_playback_status_calls := 0
	var get_replay_transport_capabilities_calls := 0
	var get_replay_transport_status_calls := 0

	func start(config: Dictionary) -> void:
		playback_status = {
			"source": str(config.get("source", {}).get("path", "res://clips/demo.mp4")),
			"state": "playing",
			"paused": false,
			"current_time_sec": 3.0,
			"duration_sec": 12.0,
			"progress": 0.25,
			"is_file_source": true,
		}
		super.start(config)

	func get_tracking_frame() -> Dictionary:
		get_tracking_frame_calls += 1
		return super.get_tracking_frame()

	func get_playback_status() -> Dictionary:
		get_playback_status_calls += 1
		return super.get_playback_status()

	func get_replay_transport_capabilities() -> Dictionary:
		get_replay_transport_capabilities_calls += 1
		return super.get_replay_transport_capabilities()

	func get_replay_transport_status() -> Dictionary:
		get_replay_transport_status_calls += 1
		return super.get_replay_transport_status()

	func reset_runtime_snapshot_call_counts() -> void:
		get_tracking_frame_calls = 0
		get_playback_status_calls = 0
		get_replay_transport_capabilities_calls = 0
		get_replay_transport_status_calls = 0

	func advance_playback(current_time_sec: float, duration_sec: float) -> void:
		var safe_duration := maxf(duration_sec, 0.0)
		var safe_position := maxf(current_time_sec, 0.0)
		var progress := 0.0
		if safe_duration > 0.0:
			progress = minf(maxf(safe_position / safe_duration, 0.0), 1.0)
		playback_status = {
			"source": str(last_config.get("source", {}).get("path", "res://clips/demo.mp4")),
			"state": "playing" if safe_position < safe_duration else "ended",
			"paused": safe_position >= safe_duration,
			"current_time_sec": safe_position,
			"duration_sec": safe_duration,
			"progress": progress,
			"is_file_source": true,
		}
		emit_tracking_frame(tracking_frame)

class ReplayTransportFakeBackend extends PlaybackStatusFakeBackend:
	var play_requests := 0
	var pause_requests := 0
	var replay_transport_capabilities := {
		"transport_mode": CameraTracking.TRANSPORT_MODE_EXACT_OWNED_FRAME_INDEX,
		"can_step_forward": true,
		"can_step_backward": true,
		"can_seek_frame": true,
		"nominal_fps": 30.0,
		"frame_duration_sec": 1.0 / 30.0,
		"exactness_note": "Fake backend owns a stable replay frame index for regression coverage.",
		"limitation_code": "",
	}
	var replay_transport_status := {
		"transport_mode": CameraTracking.TRANSPORT_MODE_EXACT_OWNED_FRAME_INDEX,
		"can_step_forward": true,
		"can_step_backward": true,
		"can_seek_frame": true,
		"frame_index": 90,
		"frame_count": 360,
		"nominal_fps": 30.0,
		"frame_duration_sec": 1.0 / 30.0,
		"paused": true,
		"position_sec": 3.0,
		"duration_sec": 12.0,
		"exactness_note": "Fake backend owns a stable replay frame index for regression coverage.",
		"limitation_code": "",
	}
	var step_frame_requests: Array = []
	var seek_frame_requests: Array = []

	func get_replay_transport_capabilities() -> Dictionary:
		return replay_transport_capabilities.duplicate(true)

	func get_replay_transport_status() -> Dictionary:
		return replay_transport_status.duplicate(true)

	func play_replay() -> Dictionary:
		play_requests += 1
		replay_transport_status["paused"] = false
		playback_status["paused"] = false
		playback_status["state"] = "playing"
		return {
			CameraTrackingBackend.RESULT_SUCCESS: true,
		}

	func pause_replay() -> Dictionary:
		pause_requests += 1
		replay_transport_status["paused"] = true
		playback_status["paused"] = true
		playback_status["state"] = "paused"
		return {
			CameraTrackingBackend.RESULT_SUCCESS: true,
		}

	func step_replay_frames(delta_frames: int) -> Dictionary:
		step_frame_requests.append(delta_frames)
		var next_index := int(replay_transport_status.get("frame_index", 0)) + delta_frames
		return seek_replay_to_frame(next_index)

	func seek_replay_to_frame(frame_index: int) -> Dictionary:
		seek_frame_requests.append(frame_index)
		replay_transport_status["frame_index"] = frame_index
		replay_transport_status["paused"] = true
		var nominal_fps := float(replay_transport_status.get("nominal_fps", 30.0))
		var position_sec := float(frame_index) / nominal_fps if nominal_fps > 0.0 else 0.0
		replay_transport_status["position_sec"] = position_sec
		playback_status["paused"] = true
		playback_status["state"] = "paused"
		playback_status["current_time_sec"] = position_sec
		playback_status["progress"] = position_sec / maxf(float(playback_status.get("duration_sec", 0.0)), 0.0001)
		tracking_frame["frame_index"] = frame_index
		tracking_frame["timestamp_ms"] = int(round(position_sec * 1000.0))
		emit_tracking_frame(tracking_frame)
		return {
			CameraTrackingBackend.RESULT_SUCCESS: true,
			"frame_index": frame_index,
			"position_sec": position_sec,
		}

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

func test_config_normalization_resolves_live_and_replay_preview_contracts_and_live_camera_requests() -> void:
	var live_config := CameraTrackingConfig.normalize({
		"source": {
			"kind": "live_camera",
			"camera_id": "/dev/video7",
			"live_camera": {
				"requested_width": 1280,
				"requested_height": 720,
				"requested_fps": 24,
			}
		},
		"preview": {
			"surface_mode": "attach",
			"flip_horizontal": false,
			"live": {
				"enabled": false,
				"max_fps": 6,
				"width": 640,
				"height": 360,
				"quality": 55,
			},
			"replay": {
				"enabled": true,
				"max_fps": 12,
				"width": 800,
				"height": 450,
				"quality": 82,
			},
			"overlays": {
				"pose_skeleton_visible": false,
				"hand_bbox_visible": true,
			}
		}
	})
	assert_false(bool(live_config.get("preview", {}).get("enabled", true)))
	assert_eq(int(live_config.get("preview", {}).get("max_fps", -1)), 6)
	assert_eq(int(live_config.get("preview", {}).get("width", -1)), 640)
	assert_eq(int(live_config.get("runtime", {}).get("preview_width", -1)), 640)
	assert_eq(int(live_config.get("runtime", {}).get("live_camera_width", -1)), 1280)
	assert_eq(int(live_config.get("runtime", {}).get("live_camera_height", -1)), 720)
	assert_eq(int(live_config.get("runtime", {}).get("live_camera_fps", -1)), 24)
	assert_false(bool(live_config.get("preview", {}).get("overlays", {}).get("pose_skeleton_visible", true)))
	assert_true(bool(live_config.get("preview", {}).get("overlays", {}).get("hand_bbox_visible", false)))

	var replay_config := CameraTrackingConfig.normalize({
		"source": {"kind": "video_file", "path": "res://clips/demo.mp4"},
		"preview": {
			"live": {"enabled": false, "max_fps": 6, "width": 640, "height": 360, "quality": 55},
			"replay": {"enabled": true, "max_fps": 12, "width": 800, "height": 450, "quality": 82},
		}
	})
	assert_true(bool(replay_config.get("preview", {}).get("enabled", false)))
	assert_eq(int(replay_config.get("preview", {}).get("max_fps", -1)), 12)
	assert_eq(int(replay_config.get("preview", {}).get("width", -1)), 800)
	assert_eq(int(replay_config.get("preview", {}).get("height", -1)), 450)
	assert_eq(int(replay_config.get("preview", {}).get("quality", -1)), 82)
	assert_eq(int(replay_config.get("runtime", {}).get("preview_width", -1)), 800)

func test_backend_request_defaults_to_neutral_alias_and_resolves_to_vendor_backend() -> void:
	assert_eq(CameraTrackingConfig.defaults().get("backend"), "camera_tracking_default")
	assert_eq(CameraTrackingConfig.normalize_requested_backend(""), "camera_tracking_default")
	assert_eq(CameraTrackingConfig.resolve_backend_id(""), "mediapipe_python")
	assert_eq(CameraTrackingConfig.resolve_backend_id("camera_tracking_default"), "mediapipe_python")
	assert_eq(CameraTrackingConfig.resolve_backend_id("mediapipe_python"), "mediapipe_python")

func test_camera_tracking_defaults_expose_contract_shell() -> void:
	var tracker := CameraTracking.new()
	assert_eq(CameraTracking.VERSION, "0.3.0")
	assert_eq(tracker.get_state().get("state"), CameraTracking.STATE_IDLE)
	assert_eq(tracker.get_state().get("detail", {}).keys().size(), 4)
	assert_eq(tracker.get_tracking_frame().get("tracking_state"), "idle")
	assert_eq(tracker.get_tracking_frame().get("preview_transform", {}).get("space"), "gameplay_normalized")
	assert_false(tracker.get_preview_descriptor().get("attached"))
	assert_eq(int(tracker.get_preview_descriptor().get("attached_surface_count", -1)), 0)
	assert_eq(tracker.get_playback_status(), {})
	tracker.free()

func test_camera_tracking_exposes_backend_playback_status_through_public_contract() -> void:
	var tracker := CameraTracking.new()
	var backend := PlaybackStatusFakeBackend.new()
	tracker.set_backend(backend, "fake")
	tracker.start({
		"backend": "fake",
		"source": {"kind": "video_file", "path": "res://clips/demo.mp4"}
	})

	assert_eq(tracker.get_playback_status().get("source"), "res://clips/demo.mp4")
	assert_eq(tracker.get_playback_status().get("current_time_sec"), 3.0)
	assert_eq(tracker.get_playback_status().get("duration_sec"), 12.0)
	assert_eq(tracker.get_playback_status().get("progress"), 0.25)
	assert_true(tracker.get_playback_status().get("is_file_source"))

	backend.advance_playback(6.0, 12.0)
	assert_eq(tracker.get_playback_status().get("current_time_sec"), 6.0)
	assert_eq(tracker.get_playback_status().get("progress"), 0.5)
	tracker.free()


func test_camera_tracking_derives_truthful_replay_transport_fallback_from_backend_playback_status() -> void:
	var tracker := CameraTracking.new()
	var backend := PlaybackStatusFakeBackend.new()
	tracker.set_backend(backend, "fake")
	tracker.start({
		"backend": "fake",
		"source": {"kind": "video_file", "path": "res://clips/demo.mp4"}
	})

	var capabilities := tracker.get_replay_transport_capabilities()
	assert_eq(String(capabilities.get("transport_mode", "")), CameraTracking.TRANSPORT_MODE_APPROX_TIME_SEEK)
	assert_false(bool(capabilities.get("can_step_forward", true)))
	assert_false(bool(capabilities.get("can_seek_frame", true)))
	assert_eq(String(capabilities.get("limitation_code", "")), CameraTracking.REPLAY_TRANSPORT_UNSUPPORTED_CODE)

	var status := tracker.get_replay_transport_status()
	assert_eq(float(status.get("position_sec", -1.0)), 3.0)
	assert_eq(float(status.get("duration_sec", -1.0)), 12.0)
	assert_false(bool(status.get("paused", true)))

	var result := tracker.step_replay_frames(1)
	assert_false(bool(result.get(CameraTrackingBackend.RESULT_SUCCESS, true)))
	assert_eq(String(result.get(CameraTrackingBackend.RESULT_CODE, "")), CameraTracking.REPLAY_TRANSPORT_UNSUPPORTED_CODE)
	assert_eq(tracker.get_state().get("state"), CameraTracking.STATE_RUNNING)
	assert_eq(tracker.get_playback_status().get("current_time_sec"), 3.0)
	tracker.free()

func test_camera_tracking_delegates_exact_replay_transport_methods_through_public_contract() -> void:
	var tracker := CameraTracking.new()
	var backend := ReplayTransportFakeBackend.new()
	tracker.set_backend(backend, "fake")
	tracker.start({
		"backend": "fake",
		"source": {"kind": "video_file", "path": "res://clips/demo.mp4"}
	})

	assert_eq(String(tracker.get_replay_transport_capabilities().get("transport_mode", "")), CameraTracking.TRANSPORT_MODE_EXACT_OWNED_FRAME_INDEX)
	assert_eq(int(tracker.get_replay_transport_status().get("frame_index", -1)), 90)

	var step_result := tracker.step_replay_frames(3)
	assert_true(bool(step_result.get(CameraTrackingBackend.RESULT_SUCCESS, false)))
	assert_eq(backend.step_frame_requests, [3])
	assert_eq(backend.seek_frame_requests, [93])
	assert_eq(int(tracker.get_replay_transport_status().get("frame_index", -1)), 93)
	assert_eq(float(tracker.get_playback_status().get("current_time_sec", -1.0)), 3.1)

	var seek_result := tracker.seek_replay_to_frame(120)
	assert_true(bool(seek_result.get(CameraTrackingBackend.RESULT_SUCCESS, false)))
	assert_eq(backend.seek_frame_requests, [93, 120])
	assert_eq(int(tracker.get_replay_transport_status().get("frame_index", -1)), 120)
	assert_eq(int(tracker.get_tracking_frame().get("frame_index", -1)), 120)
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

func test_config_normalization_adds_tracker_pose_and_hand_defaults() -> void:
	var config := CameraTrackingConfig.normalize({
		"tracking": {
			"max_fps": 30,
			"state_update_max_fps": 24,
			"pose": {
				"smoothing_style": "lite_raw",
				"inference_interval_frames": 3
			},
			"hands": {
				"enabled": true,
				"landmark_mode": "full",
				"inference_interval_frames": 4,
				"association": {
					"prefer_existing_pose_side_binding": false
				},
				"validity": {
					"max_stale_ms": 280,
					"reacquire_stable_ms": 40
				}
			}
		}
	})
	assert_eq(config.get("tracking", {}).get("max_fps"), 30)
	assert_eq(config.get("tracking", {}).get("state_update_max_fps"), 24)
	assert_eq(config.get("tracking", {}).get("pose", {}).get("enabled"), true)
	assert_eq(config.get("tracking", {}).get("pose", {}).get("inference_interval_frames"), 3)
	assert_eq(config.get("tracking", {}).get("pose", {}).get("smoothing_style"), "lite_raw")
	assert_eq(config.get("tracking", {}).get("hands", {}).get("enabled"), true)
	assert_eq(config.get("tracking", {}).get("hands", {}).get("landmark_mode"), "full")
	assert_false(config.get("tracking", {}).get("hands", {}).has("bbox_recompute_interval_frames"))
	assert_eq(config.get("tracking", {}).get("hands", {}).get("association", {}).get("prefer_existing_pose_side_binding"), false)
	assert_eq(config.get("tracking", {}).get("hands", {}).get("association", {}).get("nearest_wrist_fallback"), true)
	assert_eq(config.get("tracking", {}).get("hands", {}).get("validity", {}).get("max_stale_ms"), 280)
	assert_eq(config.get("tracking", {}).get("hands", {}).get("validity", {}).get("reacquire_stable_ms"), 40)
	assert_eq(config.get("runtime", {}).get("pose_inference_interval_frames"), 3)
	assert_eq(config.get("runtime", {}).get("pose_smoothing_style"), "lite_raw")
	assert_eq(config.get("runtime", {}).get("no_filter"), true)
	assert_eq(config.get("runtime", {}).get("hand_tracking_enabled"), true)
	assert_eq(config.get("runtime", {}).get("hand_landmark_mode"), "full")
	assert_eq(config.get("runtime", {}).get("tracking_max_fps"), 30)
	assert_eq(config.get("runtime", {}).get("state_update_max_fps"), 24)
	assert_false(config.get("runtime", {}).has("hand_bbox_recompute_interval_frames"))

func test_frame_normalization_builds_per_side_hand_payload_from_vendor_samples() -> void:
	var config := {
		"backend": "mediapipe_python",
		"source": {"kind": "live_camera", "camera_id": "/dev/video0"},
		"preview": {"flip_horizontal": false},
		"tracking": {
			"hands": {
				"enabled": true,
				"landmark_mode": "lite",
				"inference_interval_frames": 2,
				"validity": {
					"max_stale_ms": 80,
					"reacquire_stable_ms": 40
				}
			}
		}
	}
	var frame := CameraTrackingFrame.normalize({
		"timestamp_ms": 500,
		"landmarks": [
			{"id": 15, "x": 0.25, "y": 0.5, "z": 0.0, "visibility": 0.9},
			{"id": 16, "x": 0.75, "y": 0.5, "z": 0.0, "visibility": 0.9}
		],
		"hands": [
			{
				"label": "Right",
				"score": 0.91,
				"landmarks": [{"id": 0, "x": 0.24, "y": 0.49, "z": 0.0}],
				"bbox": {"x": 0.20, "y": 0.40, "width": 0.10, "height": 0.20, "area": 0.02}
			},
			{
				"label": "Left",
				"score": 0.89,
				"landmarks": [{"id": 0, "x": 0.76, "y": 0.49, "z": 0.0}],
				"bbox": {"x": 0.70, "y": 0.40, "width": 0.10, "height": 0.20, "area": 0.02}
			}
		],
		"vendor_hand_tracking": {
			"available": true,
			"landmark_mode": "lite",
			"inference_backend": "mediapipe_tasks_hand_landmarker",
			"inference_interval_frames": 2,
			"inference_ran": true,
			"carried_forward": false,
			"source_frame_index": 1,
			"max_stale_ms": 80,
			"reacquire_stable_ms": 40
		}
	}, config)
	var left_hand: Dictionary = frame.get("hands", {}).get("left", {})
	var right_hand: Dictionary = frame.get("hands", {}).get("right", {})
	assert_eq(frame.get("frame_index"), 1)
	assert_eq(frame.get("timestamp_seconds"), 0.5)
	assert_eq(frame.get("hand_tracking", {}).get("inference_interval_frames"), 2)
	assert_false(frame.get("hand_tracking", {}).has("bbox_recompute_interval_frames"))
	assert_eq(left_hand.get("tracking_state"), "reacquiring")
	assert_false(left_hand.get("tracking_valid"))
	assert_eq(left_hand.get("association", {}).get("method"), "nearest_wrist_fallback")
	assert_eq(left_hand.get("association", {}).get("source_label"), "right")
	assert_eq(left_hand.get("landmarks", []).size(), 1)
	assert_eq(left_hand.get("bbox", {}).get("area_unit"), "normalized_frame_area")
	assert_true(bool(left_hand.get("fresh_sample", false)))
	assert_eq(String(left_hand.get("sample_source", "")), "fresh_inference")
	assert_eq(int(left_hand.get("source_frame_index", -1)), 1)
	assert_eq(right_hand.get("tracking_state"), "reacquiring")
	assert_false(right_hand.get("tracking_valid"))
	assert_eq(right_hand.get("association", {}).get("source_label"), "left")

func test_frame_normalization_marks_carried_forward_hand_samples_as_not_fresh() -> void:
	var config := {
		"backend": "mediapipe_python",
		"source": {"kind": "live_camera", "camera_id": "/dev/video0"},
		"preview": {"flip_horizontal": false},
		"tracking": {
			"hands": {
				"enabled": true,
				"landmark_mode": "lite",
				"inference_interval_frames": 3,
				"validity": {
					"max_stale_ms": 80,
					"reacquire_stable_ms": 0
				}
			}
		}
	}
	var first := CameraTrackingFrame.normalize({
		"frame_index": 4,
		"timestamp_ms": 400,
		"landmarks": [
			{"id": 15, "x": 0.25, "y": 0.5, "z": 0.0, "visibility": 0.9}
		],
		"hands": [
			{
				"label": "Right",
				"score": 0.91,
				"landmarks": [{"id": 0, "x": 0.24, "y": 0.49, "z": 0.0}],
				"bbox": {"x": 0.20, "y": 0.40, "width": 0.10, "height": 0.20}
			}
		],
		"vendor_hand_tracking": {
			"available": true,
			"landmark_mode": "lite",
			"inference_backend": "mediapipe_tasks_hand_landmarker",
			"inference_interval_frames": 3,
			"inference_ran": true,
			"carried_forward": false,
			"source_frame_index": 4,
			"max_stale_ms": 80,
			"reacquire_stable_ms": 0
		}
	}, config)
	var carried := CameraTrackingFrame.normalize({
		"frame_index": 5,
		"timestamp_ms": 433,
		"landmarks": [
			{"id": 15, "x": 0.25, "y": 0.5, "z": 0.0, "visibility": 0.9}
		],
		"hands": [
			{
				"label": "Right",
				"score": 0.91,
				"landmarks": [{"id": 0, "x": 0.24, "y": 0.49, "z": 0.0}],
				"bbox": {"x": 0.20, "y": 0.40, "width": 0.10, "height": 0.20}
			}
		],
		"vendor_hand_tracking": {
			"available": true,
			"landmark_mode": "lite",
			"inference_backend": "mediapipe_tasks_hand_landmarker",
			"inference_interval_frames": 3,
			"inference_ran": false,
			"carried_forward": true,
			"source_frame_index": 4,
			"max_stale_ms": 80,
			"reacquire_stable_ms": 0
		}
	}, config, first)
	var hand: Dictionary = carried.get("hands", {}).get("left", {})
	assert_false(bool(hand.get("fresh_sample", true)))
	assert_eq(String(hand.get("sample_source", "")), "carried_forward")
	assert_eq(int(hand.get("source_frame_index", -1)), 4)
	assert_true(bool(hand.get("tracking_valid", false)))
	assert_eq(String(hand.get("tracking_state", "")), "tracked")

func test_frame_normalization_reacquire_uses_elapsed_milliseconds() -> void:
	var config := {
		"backend": "mediapipe_python",
		"source": {"kind": "live_camera", "camera_id": "/dev/video0"},
		"preview": {"flip_horizontal": false},
		"tracking": {
			"hands": {
				"enabled": true,
				"validity": {
					"max_stale_ms": 80,
					"reacquire_stable_ms": 40
				}
			}
		}
	}
	var first := CameraTrackingFrame.normalize({
		"timestamp_ms": 100,
		"landmarks": [{"id": 15, "x": 0.20, "y": 0.5, "z": 0.0, "visibility": 0.9}],
		"hands": [{
			"label": "Left",
			"score": 0.95,
			"landmarks": [{"id": 0, "x": 0.21, "y": 0.5, "z": 0.0}],
			"bbox": {"x": 0.18, "y": 0.42, "width": 0.08, "height": 0.16}
		}],
		"vendor_hand_tracking": {"available": true}
	}, config)
	var second := CameraTrackingFrame.normalize({
		"timestamp_ms": 130,
		"landmarks": [{"id": 15, "x": 0.21, "y": 0.5, "z": 0.0, "visibility": 0.9}],
		"hands": [{
			"label": "Left",
			"score": 0.96,
			"landmarks": [{"id": 0, "x": 0.22, "y": 0.5, "z": 0.0}],
			"bbox": {"x": 0.19, "y": 0.42, "width": 0.08, "height": 0.16}
		}],
		"vendor_hand_tracking": {"available": true}
	}, config, first)
	var third := CameraTrackingFrame.normalize({
		"timestamp_ms": 140,
		"landmarks": [{"id": 15, "x": 0.22, "y": 0.5, "z": 0.0, "visibility": 0.9}],
		"hands": [{
			"label": "Left",
			"score": 0.97,
			"landmarks": [{"id": 0, "x": 0.23, "y": 0.5, "z": 0.0}],
			"bbox": {"x": 0.20, "y": 0.42, "width": 0.08, "height": 0.16}
		}],
		"vendor_hand_tracking": {"available": true}
	}, config, second)
	assert_eq(first.get("hands", {}).get("left", {}).get("tracking_state"), "reacquiring")
	assert_eq(int(first.get("hands", {}).get("left", {}).get("stable_ms", -1)), 0)
	assert_eq(second.get("hands", {}).get("left", {}).get("tracking_state"), "reacquiring")
	assert_eq(int(second.get("hands", {}).get("left", {}).get("stable_ms", -1)), 30)
	assert_false(bool(second.get("hands", {}).get("left", {}).get("tracking_valid", true)))
	assert_eq(third.get("hands", {}).get("left", {}).get("tracking_state"), "tracked")
	assert_eq(int(third.get("hands", {}).get("left", {}).get("stable_ms", -1)), 40)
	assert_true(bool(third.get("hands", {}).get("left", {}).get("tracking_valid", false)))

func test_frame_normalization_ignores_legacy_vendor_frame_timing_aliases() -> void:
	var config := {
		"backend": "mediapipe_python",
		"source": {"kind": "live_camera", "camera_id": "/dev/video0"},
		"preview": {"flip_horizontal": false},
		"tracking": {
			"hands": {
				"enabled": true,
				"validity": {
					"max_stale_ms": 80,
					"reacquire_stable_ms": 40
				}
			}
		}
	}
	var first := CameraTrackingFrame.normalize({
		"timestamp_ms": 100,
		"landmarks": [{"id": 15, "x": 0.20, "y": 0.5, "z": 0.0, "visibility": 0.9}],
		"hands": [{
			"label": "Left",
			"score": 0.95,
			"landmarks": [{"id": 0, "x": 0.21, "y": 0.5, "z": 0.0}],
			"bbox": {"x": 0.18, "y": 0.42, "width": 0.08, "height": 0.16}
		}],
		"vendor_hand_tracking": {
			"available": true,
			"max_stale_frames": 2,
			"reacquire_stable_frames": 2
		}
	}, config)
	var second := CameraTrackingFrame.normalize({
		"timestamp_ms": 140,
		"landmarks": [{"id": 15, "x": 0.20, "y": 0.5, "z": 0.0, "visibility": 0.9}],
		"hands": [],
		"vendor_hand_tracking": {
			"available": true,
			"max_stale_frames": 2,
			"reacquire_stable_frames": 2
		}
	}, config, first)
	assert_eq(int(first.get("hand_tracking", {}).get("max_stale_ms", -1)), 80)
	assert_eq(int(first.get("hand_tracking", {}).get("reacquire_stable_ms", -1)), 40)
	assert_eq(second.get("hands", {}).get("left", {}).get("tracking_state"), "grace")
	assert_eq(int(second.get("hands", {}).get("left", {}).get("grace_ms", -1)), 40)

func test_frame_normalization_carries_stale_hands_until_validity_budget_expires() -> void:
	var config := {
		"backend": "mediapipe_python",
		"source": {"kind": "live_camera", "camera_id": "/dev/video0"},
		"preview": {"flip_horizontal": false},
		"tracking": {
			"hands": {
				"enabled": true,
				"validity": {
					"max_stale_ms": 80,
					"reacquire_stable_ms": 0
				}
			}
		}
	}
	var first := CameraTrackingFrame.normalize({
		"timestamp_ms": 100,
		"landmarks": [
			{"id": 15, "x": 0.20, "y": 0.5, "z": 0.0, "visibility": 0.9}
		],
		"hands": [
			{
				"label": "Left",
				"score": 0.95,
				"landmarks": [{"id": 0, "x": 0.21, "y": 0.5, "z": 0.0}],
				"bbox": {"x": 0.18, "y": 0.42, "width": 0.08, "height": 0.16}
			}
		],
		"vendor_hand_tracking": {
			"available": true,
			"landmark_mode": "lite",
			"inference_backend": "mediapipe_tasks_hand_landmarker"
		}
	}, config)
	var second := CameraTrackingFrame.normalize({
		"timestamp_ms": 140,
		"landmarks": [
			{"id": 15, "x": 0.20, "y": 0.5, "z": 0.0, "visibility": 0.9}
		],
		"hands": [],
		"vendor_hand_tracking": {
			"available": true,
			"landmark_mode": "lite",
			"inference_backend": "mediapipe_tasks_hand_landmarker"
		}
	}, config, first)
	var third := CameraTrackingFrame.normalize({
		"timestamp_ms": 180,
		"landmarks": [
			{"id": 15, "x": 0.20, "y": 0.5, "z": 0.0, "visibility": 0.9}
		],
		"hands": [],
		"vendor_hand_tracking": {
			"available": true,
			"landmark_mode": "lite",
			"inference_backend": "mediapipe_tasks_hand_landmarker"
		}
	}, config, second)
	var fourth := CameraTrackingFrame.normalize({
		"timestamp_ms": 220,
		"landmarks": [
			{"id": 15, "x": 0.20, "y": 0.5, "z": 0.0, "visibility": 0.9}
		],
		"hands": [],
		"vendor_hand_tracking": {
			"available": true,
			"landmark_mode": "lite",
			"inference_backend": "mediapipe_tasks_hand_landmarker"
		}
	}, config, third)
	assert_eq(first.get("hands", {}).get("left", {}).get("tracking_state"), "tracked")
	assert_true(first.get("hands", {}).get("left", {}).get("tracking_valid"))
	assert_eq(second.get("hands", {}).get("left", {}).get("tracking_state"), "grace")
	assert_true(second.get("hands", {}).get("left", {}).get("tracking_valid"))
	assert_true(bool(second.get("hands", {}).get("left", {}).get("predicted", false)))
	assert_eq(second.get("hands", {}).get("left", {}).get("grace_frames"), 1)
	assert_eq(second.get("hands", {}).get("left", {}).get("stale_frames"), 1)
	assert_eq(second.get("hands", {}).get("left", {}).get("stale_ms"), 40)
	assert_eq(second.get("hands", {}).get("left", {}).get("grace_ms"), 40)
	assert_eq(third.get("hands", {}).get("left", {}).get("tracking_state"), "grace")
	assert_eq(third.get("hands", {}).get("left", {}).get("grace_frames"), 2)
	assert_eq(third.get("hands", {}).get("left", {}).get("stale_frames"), 2)
	assert_eq(third.get("hands", {}).get("left", {}).get("stale_ms"), 80)
	assert_eq(third.get("hands", {}).get("left", {}).get("grace_ms"), 80)
	assert_eq(fourth.get("hands", {}).get("left", {}).get("tracking_state"), "tracking_lost")
	assert_false(fourth.get("hands", {}).get("left", {}).get("tracking_valid"))
	assert_eq(fourth.get("hands", {}).get("left", {}).get("stale_frames"), 3)
	assert_eq(fourth.get("hands", {}).get("left", {}).get("stale_ms"), 120)

func test_frame_normalization_predicts_grace_bbox_from_recent_trend() -> void:
	var config := {
		"backend": "mediapipe_python",
		"source": {"kind": "live_camera", "camera_id": "/dev/video0"},
		"preview": {"flip_horizontal": false},
		"tracking": {
			"hands": {
				"enabled": true,
				"validity": {
					"max_stale_ms": 80,
					"reacquire_stable_ms": 0
				},
				"grace": {
					"enabled": true,
					"position_decay": 1.0,
					"size_decay": 1.0
				}
			}
		}
	}
	var first := CameraTrackingFrame.normalize({
		"timestamp_ms": 100,
		"landmarks": [
			{"id": 15, "x": 0.20, "y": 0.50, "z": 0.0, "visibility": 0.9}
		],
		"hands": [{
			"label": "Left",
			"score": 0.95,
			"landmarks": [{"id": 0, "x": 0.18, "y": 0.50, "z": 0.0}],
			"bbox": {"x": 0.14, "y": 0.42, "width": 0.08, "height": 0.12}
		}],
		"vendor_hand_tracking": {"available": true}
	}, config)
	var tracked := CameraTrackingFrame.normalize({
		"timestamp_ms": 140,
		"landmarks": [
			{"id": 15, "x": 0.25, "y": 0.48, "z": 0.0, "visibility": 0.9}
		],
		"hands": [{
			"label": "Left",
			"score": 0.96,
			"landmarks": [{"id": 0, "x": 0.24, "y": 0.48, "z": 0.0}],
			"bbox": {"x": 0.18, "y": 0.40, "width": 0.10, "height": 0.14}
		}],
		"vendor_hand_tracking": {"available": true}
	}, config, first)
	var grace := CameraTrackingFrame.normalize({
		"timestamp_ms": 180,
		"landmarks": [
			{"id": 15, "x": 0.30, "y": 0.46, "z": 0.0, "visibility": 0.9}
		],
		"hands": [],
		"vendor_hand_tracking": {"available": true}
	}, config, tracked)
	var bbox: Dictionary = grace.get("hands", {}).get("left", {}).get("bbox", {})
	assert_eq(grace.get("hands", {}).get("left", {}).get("tracking_state"), "grace")
	assert_true(bool(grace.get("hands", {}).get("left", {}).get("predicted", false)))
	assert_true(is_equal_approx(float(bbox.get("x", 0.0)), 0.22))
	assert_true(is_equal_approx(float(bbox.get("y", 0.0)), 0.38))
	assert_true(is_equal_approx(float(bbox.get("width", 0.0)), 0.12))
	assert_true(is_equal_approx(float(bbox.get("height", 0.0)), 0.16))
	assert_true(is_equal_approx(float(bbox.get("area", 0.0)), 0.0192))

func test_frame_normalization_preserves_pose_side_lock_across_tracking_lost_reacquire() -> void:
	var config := {
		"backend": "mediapipe_python",
		"source": {"kind": "live_camera", "camera_id": "/dev/video0"},
		"preview": {"flip_horizontal": false},
		"tracking": {
			"hands": {
				"enabled": true,
				"validity": {
					"max_stale_ms": 40,
					"reacquire_stable_ms": 0
				}
			}
		}
	}
	var first := CameraTrackingFrame.normalize({
		"timestamp_ms": 100,
		"landmarks": [
			{"id": 15, "x": 0.20, "y": 0.50, "z": 0.0, "visibility": 0.9},
			{"id": 16, "x": 0.80, "y": 0.50, "z": 0.0, "visibility": 0.9}
		],
		"hands": [
			{
				"label": "Left",
				"score": 0.95,
				"landmarks": [{"id": 0, "x": 0.21, "y": 0.50, "z": 0.0}],
				"bbox": {"x": 0.18, "y": 0.42, "width": 0.08, "height": 0.16}
			},
			{
				"label": "Right",
				"score": 0.94,
				"landmarks": [{"id": 0, "x": 0.79, "y": 0.50, "z": 0.0}],
				"bbox": {"x": 0.75, "y": 0.42, "width": 0.08, "height": 0.16}
			}
		],
		"vendor_hand_tracking": {
			"available": true,
			"landmark_mode": "lite",
			"inference_backend": "mediapipe_tasks_hand_landmarker"
		}
	}, config)
	var stale := CameraTrackingFrame.normalize({
		"timestamp_ms": 140,
		"landmarks": [
			{"id": 15, "x": 0.20, "y": 0.50, "z": 0.0, "visibility": 0.9},
			{"id": 16, "x": 0.80, "y": 0.50, "z": 0.0, "visibility": 0.9}
		],
		"hands": [],
		"vendor_hand_tracking": {
			"available": true,
			"landmark_mode": "lite",
			"inference_backend": "mediapipe_tasks_hand_landmarker"
		}
	}, config, first)
	var lost := CameraTrackingFrame.normalize({
		"timestamp_ms": 190,
		"landmarks": [
			{"id": 15, "x": 0.20, "y": 0.50, "z": 0.0, "visibility": 0.9},
			{"id": 16, "x": 0.80, "y": 0.50, "z": 0.0, "visibility": 0.9}
		],
		"hands": [],
		"vendor_hand_tracking": {
			"available": true,
			"landmark_mode": "lite",
			"inference_backend": "mediapipe_tasks_hand_landmarker"
		}
	}, config, stale)
	var reacquired := CameraTrackingFrame.normalize({
		"timestamp_ms": 240,
		"landmarks": [
			{"id": 15, "x": 0.78, "y": 0.50, "z": 0.0, "visibility": 0.9},
			{"id": 16, "x": 0.22, "y": 0.50, "z": 0.0, "visibility": 0.9}
		],
		"hands": [
			{
				"label": "Left",
				"score": 0.96,
				"landmarks": [{"id": 0, "x": 0.79, "y": 0.50, "z": 0.0}],
				"bbox": {"x": 0.75, "y": 0.42, "width": 0.08, "height": 0.16}
			},
			{
				"label": "Right",
				"score": 0.93,
				"landmarks": [{"id": 0, "x": 0.21, "y": 0.50, "z": 0.0}],
				"bbox": {"x": 0.17, "y": 0.42, "width": 0.08, "height": 0.16}
			}
		],
		"vendor_hand_tracking": {
			"available": true,
			"landmark_mode": "lite",
			"inference_backend": "mediapipe_tasks_hand_landmarker"
		}
	}, config, lost)
	assert_eq(stale.get("hands", {}).get("left", {}).get("tracking_state"), "grace")
	assert_eq(lost.get("hands", {}).get("left", {}).get("tracking_state"), "tracking_lost")
	assert_true(bool(lost.get("hands", {}).get("left", {}).get("_pose_side_locked", false)))
	assert_eq(reacquired.get("hands", {}).get("left", {}).get("association", {}).get("method"), "prefer_existing_pose_side_binding")
	assert_eq(reacquired.get("hands", {}).get("right", {}).get("association", {}).get("method"), "prefer_existing_pose_side_binding")
	assert_eq(reacquired.get("hands", {}).get("left", {}).get("association", {}).get("source_label"), "left")
	assert_eq(reacquired.get("hands", {}).get("right", {}).get("association", {}).get("source_label"), "right")
	assert_eq(reacquired.get("hands", {}).get("left", {}).get("landmarks", [])[0].get("x"), 0.79)
	assert_eq(reacquired.get("hands", {}).get("right", {}).get("landmarks", [])[0].get("x"), 0.21)

func test_frame_normalization_single_reacquired_candidate_chooses_nearest_locked_side_without_left_bias() -> void:
	var config := {
		"backend": "mediapipe_python",
		"source": {"kind": "live_camera", "camera_id": "/dev/video0"},
		"preview": {"flip_horizontal": false},
		"tracking": {
			"hands": {
				"enabled": true,
				"validity": {
					"max_stale_ms": 40,
					"reacquire_stable_ms": 0
				}
			}
		}
	}
	var tracked := CameraTrackingFrame.normalize({
		"timestamp_ms": 100,
		"landmarks": [
			{"id": 15, "x": 0.20, "y": 0.50, "z": 0.0, "visibility": 0.9},
			{"id": 16, "x": 0.80, "y": 0.50, "z": 0.0, "visibility": 0.9}
		],
		"hands": [
			{
				"label": "Left",
				"score": 0.95,
				"landmarks": [{"id": 0, "x": 0.21, "y": 0.50, "z": 0.0}],
				"bbox": {"x": 0.18, "y": 0.42, "width": 0.08, "height": 0.16}
			},
			{
				"label": "Right",
				"score": 0.94,
				"landmarks": [{"id": 0, "x": 0.79, "y": 0.50, "z": 0.0}],
				"bbox": {"x": 0.75, "y": 0.42, "width": 0.08, "height": 0.16}
			}
		],
		"vendor_hand_tracking": {
			"available": true,
			"landmark_mode": "lite",
			"inference_backend": "mediapipe_tasks_hand_landmarker"
		}
	}, config)
	var stale := CameraTrackingFrame.normalize({
		"timestamp_ms": 140,
		"landmarks": [
			{"id": 15, "x": 0.20, "y": 0.50, "z": 0.0, "visibility": 0.9},
			{"id": 16, "x": 0.80, "y": 0.50, "z": 0.0, "visibility": 0.9}
		],
		"hands": [],
		"vendor_hand_tracking": {
			"available": true,
			"landmark_mode": "lite",
			"inference_backend": "mediapipe_tasks_hand_landmarker"
		}
	}, config, tracked)
	var lost := CameraTrackingFrame.normalize({
		"timestamp_ms": 190,
		"landmarks": [
			{"id": 15, "x": 0.20, "y": 0.50, "z": 0.0, "visibility": 0.9},
			{"id": 16, "x": 0.80, "y": 0.50, "z": 0.0, "visibility": 0.9}
		],
		"hands": [],
		"vendor_hand_tracking": {
			"available": true,
			"landmark_mode": "lite",
			"inference_backend": "mediapipe_tasks_hand_landmarker"
		}
	}, config, stale)
	var one_candidate_reacquired := CameraTrackingFrame.normalize({
		"timestamp_ms": 400,
		"landmarks": [
			{"id": 15, "x": 0.20, "y": 0.50, "z": 0.0, "visibility": 0.9},
			{"id": 16, "x": 0.74, "y": 0.50, "z": 0.0, "visibility": 0.9}
		],
		"hands": [
			{
				"label": "Right",
				"score": 0.93,
				"landmarks": [{"id": 0, "x": 0.75, "y": 0.50, "z": 0.0}],
				"bbox": {"x": 0.71, "y": 0.42, "width": 0.08, "height": 0.16}
			}
		],
		"vendor_hand_tracking": {
			"available": true,
			"landmark_mode": "lite",
			"inference_backend": "mediapipe_tasks_hand_landmarker"
		}
	}, config, lost)
	assert_eq(one_candidate_reacquired.get("hands", {}).get("right", {}).get("association", {}).get("method"), "prefer_existing_pose_side_binding")
	assert_eq(one_candidate_reacquired.get("hands", {}).get("right", {}).get("association", {}).get("source_label"), "right")
	assert_eq(one_candidate_reacquired.get("hands", {}).get("right", {}).get("tracking_state"), "tracked")
	assert_eq(one_candidate_reacquired.get("hands", {}).get("left", {}).get("association", {}).get("assigned"), false)
	assert_eq(one_candidate_reacquired.get("hands", {}).get("left", {}).get("landmarks", []).size(), 0)
	assert_eq(one_candidate_reacquired.get("hands", {}).get("left", {}).get("bbox", {}).get("area"), 0.0)

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

func test_create_preview_presenter_binds_session_and_attaches_internal_surface() -> void:
	var tracker := CameraTracking.new()
	var parent := Control.new()
	parent.name = "PresenterParent"
	get_tree().root.add_child(parent)

	var presenter := tracker.mount_preview_presenter(parent)
	await get_tree().process_frame

	assert_true(presenter != null)
	assert_eq(presenter.get_tracking_session(), tracker)
	assert_true(tracker.get_preview_descriptor().get("attached"))
	assert_eq(tracker.get_preview_descriptor().get("surface_path"), presenter.get_preview_surface().get_path())
	assert_eq(int(tracker.get_preview_descriptor().get("attached_surface_count", -1)), 1)

	parent.queue_free()
	await get_tree().process_frame
	tracker.free()

func test_preview_presenter_loads_preview_image_and_maps_landmarks_in_preview_space() -> void:
	var tracker := CameraTracking.new()
	var backend := CameraTrackingFakeBackend.new()
	var parent := Control.new()
	parent.name = "PresenterParent"
	parent.size = Vector2(200, 200)
	get_tree().root.add_child(parent)

	var presenter := tracker.mount_preview_presenter(parent, {"fit_mode": "contain"})
	tracker.set_backend(backend, "fake")
	tracker.start({
		"backend": "fake",
		"preview": {"flip_horizontal": true}
	})

	var preview_path := _write_preview_image("preview_presenter.png", 400, 200, Color(0.8, 0.2, 0.1, 1.0))
	backend.emit_preview_descriptor({
		"backend": "fake",
		"enabled": true,
		"flip_horizontal": true,
		"image_path": preview_path,
		"image_revision": 1,
		"image_width": 400,
		"image_height": 200,
		"width": 400,
		"height": 200
	})
	backend.emit_tracking_frame({
		"timestamp_ms": 101,
		"backend": "fake",
		"source_kind": "live_camera",
		"source_id": "/dev/video0",
		"tracking_state": "tracked",
		"frame_size": {"x": 400, "y": 200},
		"landmarks": [
			{"id": 0, "x": 0.25, "y": 0.25, "z": 0.0, "visibility": 0.95}
		]
	})
	await get_tree().process_frame

	assert_true(presenter.get_preview_surface().texture != null)
	assert_true(presenter.get_preview_surface().flip_h)
	assert_eq(presenter.get_content_rect(), Rect2(Vector2(0, 50), Vector2(200, 100)))
	var mapped := presenter.map_landmark_to_preview_position(presenter.get_tracking_frame_snapshot().get("landmarks", [])[0])
	assert_eq(mapped, Vector2(150, 75))

	tracker.stop()
	parent.queue_free()
	await get_tree().process_frame
	tracker.free()

func test_preview_presenter_cover_content_rect_handles_crop_without_extra_flip() -> void:
	var tracker := CameraTracking.new()
	var backend := CameraTrackingFakeBackend.new()
	var parent := Control.new()
	parent.name = "PresenterParent"
	parent.size = Vector2(200, 200)
	get_tree().root.add_child(parent)

	var presenter := tracker.mount_preview_presenter(parent, {"fit_mode": "cover"})
	tracker.set_backend(backend, "fake")
	tracker.start({
		"backend": "fake",
		"preview": {"flip_horizontal": false}
	})
	backend.emit_preview_descriptor({
		"backend": "fake",
		"enabled": true,
		"flip_horizontal": false,
		"image_width": 400,
		"image_height": 200,
		"width": 400,
		"height": 200
	})
	backend.emit_tracking_frame({
		"timestamp_ms": 202,
		"backend": "fake",
		"source_kind": "live_camera",
		"source_id": "/dev/video0",
		"tracking_state": "tracked",
		"frame_size": {"x": 400, "y": 200},
		"landmarks": [
			{"id": 0, "x": 0.25, "y": 0.5, "z": 0.0, "visibility": 0.95}
		]
	})
	await get_tree().process_frame

	assert_eq(presenter.get_content_rect(), Rect2(Vector2(-100, 0), Vector2(400, 200)))
	var mapped := presenter.map_landmark_to_preview_position(presenter.get_tracking_frame_snapshot().get("landmarks", [])[0])
	assert_eq(mapped, Vector2(0, 100))

	tracker.stop()
	parent.queue_free()
	await get_tree().process_frame
	tracker.free()

func test_preview_presenter_exposes_hand_debug_snapshot_and_bbox_preview_rects() -> void:
	var tracker := CameraTracking.new()
	var backend := CameraTrackingFakeBackend.new()
	var parent := Control.new()
	parent.name = "PresenterParent"
	parent.size = Vector2(200, 200)
	get_tree().root.add_child(parent)

	var presenter := tracker.mount_preview_presenter(parent, {"fit_mode": "contain"})
	tracker.set_backend(backend, "fake")
	tracker.start({
		"backend": "fake",
		"preview": {"flip_horizontal": false},
		"tracking": {
			"hands": {
				"enabled": true,
				"landmark_mode": "full"
			}
		}
	})
	backend.emit_preview_descriptor({
		"backend": "fake",
		"enabled": true,
		"flip_horizontal": false,
		"image_width": 400,
		"image_height": 200,
		"width": 400,
		"height": 200
	})
	backend.emit_tracking_frame({
		"timestamp_ms": 303,
		"backend": "fake",
		"source_kind": "live_camera",
		"source_id": "/dev/video0",
		"tracking_state": "tracked",
		"frame_size": {"x": 400, "y": 200},
		"vendor_hand_tracking": {
			"available": true,
			"landmark_mode": "full"
		},
		"landmarks": [
			{"id": 15, "x": 0.2, "y": 0.5, "z": 0.0, "visibility": 0.95},
			{"id": 16, "x": 0.8, "y": 0.5, "z": 0.0, "visibility": 0.95}
		],
		"hands": [
			{
				"label": "Left",
				"score": 0.91,
				"landmarks": [
					{"id": 0, "x": 0.2, "y": 0.4, "z": 0.0, "visibility": 0.9},
					{"id": 8, "x": 0.25, "y": 0.45, "z": 0.0, "visibility": 0.8}
				],
				"bbox": {"x": 0.2, "y": 0.4, "width": 0.1, "height": 0.2, "area": 0.02}
			}
		]
	})
	await get_tree().process_frame

	var snapshot := presenter.get_hand_debug_snapshot()
	assert_eq(snapshot.get("frame_index"), 1)
	assert_eq(snapshot.get("source_kind"), "live_camera")
	assert_eq(snapshot.get("hand_tracking", {}).get("landmark_mode"), "full")
	assert_false(snapshot.get("hands", {}).get("left", {}).get("tracking_valid"))
	assert_eq(snapshot.get("hands", {}).get("left", {}).get("tracking_state"), "reacquiring")
	assert_eq(snapshot.get("hands", {}).get("left", {}).get("landmark_mode"), "full")
	assert_eq(int(snapshot.get("hands", {}).get("left", {}).get("grace_frames", -1)), 0)
	assert_false(bool(snapshot.get("hands", {}).get("left", {}).get("predicted", true)))
	assert_eq(snapshot.get("hands", {}).get("left", {}).get("bbox_preview_rect"), {
		"x": 40.0,
		"y": 90.0,
		"width": 20.0,
		"height": 20.0,
	})
	assert_eq(presenter.map_bbox_to_preview_rect({"x": 0.2, "y": 0.4, "width": 0.1, "height": 0.2}), Rect2(Vector2(40, 90), Vector2(20, 20)))
	assert_eq(snapshot.get("hands", {}).get("right", {}).get("tracking_state"), "idle")

	tracker.stop()
	parent.queue_free()
	await get_tree().process_frame
	tracker.free()

func test_preview_presenter_exposes_playback_status_alongside_hand_debug_snapshot() -> void:
	var tracker := CameraTracking.new()
	var backend := PlaybackStatusFakeBackend.new()
	var parent := Control.new()
	parent.name = "PresenterParent"
	parent.size = Vector2(200, 200)
	get_tree().root.add_child(parent)

	var presenter := tracker.mount_preview_presenter(parent, {"fit_mode": "contain"})
	tracker.set_backend(backend, "fake")
	tracker.start({
		"backend": "fake",
		"source": {"kind": "video_file", "path": "res://clips/demo.mp4"},
		"preview": {"flip_horizontal": false},
		"tracking": {
			"hands": {
				"enabled": true
			}
		}
	})
	backend.emit_preview_descriptor({
		"backend": "fake",
		"enabled": true,
		"flip_horizontal": false,
		"image_width": 400,
		"image_height": 200,
		"width": 400,
		"height": 200
	})
	backend.emit_tracking_frame({
		"timestamp_ms": 404,
		"backend": "fake",
		"source_kind": "video_file",
		"source_id": "res://clips/demo.mp4",
		"tracking_state": "tracked",
		"frame_size": {"x": 400, "y": 200},
		"vendor_hand_tracking": {
			"available": false
		},
		"hands": []
	})
	await get_tree().process_frame

	assert_eq(presenter.get_playback_status_snapshot().get("current_time_sec"), 3.0)
	assert_eq(presenter.get_hand_debug_snapshot().get("playback", {}).get("progress"), 0.25)
	assert_eq(String(presenter.get_replay_transport_status_snapshot().get("transport_mode", "")), CameraTracking.TRANSPORT_MODE_APPROX_TIME_SEEK)
	assert_eq(String(presenter.get_hand_debug_snapshot().get("replay_transport", {}).get("limitation_code", "")), CameraTracking.REPLAY_TRANSPORT_UNSUPPORTED_CODE)
	assert_eq(presenter.get_hand_debug_snapshot().get("hands", {}).get("left", {}).get("tracking_state"), "unavailable")

	backend.advance_playback(9.0, 12.0)
	await get_tree().process_frame
	assert_eq(presenter.get_playback_status_snapshot().get("progress"), 0.75)

	tracker.stop()
	parent.queue_free()
	await get_tree().process_frame
	tracker.free()

func test_preview_presenter_snapshot_reads_do_not_force_runtime_refresh() -> void:
	var tracker := CameraTracking.new()
	var backend := PlaybackStatusFakeBackend.new()
	var parent := Control.new()
	parent.name = "PresenterParent"
	parent.size = Vector2(200, 200)
	get_tree().root.add_child(parent)

	var presenter := tracker.mount_preview_presenter(parent, {"fit_mode": "contain"})
	tracker.set_backend(backend, "fake")
	tracker.start({
		"backend": "fake",
		"source": {"kind": "video_file", "path": "res://clips/demo.mp4"},
		"preview": {"flip_horizontal": false},
		"tracking": {
			"hands": {
				"enabled": true
			}
		}
	})
	backend.emit_tracking_frame({
		"timestamp_ms": 404,
		"backend": "fake",
		"source_kind": "video_file",
		"source_id": "res://clips/demo.mp4",
		"tracking_state": "tracked",
		"frame_size": {"x": 400, "y": 200},
		"vendor_hand_tracking": {
			"available": false
		},
		"hands": []
	})
	await get_tree().process_frame
	backend.reset_runtime_snapshot_call_counts()

	var playback_snapshot := presenter.get_playback_status_snapshot()
	var transport_snapshot := presenter.get_replay_transport_status_snapshot()
	var hand_snapshot := presenter.get_hand_debug_snapshot()

	assert_eq(playback_snapshot.get("current_time_sec"), 3.0)
	assert_eq(String(transport_snapshot.get("transport_mode", "")), CameraTracking.TRANSPORT_MODE_APPROX_TIME_SEEK)
	assert_eq(hand_snapshot.get("playback", {}).get("progress"), 0.25)
	assert_eq(backend.get_tracking_frame_calls, 0, "Presenter snapshot reads should stay on cached session snapshots and must not poll the backend for a fresh tracking frame.")
	assert_eq(backend.get_playback_status_calls, 0, "Presenter snapshot reads should avoid runtime-refresh playback reads during debug repaint paths.")
	assert_eq(backend.get_replay_transport_capabilities_calls, 0, "Presenter snapshot reads should not force replay transport capability refreshes.")
	assert_eq(backend.get_replay_transport_status_calls, 0, "Presenter snapshot reads should not force replay transport status refreshes.")

	tracker.stop()
	parent.queue_free()
	await get_tree().process_frame
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
	tracker._continuous_backend_refresh_interval_ms = 0

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
	tracker._continuous_backend_refresh_interval_ms = 100
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

func test_camera_tracking_rate_limits_continuous_process_polling_but_forces_explicit_refreshes() -> void:
	var tracker := CameraTracking.new()
	var backend := CountingPollingBackend.new()
	get_tree().root.add_child(tracker)
	tracker.set_backend(backend)
	tracker._continuous_backend_refresh_interval_ms = 100
	tracker.start({
		"backend": "polling_fake",
		"source": {"kind": "live_camera", "camera_id": "/dev/video0"},
		"preview": {"enabled": true, "flip_horizontal": true}
	})
	backend.reset_counts()

	tracker._process(0.0)
	tracker._process(0.0)
	assert_eq(backend.get_tracking_frame_calls, 1)

	tracker.get_playback_status()
	assert_eq(backend.get_tracking_frame_calls, 2)

	tracker.get_replay_transport_capabilities()
	tracker.get_replay_transport_status()
	assert_eq(backend.get_tracking_frame_calls, 4)

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
	var tracking_events: Array = []
	tracker.tracking_updated.connect(func(frame: Dictionary): tracking_events.append(frame.duplicate(true)))
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
	var tracking_events_before_replay_change := tracking_events.size()
	tracker.change(_make_replay_config(replay_path, {
		"preview": {"flip_horizontal": false}
	}))
	assert_true(tracking_events.size() > tracking_events_before_replay_change)
	var first_replay_event: Dictionary = tracking_events[tracking_events_before_replay_change]
	assert_eq(first_replay_event.get("source_kind"), "video_file")
	assert_eq(first_replay_event.get("source_id"), replay_path)
	assert_true(["tracked", "idle"].has(first_replay_event.get("tracking_state")))
	assert_eq(int(first_replay_event.get("frame_size", {}).get("x", 0)), 960)
	assert_eq(int(first_replay_event.get("frame_size", {}).get("y", 0)), 540)
	assert_true(int(first_replay_event.get("timestamp_ms", 0)) > 0)
	assert_eq(tracker.get_state().get("state"), CameraTracking.STATE_RUNNING)
	assert_true(tracker.get_state().get("detail", {}).get("backend_ready"))
	assert_true(tracker.get_state().get("detail", {}).get("preview_ready"))
	assert_true(tracker.get_state().get("detail", {}).get("tracking_ready"))
	assert_true(tracker.get_state().get("detail", {}).get("source_ready"))
	assert_eq(tracker.get_active_config().get("source", {}).get("kind"), "video_file")
	assert_eq(tracker.get_active_config().get("source", {}).get("path"), replay_path)
	assert_eq(tracker.get_tracking_frame().get("source_kind"), "video_file")
	assert_eq(tracker.get_tracking_frame().get("source_id"), replay_path)
	assert_true(["tracked", "idle"].has(tracker.get_tracking_frame().get("tracking_state")))
	assert_eq(int(tracker.get_tracking_frame().get("frame_size", {}).get("x", 0)), 960)
	assert_eq(int(tracker.get_tracking_frame().get("frame_size", {}).get("y", 0)), 540)
	assert_true(int(tracker.get_tracking_frame().get("timestamp_ms", 0)) > 0)
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

func _write_preview_image(name: String, width: int, height: int, color: Color) -> String:
	var path := _fixture_root.path_join(name)
	var image := Image.create(maxi(width, 1), maxi(height, 1), false, Image.FORMAT_RGBA8)
	image.fill(color)
	var error := image.save_png(path)
	assert_eq(error, OK)
	return path

func _deep_merge(base: Dictionary, incoming: Dictionary) -> void:
	for key in incoming.keys():
		var incoming_value: Variant = incoming[key]
		if base.has(key) and base[key] is Dictionary and incoming_value is Dictionary:
			_deep_merge(base[key], incoming_value)
		else:
			base[key] = incoming_value
