class_name CameraTrackingPreviewPresenter
extends Control

const FIT_COVER := "cover"
const FIT_CONTAIN := "contain"
const FIT_STRETCH := "stretch"
const FIT_MODES := [FIT_COVER, FIT_CONTAIN, FIT_STRETCH]

const DEFAULT_OVERLAY_COLOR := Color(0.24, 0.9, 0.45, 0.95)
const DEFAULT_JOINT_RADIUS := 5.0
const DEFAULT_LINE_WIDTH := 2.0
const DEFAULT_MIN_VISIBILITY := 0.35
const DEFAULT_SKELETON_CONNECTIONS := [
	[0, 11], [0, 12],
	[11, 12],
	[11, 13], [13, 15],
	[12, 14], [14, 16],
	[11, 23], [12, 24],
	[23, 24],
	[23, 25], [25, 27],
	[24, 26], [26, 28],
]

class _OverlayLayer:
	extends Control

	var presenter: CameraTrackingPreviewPresenter = null

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if presenter != null:
			presenter._draw_overlay(self)

var _tracking_session: Node = null
var _preview_surface: TextureRect = null
var _overlay_layer: _OverlayLayer = null
var _preview_descriptor: Dictionary = {}
var _tracking_frame: Dictionary = {}
var _fit_mode := FIT_COVER
var _overlay_visible := true
var _overlay_color := DEFAULT_OVERLAY_COLOR
var _joint_radius := DEFAULT_JOINT_RADIUS
var _line_width := DEFAULT_LINE_WIDTH
var _min_visibility := DEFAULT_MIN_VISIBILITY
var _skeleton_connections: Array = DEFAULT_SKELETON_CONNECTIONS.duplicate(true)
var _last_loaded_image_path := ""
var _last_loaded_image_revision := -1

func _init(options: Dictionary = {}) -> void:
	_ensure_structure()
	configure(options)

func _ready() -> void:
	_ensure_structure()
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _exit_tree() -> void:
	_detach_from_tracking_session_if_current_surface_is_active()
	disconnect_tracking_session()

func configure(options: Dictionary = {}) -> void:
	_fit_mode = _normalize_fit_mode(options.get("fit_mode", _fit_mode))
	_overlay_visible = bool(options.get("overlay_visible", _overlay_visible))
	_overlay_color = options.get("overlay_color", _overlay_color)
	_joint_radius = maxf(float(options.get("joint_radius", _joint_radius)), 0.0)
	_line_width = maxf(float(options.get("line_width", _line_width)), 0.0)
	_min_visibility = clampf(float(options.get("min_visibility", _min_visibility)), 0.0, 1.0)
	if options.has("skeleton_connections") and options.get("skeleton_connections") is Array:
		_skeleton_connections = Array(options.get("skeleton_connections", [])).duplicate(true)
	_apply_fit_mode()
	_sync_overlay_visibility()
	_queue_redraw()

func bind_tracking_session(session: Node) -> void:
	if _tracking_session == session:
		_attach_preview_surface_to_tracking_session()
		_sync_from_tracking_session()
		return
	_detach_from_tracking_session_if_current_surface_is_active()
	disconnect_tracking_session()
	_tracking_session = session
	_connect_tracking_session()
	_attach_preview_surface_to_tracking_session()
	_sync_from_tracking_session()

func disconnect_tracking_session() -> void:
	if _tracking_session == null or not is_instance_valid(_tracking_session):
		_tracking_session = null
		return
	if _tracking_session.has_signal("preview_changed") and _tracking_session.preview_changed.is_connected(_on_tracking_session_preview_changed):
		_tracking_session.preview_changed.disconnect(_on_tracking_session_preview_changed)
	if _tracking_session.has_signal("tracking_updated") and _tracking_session.tracking_updated.is_connected(_on_tracking_session_tracking_updated):
		_tracking_session.tracking_updated.disconnect(_on_tracking_session_tracking_updated)
	if _tracking_session.has_signal("state_changed") and _tracking_session.state_changed.is_connected(_on_tracking_session_state_changed):
		_tracking_session.state_changed.disconnect(_on_tracking_session_state_changed)
	_tracking_session = null

func get_tracking_session() -> Node:
	return _tracking_session

func get_preview_surface() -> TextureRect:
	_ensure_structure()
	return _preview_surface

func get_overlay_layer() -> Control:
	_ensure_structure()
	return _overlay_layer

func get_content_rect() -> Rect2:
	_ensure_structure()
	var surface_size := _preview_surface.size
	if surface_size.x <= 0.0 or surface_size.y <= 0.0:
		surface_size = size
	return _compute_content_rect(surface_size, _resolve_source_size())

func get_preview_descriptor_snapshot() -> Dictionary:
	return _preview_descriptor.duplicate(true)

func get_tracking_frame_snapshot() -> Dictionary:
	return _tracking_frame.duplicate(true)

func map_landmark_to_preview_position(landmark: Dictionary) -> Vector2:
	var content_rect := get_content_rect()
	return Vector2(
		content_rect.position.x + clampf(float(landmark.get("x", 0.0)), 0.0, 1.0) * content_rect.size.x,
		content_rect.position.y + clampf(float(landmark.get("y", 0.0)), 0.0, 1.0) * content_rect.size.y
	)

func _ensure_structure() -> void:
	if _preview_surface == null:
		_preview_surface = TextureRect.new()
		_preview_surface.name = "PreviewSurface"
		_preview_surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_preview_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_preview_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_preview_surface)
	if _overlay_layer == null:
		_overlay_layer = _OverlayLayer.new()
		_overlay_layer.name = "OverlayLayer"
		_overlay_layer.presenter = self
		add_child(_overlay_layer)
	_apply_fit_mode()
	_sync_overlay_visibility()

func _normalize_fit_mode(value: Variant) -> String:
	var normalized := str(value).strip_edges().to_lower()
	return normalized if FIT_MODES.has(normalized) else FIT_COVER

func _apply_fit_mode() -> void:
	if _preview_surface == null:
		return
	match _fit_mode:
		FIT_STRETCH:
			_preview_surface.stretch_mode = TextureRect.STRETCH_SCALE
		FIT_CONTAIN:
			_preview_surface.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_:
			_preview_surface.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

func _sync_overlay_visibility() -> void:
	if _overlay_layer != null:
		_overlay_layer.visible = _overlay_visible

func _connect_tracking_session() -> void:
	if _tracking_session == null or not is_instance_valid(_tracking_session):
		return
	if _tracking_session.has_signal("preview_changed") and not _tracking_session.preview_changed.is_connected(_on_tracking_session_preview_changed):
		_tracking_session.preview_changed.connect(_on_tracking_session_preview_changed)
	if _tracking_session.has_signal("tracking_updated") and not _tracking_session.tracking_updated.is_connected(_on_tracking_session_tracking_updated):
		_tracking_session.tracking_updated.connect(_on_tracking_session_tracking_updated)
	if _tracking_session.has_signal("state_changed") and not _tracking_session.state_changed.is_connected(_on_tracking_session_state_changed):
		_tracking_session.state_changed.connect(_on_tracking_session_state_changed)

func _attach_preview_surface_to_tracking_session() -> void:
	_ensure_structure()
	if _tracking_session != null and is_instance_valid(_tracking_session) and _tracking_session.has_method("attach_preview_surface"):
		_tracking_session.attach_preview_surface(_preview_surface)

func _detach_from_tracking_session_if_current_surface_is_active() -> void:
	if _tracking_session == null or not is_instance_valid(_tracking_session):
		return
	if not _tracking_session.has_method("detach_preview_surface"):
		return
	if not _tracking_session.has_method("get_preview_descriptor"):
		return
	var descriptor: Dictionary = _tracking_session.get_preview_descriptor()
	if not bool(descriptor.get("attached", false)):
		return
	if _preview_surface == null or not _preview_surface.is_inside_tree():
		return
	var active_path := NodePath(descriptor.get("surface_path", NodePath()))
	if active_path == _preview_surface.get_path():
		_tracking_session.detach_preview_surface()

func _sync_from_tracking_session() -> void:
	if _tracking_session == null or not is_instance_valid(_tracking_session):
		_apply_preview_descriptor({})
		_apply_tracking_frame({})
		return
	if _tracking_session.has_method("get_preview_descriptor"):
		_apply_preview_descriptor(_tracking_session.get_preview_descriptor())
	if _tracking_session.has_method("get_tracking_frame"):
		_apply_tracking_frame(_tracking_session.get_tracking_frame())

func _apply_preview_descriptor(descriptor: Dictionary) -> void:
	_preview_descriptor = descriptor.duplicate(true)
	_apply_surface_flip()
	_update_preview_texture()
	_queue_redraw()

func _apply_tracking_frame(frame: Dictionary) -> void:
	_tracking_frame = frame.duplicate(true)
	_queue_redraw()

func _apply_surface_flip() -> void:
	if _preview_surface == null:
		return
	_preview_surface.flip_h = bool(_preview_descriptor.get("flip_horizontal", false))

func _update_preview_texture() -> void:
	if _preview_surface == null:
		return
	var image_path := str(_preview_descriptor.get("image_path", "")).strip_edges()
	var image_revision := int(_preview_descriptor.get("image_revision", -1))
	if image_path == "":
		if _last_loaded_image_path != "" or _preview_surface.texture != null:
			_preview_surface.texture = null
		_last_loaded_image_path = ""
		_last_loaded_image_revision = -1
		return
	if image_path == _last_loaded_image_path and image_revision == _last_loaded_image_revision and _preview_surface.texture != null:
		return
	var image := Image.new()
	var error := image.load(image_path)
	if error != OK:
		return
	_preview_surface.texture = ImageTexture.create_from_image(image)
	_last_loaded_image_path = image_path
	_last_loaded_image_revision = image_revision

func _resolve_source_size() -> Vector2:
	if _preview_surface != null and _preview_surface.texture != null:
		return _preview_surface.texture.get_size()
	var image_width := int(_preview_descriptor.get("image_width", 0))
	var image_height := int(_preview_descriptor.get("image_height", 0))
	if image_width > 0 and image_height > 0:
		return Vector2(image_width, image_height)
	var preview_width := int(_preview_descriptor.get("width", 0))
	var preview_height := int(_preview_descriptor.get("height", 0))
	if preview_width > 0 and preview_height > 0:
		return Vector2(preview_width, preview_height)
	var frame_size: Dictionary = _tracking_frame.get("frame_size", {})
	var frame_width := int(frame_size.get("x", 0))
	var frame_height := int(frame_size.get("y", 0))
	if frame_width > 0 and frame_height > 0:
		return Vector2(frame_width, frame_height)
	return Vector2.ZERO

func _compute_content_rect(surface_size: Vector2, source_size: Vector2) -> Rect2:
	if surface_size.x <= 0.0 or surface_size.y <= 0.0:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	if _fit_mode == FIT_STRETCH or source_size.x <= 0.0 or source_size.y <= 0.0:
		return Rect2(Vector2.ZERO, surface_size)
	var scale := minf(surface_size.x / source_size.x, surface_size.y / source_size.y)
	if _fit_mode == FIT_COVER:
		scale = maxf(surface_size.x / source_size.x, surface_size.y / source_size.y)
	var content_size := Vector2(source_size.x * scale, source_size.y * scale)
	var content_position := (surface_size - content_size) * 0.5
	return Rect2(content_position, content_size)

func _visible_landmarks() -> Array:
	var raw_landmarks: Variant = _tracking_frame.get("landmarks", [])
	if not raw_landmarks is Array:
		return []
	var visible: Array = []
	for landmark_variant: Variant in raw_landmarks:
		if not landmark_variant is Dictionary:
			continue
		var landmark: Dictionary = landmark_variant
		if float(landmark.get("v", landmark.get("visibility", 1.0))) < _min_visibility:
			continue
		visible.append(landmark)
	return visible

func _draw_overlay(canvas: Control) -> void:
	if not _overlay_visible or canvas == null:
		return
	var landmarks := _visible_landmarks()
	if landmarks.is_empty():
		return
	var landmarks_by_id := {}
	for landmark: Dictionary in landmarks:
		landmarks_by_id[int(landmark.get("id", -1))] = landmark
	for connection_variant: Variant in _skeleton_connections:
		if not connection_variant is Array:
			continue
		var connection: Array = connection_variant
		if connection.size() < 2:
			continue
		var start_id := int(connection[0])
		var end_id := int(connection[1])
		if not landmarks_by_id.has(start_id) or not landmarks_by_id.has(end_id):
			continue
		canvas.draw_line(
			map_landmark_to_preview_position(landmarks_by_id[start_id]),
			map_landmark_to_preview_position(landmarks_by_id[end_id]),
			_overlay_color,
			_line_width,
			true
		)
	for landmark: Dictionary in landmarks:
		canvas.draw_circle(map_landmark_to_preview_position(landmark), _joint_radius, _overlay_color)

func _queue_redraw() -> void:
	queue_redraw()
	if _overlay_layer != null:
		_overlay_layer.queue_redraw()

func _on_tracking_session_preview_changed(descriptor: Dictionary) -> void:
	_apply_preview_descriptor(descriptor)

func _on_tracking_session_tracking_updated(frame: Dictionary) -> void:
	_apply_tracking_frame(frame)

func _on_tracking_session_state_changed(_state: String, _detail: Dictionary) -> void:
	_sync_from_tracking_session()
