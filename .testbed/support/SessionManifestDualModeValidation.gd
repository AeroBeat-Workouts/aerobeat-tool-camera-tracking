extends RefCounted

const CameraTracking = preload("res://addons/aerobeat-tool-camera-tracking/src/CameraTracking.gd")
const CameraTrackingBackend = preload("res://addons/aerobeat-tool-camera-tracking/src/CameraTrackingBackend.gd")
const CameraRecordingManager = preload("res://addons/aerobeat-tool-camera-recording/src/CameraRecordingManager.gd")
const PoseFrameRecord = preload("res://addons/aerobeat-tool-camera-recording/src/pose/PoseFrameRecord.gd")
const SavedSessionValidator = preload("res://addons/aerobeat-tool-camera-recording/src/validation/SavedSessionValidator.gd")

const SESSION_MANIFEST_FILENAME := "session_manifest.json"
const SOURCE_VIDEO_RELATIVE_PATH := "source/source_video.mp4"
const REPORT_FILENAME := "dual_mode_validation_report.json"
const TIMING_TRUTH_TEXT := "events:\n  - label: straight_left\n    start_ms: 0\n    end_ms: 66\n"

static func run_validation(host: Node, options: Dictionary = {}) -> Dictionary:
	var session_root := _resolve_workspace_path(str(options.get("session_root", "user://qa_session_manifest_dual_mode")).strip_edges())
	if session_root == "":
		return _failure("session_root_missing", "Dual-mode validation requires a non-empty session_root")
	var report_path := str(options.get("report_path", "")).strip_edges()
	if report_path == "":
		report_path = session_root.path_join(REPORT_FILENAME)
	else:
		report_path = _resolve_workspace_path(report_path)

	var setup_result := _prepare_saved_session_package(session_root)
	if not bool(setup_result.get("ok", false)):
		return setup_result

	var manifest_path := session_root.path_join(SESSION_MANIFEST_FILENAME)
	var source_video_path := session_root.path_join(SOURCE_VIDEO_RELATIVE_PATH)
	var b_validation := SavedSessionValidator.validate_session_root(session_root)
	if not bool(b_validation.get("ok", false)):
		return _failure("b_mode_package_invalid", "Expected the saved-session package to validate before B-mode replay", {
			"session_root": session_root,
			"validation": b_validation,
		})

	CameraTracking.clear_backend_factories()
	var b_tracker_result := _run_tracker_capture(host, {
		"source": {"kind": "session_manifest", "path": manifest_path},
		"preview": {"replay": {"enabled": false}}
	}, true)
	if not bool(b_tracker_result.get("ok", false)):
		CameraTracking.clear_backend_factories()
		return b_tracker_result

	var rewrite_result := _rewrite_manifest_replay_contract(manifest_path, {
		"replay_mode": "video_reinference",
		"entrypoint": SOURCE_VIDEO_RELATIVE_PATH,
	})
	if not bool(rewrite_result.get("ok", false)):
		CameraTracking.clear_backend_factories()
		return rewrite_result

	var a_validation := SavedSessionValidator.validate_session_root(session_root)
	if not bool(a_validation.get("ok", false)):
		CameraTracking.clear_backend_factories()
		return _failure("a_mode_package_invalid", "Expected the same saved-session family to validate after switching replay mode to video_reinference", {
			"session_root": session_root,
			"validation": a_validation,
		})

	CameraTracking.clear_backend_factories()
	var a_tracker_result := _run_tracker_capture(host, {
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
	}, false)
	CameraTracking.clear_backend_factories()
	if not bool(a_tracker_result.get("ok", false)):
		return a_tracker_result

	var b_report: Dictionary = b_tracker_result.get("report", {})
	var a_report: Dictionary = a_tracker_result.get("report", {})
	var b_frame: Dictionary = b_report.get("frame_initial", {})
	var a_frame: Dictionary = a_report.get("frame_initial", {})
	var b_landmark_x := float(b_frame.get("first_landmark_x", -1.0))
	var a_landmark_x := float(a_frame.get("first_landmark_x", -1.0))
	var x_delta := absf(a_landmark_x - b_landmark_x)
	var checklist := {
		"recording_validator_passed_for_b_mode": bool(b_validation.get("ok", false)),
		"recording_validator_passed_for_a_mode": bool(a_validation.get("ok", false)),
		"same_manifest_entrypoint": manifest_path == str((b_report.get("playback", {}) as Dictionary).get("manifest_path", "")) and manifest_path == str((a_report.get("playback", {}) as Dictionary).get("manifest_path", "")),
		"same_saved_session_family": session_root == str((b_report.get("playback", {}) as Dictionary).get("session_root", "")) and session_root == str((a_report.get("playback", {}) as Dictionary).get("session_root", "")),
		"b_mode_exact_saved_frames": str((b_report.get("transport", {}) as Dictionary).get("transport_mode", "")) == CameraTracking.TRANSPORT_MODE_EXACT_OWNED_FRAME_INDEX,
		"b_mode_controls_proved": _b_mode_controls_passed(b_report),
		"a_mode_vendor_video_path": str(a_frame.get("backend", "")) == "mediapipe_python" and str((a_report.get("playback", {}) as Dictionary).get("delegate_backend", "")) == "mediapipe_python" and str((a_report.get("playback", {}) as Dictionary).get("entrypoint", "")) == source_video_path,
		"a_mode_exact_seek_not_claimed": str((a_report.get("transport", {}) as Dictionary).get("transport_mode", "")) == CameraTracking.TRANSPORT_MODE_APPROX_TIME_SEEK and not bool((a_report.get("transport", {}) as Dictionary).get("can_seek_frame", true)),
		"truth_metadata_preserved": bool((b_report.get("playback", {}) as Dictionary).get("truth_linked", false)) and bool((a_report.get("playback", {}) as Dictionary).get("truth_linked", false)),
		"parity_landmark_id_match": str(b_frame.get("first_landmark_id", "")) == str(a_frame.get("first_landmark_id", "")),
		"parity_landmark_count_match": int(b_frame.get("landmark_count", -1)) == int(a_frame.get("landmark_count", -1)),
		"parity_first_landmark_x_within_0_15": x_delta <= 0.15,
	}
	var overall_ok := true
	for value in checklist.values():
		if not bool(value):
			overall_ok = false
			break
	var report := {
		"ok": overall_ok,
		"evidence_paths": {
			"session_root": session_root,
			"manifest_path": manifest_path,
			"report_path": report_path,
			"pose_frames_path": session_root.path_join("tracking/pose_frames.jsonl"),
			"source_video_path": source_video_path,
			"timing_truth_path": session_root.path_join("truth/timing_truth.yaml"),
		},
		"validation": {
			"b_mode_package": b_validation,
			"a_mode_package": a_validation,
		},
		"b_mode": b_report,
		"a_mode": a_report,
		"comparison": {
			"first_landmark_x_delta": x_delta,
			"checklist": checklist,
			"c_complete_ready": overall_ok,
		},
	}
	var write_result := _write_json(report_path, report)
	if not bool(write_result.get("ok", false)):
		return write_result
	return report

static func _prepare_saved_session_package(session_root: String) -> Dictionary:
	_delete_recursive(session_root)
	var source_dir_result := DirAccess.make_dir_recursive_absolute(session_root.path_join("source"))
	if source_dir_result != OK:
		return _failure("source_dir_create_failed", "Failed to create dual-mode validation source directory", {
			"session_root": session_root,
			"godot_error": source_dir_result,
		})
	var source_video_path := session_root.path_join(SOURCE_VIDEO_RELATIVE_PATH)
	var source_video_file := FileAccess.open(source_video_path, FileAccess.WRITE)
	if source_video_file == null:
		return _failure("source_video_open_failed", "Failed to open dual-mode validation source video artifact for writing", {
			"source_video_path": source_video_path,
		})
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
	if not bool(created.get("ok", false)):
		return _failure("saved_session_create_failed", "Failed to create dual-mode validation saved-session package", {
			"session_root": session_root,
			"result": created,
		})
	return {"ok": true, "session_root": session_root, "source_video_path": source_video_path}

static func _run_tracker_capture(host: Node, config: Dictionary, exercise_controls: bool) -> Dictionary:
	var tracker := CameraTracking.new()
	host.add_child(tracker)
	tracker.start(config)
	if tracker.get_state().get("state") != CameraTracking.STATE_RUNNING:
		tracker.queue_free()
		return _failure("tracker_start_failed", "Dual-mode validation tracker failed to start", {
			"config": config,
			"state": tracker.get_state(),
		})
	var report := {
		"frame_initial": _frame_brief(tracker.get_tracking_frame()),
		"playback": tracker.get_playback_status(),
		"transport": tracker.get_replay_transport_capabilities(),
	}
	if exercise_controls:
		var pause_result := tracker.pause_replay()
		var seek_result := tracker.seek_replay_to_frame(1)
		var frame_after_seek := tracker.get_tracking_frame()
		var step_forward_result := tracker.step_replay_frames(1)
		var frame_after_step_forward := tracker.get_tracking_frame()
		var step_backward_result := tracker.step_replay_frames(-2)
		var frame_after_step_backward := tracker.get_tracking_frame()
		var play_result := tracker.play_replay()
		OS.delay_msec(130)
		tracker._process(0.13)
		var frame_after_play := tracker.get_tracking_frame()
		var pause_after_play_result := tracker.pause_replay()
		report["controls"] = {
			"pause": pause_result,
			"seek_to_frame_1": seek_result,
			"step_forward_1": step_forward_result,
			"step_backward_2": step_backward_result,
			"play": play_result,
			"pause_after_play": pause_after_play_result,
			"frame_after_seek": _frame_brief(frame_after_seek),
			"frame_after_step_forward": _frame_brief(frame_after_step_forward),
			"frame_after_step_backward": _frame_brief(frame_after_step_backward),
			"frame_after_play": _frame_brief(frame_after_play),
			"transport_status_after_play": tracker.get_replay_transport_status(),
		}
	tracker.queue_free()
	return {"ok": true, "report": report}

static func _b_mode_controls_passed(report: Dictionary) -> bool:
	var controls: Dictionary = report.get("controls", {}) if report.get("controls", {}) is Dictionary else {}
	if controls.is_empty():
		return false
	return bool((controls.get("pause", {}) as Dictionary).get(CameraTrackingBackend.RESULT_SUCCESS, false)) \
		and bool((controls.get("seek_to_frame_1", {}) as Dictionary).get(CameraTrackingBackend.RESULT_SUCCESS, false)) \
		and bool((controls.get("step_forward_1", {}) as Dictionary).get(CameraTrackingBackend.RESULT_SUCCESS, false)) \
		and bool((controls.get("step_backward_2", {}) as Dictionary).get(CameraTrackingBackend.RESULT_SUCCESS, false)) \
		and bool((controls.get("play", {}) as Dictionary).get(CameraTrackingBackend.RESULT_SUCCESS, false)) \
		and bool((controls.get("pause_after_play", {}) as Dictionary).get(CameraTrackingBackend.RESULT_SUCCESS, false)) \
		and int((controls.get("frame_after_seek", {}) as Dictionary).get("frame_index", -1)) == 1 \
		and int((controls.get("frame_after_step_forward", {}) as Dictionary).get("frame_index", -1)) == 2 \
		and int((controls.get("frame_after_step_backward", {}) as Dictionary).get("frame_index", -1)) == 0 \
		and int((controls.get("frame_after_play", {}) as Dictionary).get("frame_index", -1)) == 2

static func _rewrite_manifest_replay_contract(manifest_path: String, replay_contract: Dictionary) -> Dictionary:
	var read_result := _read_json(manifest_path)
	if not bool(read_result.get("ok", false)):
		return read_result
	var manifest: Dictionary = read_result.get("data", {})
	manifest["replay_contract"] = replay_contract.duplicate(true)
	return _write_json(manifest_path, manifest)

static func _frame_brief(frame: Dictionary) -> Dictionary:
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

static func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("json_open_failed", "Failed to open JSON file", {"path": path})
	var parsed := JSON.new()
	if parsed.parse(file.get_as_text()) != OK or not (parsed.data is Dictionary):
		return _failure("json_parse_failed", "Failed to parse JSON object", {"path": path})
	return {"ok": true, "data": parsed.data}

static func _resolve_workspace_path(path: String) -> String:
	if path == "":
		return ""
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	if path.is_absolute_path():
		return path
	var project_root := ProjectSettings.globalize_path("res://")
	return project_root.path_join(path).simplify_path()

static func _write_json(path: String, payload: Dictionary) -> Dictionary:
	var parent_dir := path.get_base_dir()
	if parent_dir != "":
		var make_dir_result := DirAccess.make_dir_recursive_absolute(parent_dir)
		if make_dir_result != OK:
			return _failure("json_parent_dir_create_failed", "Failed to create parent directory for JSON output", {
				"path": path,
				"godot_error": make_dir_result,
			})
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _failure("json_write_open_failed", "Failed to open JSON file for writing", {"path": path})
	file.store_string(JSON.stringify(payload, "\t") + "\n")
	file.close()
	return {"ok": true, "path": path}

static func _delete_recursive(path: String) -> void:
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

static func _failure(code: String, message: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"error": {
			"code": code,
			"message": message,
			"detail": detail.duplicate(true),
		},
	}
