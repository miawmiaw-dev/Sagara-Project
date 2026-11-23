class_name StunIndicator
extends Node2D

const STAR_COUNT := 3
const STAR_COLOR := Color(1.0, 0.88, 0.32, 1.0)
const STAR_OUTLINE_COLOR := Color(0.24, 0.09, 0.02, 0.9)

@export var orbit_radius: float = 17.0
@export var orbit_speed: float = 4.2
@export var star_radius: float = 5.5
@export var bob_height: float = 2.0
@export var bob_speed: float = 5.0

var _stars: Array[Polygon2D] = []
var _stars_root: Node2D
var _label: Label
var _time: float = 0.0
var _active: bool = false


func _ready() -> void:
	visible = false
	set_process(false)
	_stars_root = get_node_or_null("Stars") as Node2D
	if _stars_root == null:
		_stars_root = Node2D.new()
		_stars_root.name = "Stars"
		add_child(_stars_root)
	_label = get_node_or_null("Label") as Label
	_create_stars()


func show_stun() -> void:
	_active = true
	_time = 0.0
	visible = true
	set_process(true)


func hide_stun() -> void:
	_active = false
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	if not _active:
		return

	_time += delta
	var count := maxi(_stars.size(), 1)
	for index in range(_stars.size()):
		var star := _stars[index]
		var angle := _time * orbit_speed + TAU * float(index) / float(count)
		star.position = Vector2(cos(angle), sin(angle) * 0.45) * orbit_radius
		star.rotation = -angle * 1.6
		var pulse := 0.85 + 0.15 * sin(_time * 9.0 + float(index) * 2.0)
		star.scale = Vector2(pulse, pulse)

	if _stars_root != null:
		_stars_root.position.y = sin(_time * bob_speed) * bob_height
	if _label != null:
		_label.modulate.a = 0.72 + 0.28 * sin(_time * 7.0)


func _create_stars() -> void:
	for index in range(STAR_COUNT):
		var star := Polygon2D.new()
		star.name = "Star%d" % (index + 1)
		star.color = STAR_COLOR
		star.polygon = _build_star_polygon(star_radius, star_radius * 0.45)
		_stars_root.add_child(star)

		var outline := Polygon2D.new()
		outline.name = "Outline"
		outline.color = STAR_OUTLINE_COLOR
		outline.polygon = _build_star_polygon(star_radius * 1.25, star_radius * 0.56)
		outline.position = Vector2(1.0, 1.0)
		outline.show_behind_parent = true
		star.add_child(outline)

		_stars.append(star)


func _build_star_polygon(outer_radius: float, inner_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(10):
		var radius := outer_radius if index % 2 == 0 else inner_radius
		var angle := -PI * 0.5 + float(index) * PI / 5.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
