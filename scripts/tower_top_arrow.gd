extends Sprite2D

@export var settle_velocity_threshold = 15.0
@export var min_rest_time_ms = 500
@export var star_touch_fraction = 1.0 / 3.0

var tower_zone: Area2D
var star: Node2D

func _ready():
	visible = false
	tower_zone = get_tree().current_scene.get_node_or_null("TowerZone")
	if tower_zone == null:
		push_error("TowerTopArrow: could not find TowerZone node")

	star = get_tree().current_scene.get_node_or_null("Star")

func _process(_delta):
	if tower_zone == null:
		return

	var top_y = tower_zone.global_position.y

	for body in tower_zone.get_overlapping_bodies():
		if "placed_in_tower" in body and body.placed_in_tower and not body.dragging and body.linear_velocity.length() < settle_velocity_threshold and Time.get_ticks_msec() - body.placed_in_tower_time_ms > min_rest_time_ms:
			top_y = min(top_y, _get_top_y(body))

	var height = tower_zone.global_position.y - top_y
	if GameManager.height_label:
		GameManager.height_label.text = "height: " + str(int(round(height))) + " cm"

	if star:
		var touch_y = _get_star_touch_y()
		if top_y <= touch_y:
			GameManager.win_game()

func _get_star_touch_y() -> float:
	var star_height = 18.0
	if star is AnimatedSprite2D and star.sprite_frames and star.animation != &"":
		var tex = star.sprite_frames.get_frame_texture(star.animation, 0)
		if tex:
			star_height = tex.get_height() * star.scale.y
	var half_height = star_height / 2.0
	return star.global_position.y + half_height - star_height * star_touch_fraction

func _get_top_y(body: Node) -> float:
	var min_y = body.global_position.y
	for child in body.get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			var half = child.shape.size / 2.0
			var xform = child.global_transform
			for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(-half.x, half.y), Vector2(half.x, half.y)]:
				min_y = min(min_y, (xform * corner).y)
	return min_y
