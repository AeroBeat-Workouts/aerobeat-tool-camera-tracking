extends SceneTree

const CameraTrackingScript = preload("res://addons/aerobeat-tool-camera-tracking/src/CameraTracking.gd")
const MODEL_PATH := "/home/derrick/.openclaw/workspace/projects/aerobeat/aerobeat-vendor-mediapipe-python/models/pose_landmarker_lite.task"
const CAMERA_ID := "/dev/video0"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	CameraTrackingScript.clear_backend_factories()
	var tracker: Node = CameraTrackingScript.new()
	root.add_child(tracker)
	tracker.start({
		"source": {"kind": "live_camera", "camera_id": CAMERA_ID},
		"tracking": {"overlay_mode": "optimized"},
		"preview": {"enabled": false, "surface_mode": "attach", "flip_horizontal": true},
		"runtime": {
			"tracking_max_fps": 30,
			"state_update_max_fps": 15,
			"preview_enabled": false,
			"pose_landmarker_model_path": MODEL_PATH,
		},
	})
	for _i in range(120):
		await process_frame
	print("auto_registered_teardown state=%s error=%s" % [JSON.stringify(tracker.get_state()), JSON.stringify(tracker.get_last_error())])
	tracker.stop()
	await process_frame
	tracker.queue_free()
	await process_frame
	quit(0)
