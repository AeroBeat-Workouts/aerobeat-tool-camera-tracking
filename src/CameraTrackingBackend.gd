class_name CameraTrackingBackend
extends RefCounted

signal state_changed(state: String, detail: Dictionary)
signal tracking_updated(frame: Dictionary)
signal preview_changed(descriptor: Dictionary)
signal cameras_changed(cameras: Array)
signal error_raised(error_info: Dictionary)

const RESULT_SUCCESS := "success"
const RESULT_CODE := "code"
const RESULT_MESSAGE := "message"
const RESULT_DETAIL := "detail"
const TRANSPORT_MODE_EXACT_DECODED_FRAME := "exact_decoded_frame"
const TRANSPORT_MODE_EXACT_OWNED_FRAME_INDEX := "exact_owned_frame_index"
const TRANSPORT_MODE_APPROX_TIME_SEEK := "approx_time_seek"
const TRANSPORT_UNSUPPORTED_CODE := "backend_transport_unsupported"
const REPLAY_TRANSPORT_INACTIVE_CODE := "replay_transport_inactive"

func get_backend_id() -> String:
	return ""

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

func get_camera_options(_camera_id: String = "") -> Dictionary:
	return {}

func get_playback_status() -> Dictionary:
	return {}

func get_replay_transport_capabilities() -> Dictionary:
	if not _has_active_file_replay_transport():
		return {
			"transport_mode": TRANSPORT_MODE_APPROX_TIME_SEEK,
			"can_step_forward": false,
			"can_step_backward": false,
			"can_seek_frame": false,
			"nominal_fps": null,
			"frame_duration_sec": null,
			"exactness_note": "No active replay/video-file transport is loaded on this backend.",
			"limitation_code": REPLAY_TRANSPORT_INACTIVE_CODE,
		}
	return {
		"transport_mode": TRANSPORT_MODE_APPROX_TIME_SEEK,
		"can_step_forward": false,
		"can_step_backward": false,
		"can_seek_frame": false,
		"nominal_fps": null,
		"frame_duration_sec": null,
		"exactness_note": "This backend exposes replay time/paused status for video-file sessions but does not prove exact frame-addressed stepping.",
		"limitation_code": TRANSPORT_UNSUPPORTED_CODE,
	}

func get_replay_transport_status() -> Dictionary:
	var playback_status := get_playback_status()
	var capabilities := get_replay_transport_capabilities()
	var playback_state := str(playback_status.get("state", "")).strip_edges().to_lower()
	return {
		"transport_mode": str(capabilities.get("transport_mode", TRANSPORT_MODE_APPROX_TIME_SEEK)),
		"can_step_forward": bool(capabilities.get("can_step_forward", false)),
		"can_step_backward": bool(capabilities.get("can_step_backward", false)),
		"can_seek_frame": bool(capabilities.get("can_seek_frame", false)),
		"frame_index": null,
		"frame_count": null,
		"nominal_fps": capabilities.get("nominal_fps", null),
		"frame_duration_sec": capabilities.get("frame_duration_sec", null),
		"paused": bool(playback_status.get("paused", playback_state == "paused" or playback_state == "ended")),
		"position_sec": float(playback_status.get("current_time_sec", playback_status.get("position_sec", 0.0))),
		"duration_sec": float(playback_status.get("duration_sec", 0.0)),
		"exactness_note": str(capabilities.get("exactness_note", "")),
		"limitation_code": str(capabilities.get("limitation_code", REPLAY_TRANSPORT_INACTIVE_CODE)),
	}

func play_replay() -> Dictionary:
	return _transport_unsupported("play_replay")

func pause_replay() -> Dictionary:
	return _transport_unsupported("pause_replay")

func step_replay_frames(_delta_frames: int) -> Dictionary:
	return _transport_unsupported("step_replay_frames")

func seek_replay_to_frame(_frame_index: int) -> Dictionary:
	return _transport_unsupported("seek_replay_to_frame")

func _has_active_file_replay_transport() -> bool:
	var playback_status := get_playback_status()
	if bool(playback_status.get("is_file_source", false)):
		return true
	var source := str(playback_status.get("source", "")).strip_edges()
	return source != ""

func _transport_unsupported(method_name: String) -> Dictionary:
	var capabilities := get_replay_transport_capabilities()
	return {
		RESULT_SUCCESS: false,
		RESULT_CODE: TRANSPORT_UNSUPPORTED_CODE if _has_active_file_replay_transport() else REPLAY_TRANSPORT_INACTIVE_CODE,
		RESULT_MESSAGE: "%s requires exact frame-addressed replay transport, but this backend only supports %s." % [method_name, str(capabilities.get("transport_mode", TRANSPORT_MODE_APPROX_TIME_SEEK))],
		RESULT_DETAIL: {
			"method": method_name,
			"transport_mode": capabilities.get("transport_mode", TRANSPORT_MODE_APPROX_TIME_SEEK),
			"capabilities": capabilities.duplicate(true),
		},
	}
