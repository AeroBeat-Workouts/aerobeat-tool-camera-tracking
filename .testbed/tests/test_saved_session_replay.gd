extends GutTest

const CameraTracking = preload("res://addons/aerobeat-tool-camera-tracking/src/CameraTracking.gd")
const CameraTrackingBackend = preload("res://addons/aerobeat-tool-camera-tracking/src/CameraTrackingBackend.gd")
const CameraRecordingManager = preload("res://addons/aerobeat-tool-camera-recording/src/CameraRecordingManager.gd")
const PoseFrameRecord = preload("res://addons/aerobeat-tool-camera-recording/src/pose/PoseFrameRecord.gd")

const GENERATED_SESSION_ROOT := "user://saved_session_replay_fixture"

func before_each() -> void:
	CameraTracking.clear_backend_factories()
	_delete_recursive(ProjectSettings.globalize_path(GENERATED_SESSION_ROOT))

func after_each() -> void:
	CameraTracking.clear_backend_factories()
	_delete_recursive(ProjectSettings.globalize_path(GENERATED_SESSION_ROOT))

func test_session_manifest_source_replays_saved_tracking_frames_without_vendor_backend() -> void:
	var session_root := ProjectSettings.globalize_path(GENERATED_SESSION_ROOT)
	var created := CameraRecordingManager.create_saved_session_package(session_root, {
		"schema_version": 1,
		"session_id": "saved_session_replay_fixture",
		"take_id": "take_01",
		"created_at": "2026-06-12T21:45:00Z",
		"source_kind": "fixture_replay",
		"artifacts": {
			"pose_frames": "tracking/pose_frames.jsonl",
			"source_info": "source/source_info.json"
		},
		"tracking_contract": {
			"backend_id": "mediapipe_python",
			"normalized_schema_version": PoseFrameRecord.SCHEMA_VERSION,
			"frame_count": 3,
			"timestamp_mode": "video_time_ms"
		},
		"source_contract": {
			"source_path": "fixtures/boxing/demo.mp4"
		},
		"replay_contract": {
			"replay_mode": "saved_tracking_frames",
			"entrypoint": "tracking/pose_frames.jsonl"
		}
	}, [
		PoseFrameRecord.normalize({
			"frame_index": 0,
			"timestamp_ms": 0,
			"timestamp_seconds": 0.0,
			"tracking_state": "tracked",
			"frame_size": {"width": 960, "height": 540},
			"landmarks": [{"id": "15", "x": 0.2, "y": 0.3, "z": -0.1, "v": 0.9}]
		}),
		PoseFrameRecord.normalize({
			"frame_index": 1,
			"timestamp_ms": 33,
			"timestamp_seconds": 0.033,
			"tracking_state": "tracked",
			"frame_size": {"width": 960, "height": 540},
			"landmarks": [{"id": "15", "x": 0.4, "y": 0.35, "z": -0.1, "v": 0.9}]
		}),
		PoseFrameRecord.normalize({
			"frame_index": 2,
			"timestamp_ms": 66,
			"timestamp_seconds": 0.066,
			"tracking_state": "tracked",
			"frame_size": {"width": 960, "height": 540},
			"landmarks": [{"id": "15", "x": 0.6, "y": 0.4, "z": -0.1, "v": 0.9}]
		})
	], "", {
		"source_info": JSON.stringify({"source_kind": "fixture_replay"}) + "\n"
	})
	assert_true(created.get("ok", false), "Fixture saved-session package should be created before replay tests")

	var tracker := CameraTracking.new()
	get_tree().root.add_child(tracker)
	tracker.start({
		"source": {"kind": "session_manifest", "path": session_root.path_join("session_manifest.json")},
		"preview": {"replay": {"enabled": false}}
	})

	assert_eq(tracker.get_state().get("state"), CameraTracking.STATE_RUNNING)
	assert_eq(tracker.get_tracking_frame().get("backend"), "saved_session_replay")
	assert_eq(tracker.get_tracking_frame().get("source_kind"), "fixture_replay")
	assert_eq(tracker.get_tracking_frame().get("source_id"), "fixtures/boxing/demo.mp4")
	assert_eq(int((tracker.get_tracking_frame().get("landmarks", []) as Array)[0].get("id", -1)), 15)
	assert_eq(str(tracker.get_playback_status().get("replay_input_kind", "")), "session_manifest")
	assert_eq(str(tracker.get_playback_status().get("replay_mode", "")), "saved_tracking_frames")
	assert_eq(str(tracker.get_replay_transport_capabilities().get("transport_mode", "")), CameraTracking.TRANSPORT_MODE_EXACT_OWNED_FRAME_INDEX)
	tracker.queue_free()

func test_saved_session_replay_supports_play_pause_step_and_seek_deterministically() -> void:
	var session_root := ProjectSettings.globalize_path(GENERATED_SESSION_ROOT)
	var created := CameraRecordingManager.create_saved_session_package(session_root, {
		"schema_version": 1,
		"session_id": "saved_session_controls",
		"take_id": "take_01",
		"created_at": "2026-06-12T21:45:00Z",
		"source_kind": "video_file",
		"artifacts": {
			"pose_frames": "tracking/pose_frames.jsonl"
		},
		"tracking_contract": {
			"backend_id": "mediapipe_python",
			"normalized_schema_version": PoseFrameRecord.SCHEMA_VERSION,
			"frame_count": 3,
			"timestamp_mode": "video_time_ms"
		},
		"source_contract": {
			"source_path": "fixtures/boxing/demo.mp4"
		},
		"replay_contract": {
			"replay_mode": "saved_tracking_frames",
			"entrypoint": "tracking/pose_frames.jsonl"
		}
	}, [
		PoseFrameRecord.normalize({"frame_index": 0, "timestamp_ms": 0, "timestamp_seconds": 0.0, "tracking_state": "tracked", "landmarks": [{"id": "0", "x": 0.1, "y": 0.2, "z": 0.0, "v": 0.9}]}),
		PoseFrameRecord.normalize({"frame_index": 1, "timestamp_ms": 50, "timestamp_seconds": 0.05, "tracking_state": "tracked", "landmarks": [{"id": "0", "x": 0.5, "y": 0.2, "z": 0.0, "v": 0.9}]}),
		PoseFrameRecord.normalize({"frame_index": 2, "timestamp_ms": 100, "timestamp_seconds": 0.1, "tracking_state": "tracked", "landmarks": [{"id": "0", "x": 0.9, "y": 0.2, "z": 0.0, "v": 0.9}]})
	])
	assert_true(created.get("ok", false))

	var tracker := CameraTracking.new()
	get_tree().root.add_child(tracker)
	tracker.start({
		"source": {"kind": "session_manifest", "path": session_root.path_join("session_manifest.json")},
		"preview": {"replay": {"enabled": false}}
	})

	var pause_result := tracker.pause_replay()
	assert_true(bool(pause_result.get(CameraTrackingBackend.RESULT_SUCCESS, false)))
	assert_true(bool(tracker.get_playback_status().get("paused", false)))
	assert_eq(int(tracker.get_replay_transport_status().get("frame_index", -1)), 0)

	var seek_result := tracker.seek_replay_to_frame(1)
	assert_true(bool(seek_result.get(CameraTrackingBackend.RESULT_SUCCESS, false)))
	assert_eq(int(tracker.get_tracking_frame().get("frame_index", -1)), 1)
	assert_true(is_equal_approx(float((tracker.get_tracking_frame().get("landmarks", []) as Array)[0].get("x", 0.0)), 0.5))

	var step_result := tracker.step_replay_frames(1)
	assert_true(bool(step_result.get(CameraTrackingBackend.RESULT_SUCCESS, false)))
	assert_eq(int(tracker.get_tracking_frame().get("frame_index", -1)), 2)
	assert_true(is_equal_approx(float((tracker.get_tracking_frame().get("landmarks", []) as Array)[0].get("x", 0.0)), 0.9))

	var back_result := tracker.step_replay_frames(-2)
	assert_true(bool(back_result.get(CameraTrackingBackend.RESULT_SUCCESS, false)))
	assert_eq(int(tracker.get_tracking_frame().get("frame_index", -1)), 0)
	assert_true(is_equal_approx(float((tracker.get_tracking_frame().get("landmarks", []) as Array)[0].get("x", 0.0)), 0.1))

	var play_result := tracker.play_replay()
	assert_true(bool(play_result.get(CameraTrackingBackend.RESULT_SUCCESS, false)))
	assert_false(bool(tracker.get_playback_status().get("paused", true)))
	OS.delay_msec(130)
	tracker._process(0.13)
	var frame_after_play := tracker.get_tracking_frame()
	assert_eq(int(frame_after_play.get("frame_index", -1)), 2)

	var paused_again := tracker.pause_replay()
	assert_true(bool(paused_again.get(CameraTrackingBackend.RESULT_SUCCESS, false)))
	assert_true(bool(tracker.get_playback_status().get("paused", false)))
	assert_eq(int(tracker.get_replay_transport_status().get("frame_index", -1)), 2)
	tracker.queue_free()

func _delete_recursive(path: String) -> void:
	if path == "" or not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break
		if entry == "." or entry == "..":
			continue
		var child_path := "%s/%s" % [path, entry]
		if dir.current_is_dir():
			_delete_recursive(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
