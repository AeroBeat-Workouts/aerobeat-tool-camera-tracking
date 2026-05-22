class_name CameraTrackingPreview
extends RefCounted

static func detached(config: Dictionary = {}) -> Dictionary:
	var normalized := CameraTrackingConfig.normalize(config)
	var preview: Dictionary = normalized.get("preview", {})
	return {
		"enabled": preview.get("enabled", true),
		"surface_mode": preview.get("surface_mode", CameraTrackingConfig.DEFAULT_SURFACE_MODE),
		"attached": false,
		"surface_path": NodePath(),
		"flip_horizontal": preview.get("flip_horizontal", true),
		"maintain_aspect_ratio": true,
		"backend": normalized.get("backend", CameraTrackingConfig.DEFAULT_BACKEND)
	}

static func attached(node: Node, config: Dictionary = {}, overrides: Dictionary = {}) -> Dictionary:
	var descriptor := detached(config)
	for key in overrides.keys():
		descriptor[key] = overrides[key]
	var is_attached := is_instance_valid(node)
	descriptor["attached"] = is_attached
	descriptor["surface_path"] = node.get_path() if is_attached and node.is_inside_tree() else NodePath(node.name if is_attached else "")
	return descriptor
