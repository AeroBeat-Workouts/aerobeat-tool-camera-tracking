extends GutTest

const README_PATH := "../README.md"
const PLUGIN_CFG_PATH := "../plugin.cfg"

func _read_repo_file(relative_path: String) -> String:
	var absolute_path := ProjectSettings.globalize_path("res://%s" % relative_path)
	assert_true(FileAccess.file_exists(absolute_path), "Expected repo file to exist: %s" % absolute_path)
	var file := FileAccess.open(absolute_path, FileAccess.READ)
	assert_true(file != null, "Expected repo file to open: %s" % absolute_path)
	return file.get_as_text()

func test_readme_describes_camera_tracking_contract_shell() -> void:
	var readme_text := _read_repo_file(README_PATH)
	assert_true(readme_text.contains("vendor-agnostic camera-tracking service"))
	assert_true(readme_text.contains("singleton shell"))
	assert_true(readme_text.contains(".testbed/"))
	assert_true(readme_text.contains("CAMERA-TRACKING-API.md"))

func test_plugin_cfg_tracks_camera_tracking_identity() -> void:
	var config := ConfigFile.new()
	var error := config.load(ProjectSettings.globalize_path("res://%s" % PLUGIN_CFG_PATH))
	assert_eq(error, OK)
	assert_eq(config.get_value("plugin", "name", ""), "AeroBeat Tool Camera Tracking")
	assert_true(str(config.get_value("plugin", "description", "")).contains("camera-tracking contract shell"))
