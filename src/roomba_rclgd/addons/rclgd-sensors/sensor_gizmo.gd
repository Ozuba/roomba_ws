@tool
extends EditorNode3DGizmoPlugin
## Base of the rclgd-sensors gizmos: draws the sensor's class icon as a billboard, like the
## built-in 3D nodes, then the sensor-specific geometry from _draw_sensor(). All geometry is in
## the sensor's local frame (Godot convention: forward is -Z, up is +Y).

## Billboard size, as the built-in node icons use
const ICON_SIZE: float = 0.05
## The class icons are 16 px SVGs; rasterize them larger for the billboard
const ICON_RASTER_SCALE: float = 4.0

var _icon_state: int = -1 # -1: not loaded yet, 0: the class has no icon, 1: "icon" material exists

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	if _icon_state == -1:
		var icon := _load_class_icon(_get_gizmo_name())
		if icon:
			create_icon_material("icon", icon)
		_icon_state = 1 if icon else 0
	if _icon_state == 1:
		gizmo.add_unscaled_billboard(get_material("icon", gizmo), ICON_SIZE)
	_draw_sensor(gizmo, gizmo.get_node_3d())

## Draws the sensor's geometry; the gizmo is already cleared
func _draw_sensor(_gizmo: EditorNode3DGizmo, _node: Node3D) -> void:
	pass

## The @icon of a global class, rasterized at ICON_RASTER_SCALE
static func _load_class_icon(class_name_: String) -> Texture2D:
	for global_class in ProjectSettings.get_global_class_list():
		if global_class["class"] == class_name_ and not global_class["icon"].is_empty():
			var image := Image.new()
			if image.load_svg_from_buffer(FileAccess.get_file_as_bytes(global_class["icon"]), ICON_RASTER_SCALE) == OK:
				return ImageTexture.create_from_image(image)
	return null

## Size of the drawn sensing volume in meters. Real ranges (up to hundreds of meters)
## would swamp the viewport, so gizmos show the shape of the field of view, not its reach.
const DISPLAY_RANGE: float = 1.0

## Unit direction for a horizontal angle `azimuth` (0 = forward, positive = right)
## and a vertical angle `elevation` (positive = up), both in radians.
static func direction(azimuth: float, elevation: float) -> Vector3:
	return Vector3(sin(azimuth) * cos(elevation), sin(elevation), -cos(azimuth) * cos(elevation))

## Appends a polyline through `points` to `lines` as segment pairs.
static func add_polyline(lines: PackedVector3Array, points: PackedVector3Array, closed: bool = false) -> void:
	for i in range(points.size() - 1):
		lines.append(points[i])
		lines.append(points[i + 1])
	if closed and points.size() > 2:
		lines.append(points[points.size() - 1])
		lines.append(points[0])

## Appends a circle of `radius` around `center`, lying in the plane spanned by `u` and `v`.
static func add_circle(lines: PackedVector3Array, center: Vector3, u: Vector3, v: Vector3, radius: float, segments: int = 32) -> void:
	var points := PackedVector3Array()
	for i in range(segments):
		var a := TAU * i / segments
		points.append(center + (u * cos(a) + v * sin(a)) * radius)
	add_polyline(lines, points, true)

## Appends the 12 edges of an axis-aligned box centered at `center`.
static func add_box(lines: PackedVector3Array, center: Vector3, size: Vector3) -> void:
	var h := size * 0.5
	var c := []
	for i in range(8):
		c.append(center + Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	for edge in [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]:
		lines.append(c[edge[0]])
		lines.append(c[edge[1]])

## Draws `lines` with material `material_name` and makes them clickable in the viewport.
func commit(gizmo: EditorNode3DGizmo, lines: PackedVector3Array, material_name: String = "main") -> void:
	if lines.is_empty():
		return
	gizmo.add_lines(lines, get_material(material_name, gizmo))
	gizmo.add_collision_segments(lines)
