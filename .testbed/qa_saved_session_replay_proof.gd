extends SceneTree

const CameraTracking = preload("res://addons/aerobeat-tool-camera-tracking/src/CameraTracking.gd")
const CameraTrackingBackend = preload("res://addons/aerobeat-tool-camera-tracking/src/CameraTrackingBackend.gd")
const CameraRecordingManager = preload("res://addons/aerobeat-tool-camera-recording/src/CameraRecordingManager.gd")

const EXPORT_ROOT := "user://qa_saved_session_replay_export"

class ExportFakeBackend extends CameraTrackingBackend:
	var _tracking_frame: Dictionary = {}
	var _state := CameraTracking.STATE_IDLE

	func get_backend_id() -> String:
		return "export_fake"

	func start(config: Dictionary) -> void:
		_tracking_frame = {
			"timestamp_ms": 1000,
			"timestamp_seconds": 1.0,
			"frame_index": 0,
			"backend": "export_fake",
			"source_kind": str(config.get("source", {}).get("kind", "video_file")),
			"source_id": str(config.get("source", {}).get("path", "fixtures/boxing/demo.mp4")),
			"tracking_state": "tracked",
			"frame_size": {"x": 640, "y": 480},
			"landmarks": [
				{"id": 15, "x": 0.2, "y": 0.3, "z": -0.1, "v": 0.9}
			]
		}
		_state = CameraTracking.STATE_RUNNING
		emit_signal("tracking_updated", _tracking_frame.duplicate(true))
		emit_signal("state_changed", _state, CameraTrackingConfig.make_state_detail({
			"backend_ready": true,
			"preview_ready": true,
			"tracking_ready": true,
			"source_ready": true,
		}))

	func stop() -> void:
		_state = CameraTracking.STATE_IDLE
		emit_signal("state_changed", _state, CameraTrackingConfig.make_state_detail())

	func change(config: Dictionary) -> void:
		start(config)

	func get_state() -> Dictionary:
		return {"state": _state, "detail": CameraTrackingConfig.make_state_detail({
			"backend_ready": _state == CameraTracking.STATE_RUNNING,
			"preview_ready": _state == CameraTracking.STATE_RUNNING,
			"tracking_ready": _state == CameraTracking.STATE_RUNNING,
			"source_ready": _state == CameraTracking.STATE_RUNNING,
		})}

	func get_tracking_frame() -> Dictionary:
		return _tracking_frame.duplicate(true)

	func emit_frame(frame_index: int, timestamp_ms: int, x: float) -> void:
		_tracking_frame = {
			"timestamp_ms": timestamp_ms,
			"timestamp_seconds": float(timestamp_ms) / 1000.0,
			"frame_index": frame_index,
			"backend": "export_fake",
			"source_kind": str(_tracking_frame.get("source_kind", "video_file")),
			"source_id": str(_tracking_frame.get("source_id", "fixtures/boxing/demo.mp4")),
			"tracking_state": "tracked",
			"frame_size": {"x": 640, "y": 480},
			"landmarks": [
				{"id": 15, "x": x, "y": 0.3 + 0.02 * frame_index, "z": -0.1, "v": 0.9}
			]
		}
		emit_signal("tracking_updated", _tracking_frame.duplicate(true))

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

func _read_jsonl(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	_assert(file != null, "Failed to open JSONL file: %s" % path)
	var lines: Array = []
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "":
			continue
		var parsed := JSON.new()
		_assert(parsed.parse(line) == OK, "Failed to parse JSONL line in %s" % path)
		lines.append(parsed.data)
	return lines

func _frame_brief(frame: Dictionary) -> Dictionary:
	var landmarks: Array = frame.get("landmarks", []) if frame.get("landmarks", []) is Array else []
	var first: Dictionary = landmarks[0] if not landmarks.is_empty() and landmarks[0] is Dictionary else {}
	return {
		"frame_index": int(frame.get("frame_index", -1)),
		"timestamp_ms": int(frame.get("timestamp_ms", -1)),
		"landmark_id": int(first.get("id", -1)),
		"landmark_x": float(first.get("x", -1.0)),
		"backend": str(frame.get("backend", "")),
		"source_kind": str(frame.get("source_kind", "")),
		"source_id": str(frame.get("source_id", "")),
	}

func _init() -> void:
	var export_root := ProjectSettings.globalize_path(EXPORT_ROOT)
	_delete_recursive(export_root)
	CameraTracking.clear_backend_factories()

	var capture_tracker := CameraTracking.new()
	var export_backend := ExportFakeBackend.new()
	var captured_frames: Array = []
	capture_tracker.tracking_updated.connect(func(frame: Dictionary): captured_frames.append(frame.duplicate(true)))
	capture_tracker.set_backend(export_backend, "export_fake")
	capture_tracker.start({
		"backend": "export_fake",
		"source": {"kind": "video_file", "path": "fixtures/boxing/demo.mp4"},
		"preview": {"replay": {"enabled": false}}
	})
	export_backend.emit_frame(1, 1033, 0.45)
	export_backend.emit_frame(2, 1066, 0.7)
	_assert(captured_frames.size() == 3, "Expected 3 captured tracker frames before export")

	var export_result := CameraRecordingManager.export_saved_session_from_tracking_frames(export_root, capture_tracker.get_active_config(), captured_frames, {
		"session_id": "qa_saved_session",
		"take_id": "take_qa_01",
		"backend_id": "export_fake",
		"created_at": "2026-06-12T21:56:00Z"
	})
	_assert(bool(export_result.get("ok", false)), "Expected truthful saved-session export to succeed")
	capture_tracker.stop()
	capture_tracker.free()

	var manifest_path := export_root.path_join("session_manifest.json")
	var manifest := _read_json(manifest_path)
	var pose_frames_path := export_root.path_join(str((manifest.get("artifacts", {}) as Dictionary).get("pose_frames", "")))
	var saved_pose_frames := _read_jsonl(pose_frames_path)
	_assert(saved_pose_frames.size() == 3, "Expected 3 saved pose frames on disk")
	_assert(str(manifest.get("source_kind", "")) == "video_file", "Expected truthful export source_kind=video_file")
	_assert(str((manifest.get("replay_contract", {}) as Dictionary).get("replay_mode", "")) == "saved_tracking_frames", "Expected B-mode replay contract")
	_assert(str((manifest.get("replay_contract", {}) as Dictionary).get("entrypoint", "")) == str((manifest.get("artifacts", {}) as Dictionary).get("pose_frames", "")), "Expected entrypoint to match pose_frames artifact")

	CameraTracking.clear_backend_factories()
	var replay_tracker := CameraTracking.new()
	root.add_child(replay_tracker)
	replay_tracker.start({
		"source": {"kind": "session_manifest", "path": manifest_path},
		"preview": {"replay": {"enabled": false}}
	})

	_assert(replay_tracker.get_state().get("state") == CameraTracking.STATE_RUNNING, "Expected session_manifest replay tracker to start")
	var initial_frame := replay_tracker.get_tracking_frame()
	_assert(str(initial_frame.get("backend", "")) == "saved_session_replay", "Expected manifest replay backend to be saved_session_replay")
	_assert(str(replay_tracker.get_playback_status().get("replay_input_kind", "")) == "session_manifest", "Expected session_manifest replay input kind")
	_assert(str(replay_tracker.get_playback_status().get("replay_mode", "")) == "saved_tracking_frames", "Expected saved_tracking_frames replay mode")
	_assert(str(replay_tracker.get_replay_transport_capabilities().get("transport_mode", "")) == CameraTracking.TRANSPORT_MODE_EXACT_OWNED_FRAME_INDEX, "Expected exact frame-owned replay transport")

	var pause_result := replay_tracker.pause_replay()
	_assert(bool(pause_result.get(CameraTrackingBackend.RESULT_SUCCESS, false)), "pause_replay should succeed")
	var seek_result := replay_tracker.seek_replay_to_frame(1)
	_assert(bool(seek_result.get(CameraTrackingBackend.RESULT_SUCCESS, false)), "seek_replay_to_frame should succeed")
	var frame_after_seek := replay_tracker.get_tracking_frame()
	var step_result := replay_tracker.step_replay_frames(1)
	_assert(bool(step_result.get(CameraTrackingBackend.RESULT_SUCCESS, false)), "step_replay_frames(+1) should succeed")
	var frame_after_step := replay_tracker.get_tracking_frame()
	var back_result := replay_tracker.step_replay_frames(-2)
	_assert(bool(back_result.get(CameraTrackingBackend.RESULT_SUCCESS, false)), "step_replay_frames(-2) should succeed")
	var frame_after_back := replay_tracker.get_tracking_frame()
	var play_result := replay_tracker.play_replay()
	_assert(bool(play_result.get(CameraTrackingBackend.RESULT_SUCCESS, false)), "play_replay should succeed")
	OS.delay_msec(130)
	replay_tracker._process(0.13)
	var frame_after_play := replay_tracker.get_tracking_frame()
	var pause_again := replay_tracker.pause_replay()
	_assert(bool(pause_again.get(CameraTrackingBackend.RESULT_SUCCESS, false)), "pause_replay after play should succeed")

	_assert(int(initial_frame.get("frame_index", -1)) == int((saved_pose_frames[0] as Dictionary).get("frame_index", -2)), "Initial replay frame index should come from saved pose frame 0")
	_assert(is_equal_approx(float((initial_frame.get("landmarks", [])[0] as Dictionary).get("x", -1.0)), float(((saved_pose_frames[0] as Dictionary).get("landmarks", [])[0].get("x", -2.0)))), "Initial replay landmark should match saved pose frame 0")
	_assert(int(frame_after_seek.get("frame_index", -1)) == int((saved_pose_frames[1] as Dictionary).get("frame_index", -2)), "Seek target frame index should match saved pose frame 1")
	_assert(is_equal_approx(float((frame_after_seek.get("landmarks", [])[0] as Dictionary).get("x", -1.0)), float(((saved_pose_frames[1] as Dictionary).get("landmarks", [])[0].get("x", -2.0)))), "Seek target landmark should match saved pose frame 1")
	_assert(int(frame_after_step.get("frame_index", -1)) == int((saved_pose_frames[2] as Dictionary).get("frame_index", -2)), "Step target frame index should match saved pose frame 2")
	_assert(is_equal_approx(float((frame_after_step.get("landmarks", [])[0] as Dictionary).get("x", -1.0)), float(((saved_pose_frames[2] as Dictionary).get("landmarks", [])[0].get("x", -2.0)))), "Step target landmark should match saved pose frame 2")
	_assert(int(frame_after_back.get("frame_index", -1)) == int((saved_pose_frames[0] as Dictionary).get("frame_index", -2)), "Backward step should return to saved pose frame 0")
	_assert(is_equal_approx(float((frame_after_back.get("landmarks", [])[0] as Dictionary).get("x", -1.0)), float(((saved_pose_frames[0] as Dictionary).get("landmarks", [])[0].get("x", -2.0)))), "Backward step landmark should match saved pose frame 0")
	_assert(int(frame_after_play.get("frame_index", -1)) == int((saved_pose_frames[2] as Dictionary).get("frame_index", -2)), "Play should advance deterministically to saved pose frame 2 by timestamp")
	_assert(is_equal_approx(float((frame_after_play.get("landmarks", [])[0] as Dictionary).get("x", -1.0)), float(((saved_pose_frames[2] as Dictionary).get("landmarks", [])[0].get("x", -2.0)))), "Play target landmark should match saved pose frame 2")

	var report := {
		"export_root": export_root,
		"manifest_path": manifest_path,
		"manifest_source_kind": manifest.get("source_kind", ""),
		"replay_mode": (manifest.get("replay_contract", {}) as Dictionary).get("replay_mode", ""),
		"captured_tracker_frames": captured_frames.map(func(frame): return _frame_brief(frame)),
		"saved_pose_frames": saved_pose_frames.map(func(frame): return _frame_brief(frame)),
		"transport_capabilities": replay_tracker.get_replay_transport_capabilities(),
		"playback_status_after_pause": replay_tracker.get_playback_status(),
		"observed_replay_frames": {
			"initial": _frame_brief(initial_frame),
			"after_seek": _frame_brief(frame_after_seek),
			"after_step": _frame_brief(frame_after_step),
			"after_back": _frame_brief(frame_after_back),
			"after_play": _frame_brief(frame_after_play)
		},
		"vendor_inference_note": "Replay succeeded after CameraTracking.clear_backend_factories() with no vendor backend registered; active backend stayed saved_session_replay for all observed frames."
	}
	print("QA_REPLAY_PROOF=" + JSON.stringify(report))
	replay_tracker.queue_free()
	quit(0)
