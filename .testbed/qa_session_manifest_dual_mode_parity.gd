extends SceneTree

const CameraTracking = preload("res://addons/aerobeat-tool-camera-tracking/src/CameraTracking.gd")
const CameraTrackingBackend = preload("res://addons/aerobeat-tool-camera-tracking/src/CameraTrackingBackend.gd")
const CameraRecordingManager = preload("res://addons/aerobeat-tool-camera-recording/src/CameraRecordingManager.gd")
const PoseFrameRecord = preload("res://addons/aerobeat-tool-camera-recording/src/pose/PoseFrameRecord.gd")

const SESSION_ROOT := "user://qa_session_manifest_dual_mode"
const SESSION_MANIFEST_PATH := "session_manifest.json"
const SOURCE_VIDEO_RELATIVE_PATH := "source/source_video.mp4"
const TIMING_TRUTH_TEXT := "events:\n  - label: straight_left\n    start_ms: 0\n    end_ms: 66\n"

func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)

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

func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	_assert(file != null, "Failed to open JSON file: %s" % path)
	var parsed := JSON.new()
	_assert(parsed.parse(file.get_as_text()) == OK, "Failed to parse JSON file: %s" % path)
	_assert(parsed.data is Dictionary, "Expected JSON object at %s" % path)
	return parsed.data

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_assert(file != null, "Failed to open JSON file for write: %s" % path)
	file.store_string(JSON.stringify(payload, "\t") + "\n")
	file.close()

func _frame_brief(frame: Dictionary) -> Dictionary:
	var landmarks: Array = frame.get("landmarks", []) if frame.get("landmarks", []) is Array else []
	var first: Dictionary = landmarks[0] if not landmarks.is_empty() and landmarks[0] is Dictionary else {}
	return {
		"frame_index": int(frame.get("frame_index", -1)),
		"timestamp_ms": int(frame.get("timestamp_ms", -1)),
		"timestamp_seconds": float(frame.get("timestamp_seconds", -1.0)),
		"backend": str(frame.get("backend", "")),
		"delegate_backend": str(frame.get("delegate_backend", "")),
		"source_kind": str(frame.get("source_kind", "")),
		"session_source_kind": str(frame.get("session_source_kind", "")),
		"replay_mode": str(frame.get("replay_mode", "")),
		"landmark_count": landmarks.size(),
		"first_landmark_id": str(first.get("id", "")),
		"first_landmark_x": float(first.get("x", -1.0)),
		"first_landmark_y": float(first.get("y", -1.0)),
	}

func _run_tracker(config: Dictionary) -> CameraTracking:
	var tracker := CameraTracking.new()
	root.add_child(tracker)
	tracker.start(config)
	_assert(tracker.get_state().get("state") == CameraTracking.STATE_RUNNING, "Tracker failed to start for config: %s" % JSON.stringify(config))
	return tracker

func _init() -> void:
	var session_root := ProjectSettings.globalize_path(SESSION_ROOT)
	_delete_recursive(session_root)
	_assert(DirAccess.make_dir_recursive_absolute(session_root.path_join("source")) == OK, "Failed to create session source dir")
	var source_video_path := session_root.path_join(SOURCE_VIDEO_RELATIVE_PATH)
	var source_video_file := FileAccess.open(source_video_path, FileAccess.WRITE)
	_assert(source_video_file != null, "Failed to open source video artifact for write")
	source_video_file.store_buffer(PackedByteArray([0x66, 0x61, 0x6b, 0x65]))
	source_video_file.close()

	var created := CameraRecordingManager.create_saved_session_package(session_root, {
		"schema_version": 1,
		"session_id": "qa_dual_mode",
		"take_id": "take_01",
		"created_at": "2026-06-12T23:55:00Z",
		"source_kind": "video_file",
		"artifacts": {
			"pose_frames": "tracking/pose_frames.jsonl",
			"source_video": SOURCE_VIDEO_RELATIVE_PATH,
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
			"landmarks": [{"id": "15", "x": 0.2, "y": 0.3, "z": -0.1, "v": 0.95}]
		}),
		PoseFrameRecord.normalize({
			"frame_index": 1,
			"timestamp_ms": 33,
			"timestamp_seconds": 0.033,
			"tracking_state": "tracked",
			"frame_size": {"width": 960, "height": 540},
			"landmarks": [{"id": "15", "x": 0.45, "y": 0.34, "z": -0.08, "v": 0.95}]
		}),
		PoseFrameRecord.normalize({
			"frame_index": 2,
			"timestamp_ms": 66,
			"timestamp_seconds": 0.066,
			"tracking_state": "tracked",
			"frame_size": {"width": 960, "height": 540},
			"landmarks": [{"id": "15", "x": 0.68, "y": 0.36, "z": -0.05, "v": 0.95}]
		})
	], TIMING_TRUTH_TEXT)
	_assert(bool(created.get("ok", false)), "Expected saved-session package creation to succeed")

	var manifest_path := session_root.path_join(SESSION_MANIFEST_PATH)
	CameraTracking.clear_backend_factories()
	var b_tracker := _run_tracker({
		"source": {"kind": "session_manifest", "path": manifest_path},
		"preview": {"replay": {"enabled": false}}
	})
	var b_frame := b_tracker.get_tracking_frame()
	var b_playback := b_tracker.get_playback_status()
	var b_transport := b_tracker.get_replay_transport_capabilities()
	var b_pause := b_tracker.pause_replay()
	_assert(bool(b_pause.get(CameraTrackingBackend.RESULT_SUCCESS, false)), "B-mode pause should succeed")
	var b_seek := b_tracker.seek_replay_to_frame(1)
	_assert(bool(b_seek.get(CameraTrackingBackend.RESULT_SUCCESS, false)), "B-mode seek should succeed")
	var b_frame_after_seek := b_tracker.get_tracking_frame()
	b_tracker.queue_free()

	var manifest := _read_json(manifest_path)
	manifest["replay_contract"] = {
		"replay_mode": "video_reinference",
		"entrypoint": SOURCE_VIDEO_RELATIVE_PATH
	}
	_write_json(manifest_path, manifest)

	CameraTracking.clear_backend_factories()
	var a_tracker := _run_tracker({
		"source": {"kind": "session_manifest", "path": manifest_path},
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
								"landmarks": [{"id": 15, "x": 0.22, "y": 0.31, "z": -0.1, "visibility": 0.95}]
							},
							{
								"width": 960,
								"height": 540,
								"timestamp_ms": 222,
								"landmarks": [{"id": 15, "x": 0.47, "y": 0.35, "z": -0.08, "visibility": 0.95}]
							}
						]
					}
				}),
				"AEROBEAT_CAMERA_REPLAY_FRAME_DELAY_MS": "10"
			}
		}
	})
	var a_frame := a_tracker.get_tracking_frame()
	var a_playback := a_tracker.get_playback_status()
	var a_transport := a_tracker.get_replay_transport_capabilities()
	a_tracker.queue_free()

	var b_landmark_x := float(((b_frame.get("landmarks", []) as Array)[0] as Dictionary).get("x", -1.0))
	var a_landmark_x := float(((a_frame.get("landmarks", []) as Array)[0] as Dictionary).get("x", -1.0))
	var x_delta := absf(a_landmark_x - b_landmark_x)
	var checklist := {
		"same_manifest_entrypoint": manifest_path == str(a_playback.get("manifest_path", "")) and manifest_path == str(b_playback.get("manifest_path", "")),
		"b_mode_exact_saved_frames": str(b_transport.get("transport_mode", "")) == CameraTracking.TRANSPORT_MODE_EXACT_OWNED_FRAME_INDEX,
		"a_mode_vendor_video_path": str(a_frame.get("backend", "")) == "mediapipe_python" and str(a_playback.get("delegate_backend", "")) == "mediapipe_python" and str(a_playback.get("entrypoint", "")) == source_video_path,
		"truth_metadata_preserved": bool(b_playback.get("truth_linked", false)) and bool(a_playback.get("truth_linked", false)),
		"parity_landmark_id_match": str((((b_frame.get("landmarks", []) as Array)[0] as Dictionary).get("id", ""))) == str((((a_frame.get("landmarks", []) as Array)[0] as Dictionary).get("id", ""))),
		"parity_first_landmark_x_within_0_15": x_delta <= 0.15,
		"b_mode_seek_available": bool(b_seek.get(CameraTrackingBackend.RESULT_SUCCESS, false)),
		"a_mode_exact_seek_not_claimed": str(a_transport.get("transport_mode", "")) == CameraTracking.TRANSPORT_MODE_APPROX_TIME_SEEK and not bool(a_transport.get("can_seek_frame", true)),
	}
	var report := {
		"session_root": session_root,
		"manifest_path": manifest_path,
		"source_video_path": source_video_path,
		"b_mode": {
			"frame_initial": _frame_brief(b_frame),
			"frame_after_seek": _frame_brief(b_frame_after_seek),
			"playback": b_playback,
			"transport": b_transport,
		},
		"a_mode": {
			"frame_initial": _frame_brief(a_frame),
			"playback": a_playback,
			"transport": a_transport,
		},
		"comparison": {
			"first_landmark_x_delta": x_delta,
			"checklist": checklist,
		}
	}
	print("QA_SESSION_MANIFEST_DUAL_MODE_REPORT=" + JSON.stringify(report))
	quit(0)
