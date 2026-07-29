extends Area2D

@export var settle_velocity_threshold = 15.0
@export var min_rest_time_ms = 400

@onready var zone_shape: CollisionShape2D = $TowerZoneShape

func _ready():
	var circle = get_node_or_null("Circle")
	if circle:
		circle.visible = not GameManager.sandbox_mode

func _physics_process(_delta):
	for body in get_overlapping_bodies():
		if body.has_method("enter_tower_zone"):
			body.enter_tower_zone()

	var half_width = zone_shape.shape.size.x / 2.0
	var center_x = zone_shape.global_position.x
	var left = center_x - half_width
	var right = center_x + half_width

	for body in get_tree().get_nodes_in_group("physics_item"):
		if body.has_been_picked_up and not body.dragging and not GameManager.sandbox_mode and body.linear_velocity.length() < settle_velocity_threshold and Time.get_ticks_msec() - body.released_time_ms > min_rest_time_ms and not _fully_inside_x(body, left, right) and _is_touching_floor(body):
			GameManager.wake_cat()

func _is_touching_floor(body) -> bool:
	for other in body.get_colliding_bodies():
		if other.collision_layer == 8:
			return true
	return false

func _fully_inside_x(body: Node, left: float, right: float) -> bool:
	for child in body.get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			var half = child.shape.size / 2.0
			var xform = child.global_transform
			for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(-half.x, half.y), Vector2(half.x, half.y)]:
				var x = (xform * corner).x
				if x < left or x > right:
					return false
	return true
