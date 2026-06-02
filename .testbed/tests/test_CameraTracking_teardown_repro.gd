extends GutTest

func test_auto_registered_vendor_backend_teardown_repro_exits_cleanly() -> void:
	var output: Array = []
	var exit_code := OS.execute(
		OS.get_executable_path(),
		[
			"--headless",
			"--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://scripts/repro_auto_registered_backend_teardown.gd"
		],
		output,
		true
	)
	assert_eq(exit_code, 0, "auto-registered vendor backend teardown repro should exit cleanly\n%s" % "\n".join(output))
	assert_true("\n".join(output).contains("auto_registered_teardown state="))
