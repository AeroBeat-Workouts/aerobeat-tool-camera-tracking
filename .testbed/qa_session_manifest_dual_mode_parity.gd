extends SceneTree

const SessionManifestDualModeValidation = preload("res://support/SessionManifestDualModeValidation.gd")

func _init() -> void:
	var options := _parse_args(OS.get_cmdline_user_args())
	var report := SessionManifestDualModeValidation.run_validation(root, options)
	if not bool(report.get("ok", false)):
		push_error("Dual-mode validation failed: %s" % JSON.stringify(report))
		quit(1)
	print("QA_SESSION_MANIFEST_DUAL_MODE_REPORT=" + JSON.stringify(report))
	var evidence_paths: Dictionary = report.get("evidence_paths", {}) if report.get("evidence_paths", {}) is Dictionary else {}
	print("QA_SESSION_MANIFEST_DUAL_MODE_REPORT_PATH=" + str(evidence_paths.get("report_path", "")))
	quit(0)

func _parse_args(args: PackedStringArray) -> Dictionary:
	var options := {
		"session_root": "user://qa_session_manifest_dual_mode",
	}
	var index := 0
	while index < args.size():
		var arg := str(args[index])
		match arg:
			"--session-root":
				if index + 1 >= args.size():
					push_error("Missing value for --session-root")
					quit(2)
				options["session_root"] = str(args[index + 1])
				index += 2
			"--report-path":
				if index + 1 >= args.size():
					push_error("Missing value for --report-path")
					quit(2)
				options["report_path"] = str(args[index + 1])
				index += 2
			_:
				push_error("Unknown argument: %s" % arg)
				quit(2)
	return options
