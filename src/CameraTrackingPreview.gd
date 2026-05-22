class_name CameraTrackingPreview
extends RefCounted

static func detached(config: Dictionary = {}, attachment_count: int = 0) -> Dictionary:
	var normalized := CameraTrackingConfig.normalize(config)
	var preview: Dictionary = normalized.get("preview", {})
	return {
		"enabled": preview.get("enabled", true),
		"surface_mode": preview.get("surface_mode", CameraTrackingConfig.DEFAULT_SURFACE_MODE),
		"attached": false,
		"surface_path": NodePath(),
		"attached_surface_count": maxi(0, attachment_count),
		"flip_horizontal": preview.get("flip_horizontal", true),
		"maintain_aspect_ratio": true,
		"backend": normalized.get("backend", CameraTrackingConfig.DEFAULT_BACKEND)
	}

static func attached(node: Node, config: Dictionary = {}, overrides: Dictionary = {}, attachment_count: int = 0) -> Dictionary:
	var descriptor := detached(config, attachment_count)
	for key in overrides.keys():
		descriptor[key] = overrides[key]
	var is_attached := is_instance_valid(node)
	descriptor["attached"] = is_attached
	descriptor["surface_path"] = node.get_path() if is_attached and node.is_inside_tree() else NodePath(node.name if is_attached else "")
	descriptor["attached_surface_count"] = maxi(0, attachment_count)
	return descriptor
