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
			"source_info": "source/source_info.json",
			"timing_truth": "truth/timing_truth.yaml"
		},
		"tracking_contract": {
			"backend_id": "mediapipe_python",
			"normalized_schema_version": PoseFrameRecord.SCHEMA_VERSION,
			"frame_count": 3,
			"timestamp_mode": "video_time_ms"
		},
		"source_contract": {
			"source_path": "fixtures/boxing/demo.mp4",
			"fixture_id": "demo_fixture"
		},
		"truth_contract": {
			"timing_truth_path": "truth/timing_truth.yaml",
			"timing_truth_source_path": "fixtures/boxing/demo.yaml",
			"label_context": "boxing_side_aware_punches_v1"
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
	], "events:\n  - label: straight_left\n    start_ms: 0\n    end_ms: 66\n", {
		"source_info": JSON.stringify({"source_kind": "fixture_replay", "timing_truth_linked": true}) + "\n"
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
	var playback_status := tracker.get_playback_status()
	assert_eq(str(playback_status.get("replay_input_kind", "")), "session_manifest")
	assert_eq(str(playback_status.get("replay_mode", "")), "saved_tracking_frames")
	assert_eq(str(playback_status.get("source_kind", "")), "fixture_replay")
	assert_eq(str(playback_status.get("source_id", "")), "fixtures/boxing/demo.mp4")
	assert_true(bool(playback_status.get("truth_linked", false)), "Fixture replay playback status should surface linked timing truth metadata")
	assert_eq(str((playback_status.get("truth_contract", {}) as Dictionary).get("timing_truth_path", "")), "truth/timing_truth.yaml")
	assert_eq(str((playback_status.get("truth_contract", {}) as Dictionary).get("timing_truth_source_path", "")), "fixtures/boxing/demo.yaml")
	assert_eq(str((playback_status.get("truth_contract", {}) as Dictionary).get("label_context", "")), "boxing_side_aware_punches_v1")
	assert_eq(str((playback_status.get("source_contract", {}) as Dictionary).get("fixture_id", "")), "demo_fixture")
	assert_eq(str(tracker.get_replay_transport_capabilities().get("transport_mode", "")), CameraTracking.TRANSPORT_MODE_EXACT_OWNED_FRAME_INDEX)
	assert_true(bool(tracker.get_replay_transport_status().get("truth_linked", false)))
	tracker.queue_free()

func test_session_manifest_source_dispatches_video_reinference_through_mediapipe_video_path() -> void:
	var session_root := ProjectSettings.globalize_path(GENERATED_SESSION_ROOT)
	assert_eq(DirAccess.make_dir_recursive_absolute(session_root.path_join("source")), OK)
	var source_video_path := session_root.path_join("source/source_video.mp4")
	var source_video_file := FileAccess.open(source_video_path, FileAccess.WRITE)
	assert_true(source_video_file != null, "Expected source video artifact to open for fixture write")
	source_video_file.store_buffer(PackedByteArray([0x66, 0x61, 0x6b, 0x65]))
	source_video_file.close()
	var created := CameraRecordingManager.create_saved_session_package(session_root, {
		"schema_version": 1,
		"session_id": "saved_session_video_reinference",
		"take_id": "take_01",
		"created_at": "2026-06-12T23:15:00Z",
		"source_kind": "video_file",
		"artifacts": {
			"pose_frames": "tracking/pose_frames.jsonl",
			"source_video": "source/source_video.mp4",
			"timing_truth": "truth/timing_truth.yaml"
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
		"truth_contract": {
			"timing_truth_path": "truth/timing_truth.yaml",
			"label_context": "boxing_side_aware_punches_v1"
		},
		"replay_contract": {
			"replay_mode": "video_reinference",
			"entrypoint": "source/source_video.mp4"
		}
	}, [
		PoseFrameRecord.normalize({"frame_index": 0, "timestamp_ms": 0, "timestamp_seconds": 0.0, "tracking_state": "tracked", "landmarks": [{"id": "0", "x": 0.1, "y": 0.2, "z": 0.0, "v": 0.9}]}),
		PoseFrameRecord.normalize({"frame_index": 1, "timestamp_ms": 50, "timestamp_seconds": 0.05, "tracking_state": "tracked", "landmarks": [{"id": "0", "x": 0.5, "y": 0.2, "z": 0.0, "v": 0.9}]}),
		PoseFrameRecord.normalize({"frame_index": 2, "timestamp_ms": 100, "timestamp_seconds": 0.1, "tracking_state": "tracked", "landmarks": [{"id": "0", "x": 0.9, "y": 0.2, "z": 0.0, "v": 0.9}]})
	], "events:\n  - label: straight_left\n    start_ms: 0\n    end_ms: 100\n")
	assert_true(created.get("ok", false))

	var tracker := CameraTracking.new()
	get_tree().root.add_child(tracker)
	tracker.start({
		"source": {"kind": "session_manifest", "path": session_root.path_join("session_manifest.json")},
		"preview": {"replay": {"enabled": false}},
		"runtime": {
			"environment": {
				"AEROBEAT_CAMERA_SAMPLE_FIXTURES_JSON": JSON.stringify({
					source_video_path: {
						"sequence": [
							{
								"width": 960,
								"height": 540,
								"timestamp_ms": 111,
								"landmarks": [
									{"id": 15, "x": 0.21, "y": 0.31, "z": -0.1, "visibility": 0.95}
								]
							},
							{
								"width": 960,
								"height": 540,
								"timestamp_ms": 222,
								"landmarks": [
									{"id": 15, "x": 0.44, "y": 0.34, "z": -0.08, "visibility": 0.95}
								]
							}
						]
					}
				}),
				"AEROBEAT_CAMERA_REPLAY_FRAME_DELAY_MS": "10"
			}
		}
	})

	assert_eq(tracker.get_state().get("state"), CameraTracking.STATE_RUNNING)
	var frame := tracker.get_tracking_frame()
	assert_eq(str(frame.get("backend", "")), "mediapipe_python")
	var playback_status := tracker.get_playback_status()
	assert_eq(str(playback_status.get("source", "")), session_root.path_join("session_manifest.json"))
	assert_eq(str(playback_status.get("replay_input_kind", "")), "session_manifest")
	assert_eq(str(playback_status.get("replay_mode", "")), "video_reinference")
	assert_eq(str(playback_status.get("entrypoint", "")), source_video_path)
	assert_eq(str(playback_status.get("source_video_path", "")), source_video_path)
	assert_eq(str(playback_status.get("delegate_backend", "")), "mediapipe_python")
	assert_eq(str(tracker.get_replay_transport_capabilities().get("transport_mode", "")), CameraTracking.TRANSPORT_MODE_APPROX_TIME_SEEK)
	assert_false(bool(tracker.get_replay_transport_capabilities().get("can_seek_frame", true)))
	assert_true(bool(playback_status.get("truth_linked", false)))
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
