extends RigidBody2D

const ITEM_LAYER = 2
const FLOOR_LAYER = 8
const TOWER_LAYER = 16
const TOUCHED_LAYER = 32

const NORMAL_MASK = 12
const TOWER_MASK = 24
const SANDBOX_DRAG_MASK = 40

@export var drag_speed = 20.0
@export var max_drag_speed = 400.0
@export var angular_damp_amount = 4.0
@export var silent_speed_threshold = 130.0
@export var min_noise_per_hit = 0.3
@export var max_noise_per_hit = 14.0
@export var noise_velocity_scale = 450.0
@export var floor_crash_speed_threshold = 420.0
@export var loud_impact_velocity = 250.0
@export var loud_tap_threshold = 350.0
@export var is_glass = false
@export_enum("wood", "paper", "soft", "plant") var material_type = "wood"
@export var rotate_speed = 3.0

var tap_sound_wood: AudioStream = preload("res://sounds/tap_1.wav")
var tap_sound_paper: AudioStream = preload("res://sounds/tap_2.wav")
var tap_sound_soft: AudioStream = preload("res://sounds/tap_3.wav")
var tap_sound_plant: AudioStream = preload("res://sounds/tap_5.wav")
var glass_tap_sound: AudioStream = preload("res://sounds/tap_4.wav")
var loud_tap_sound: AudioStream = preload("res://sounds/tap_loud.wav")

func _tap_sound_for_category() -> AudioStream:
	match material_type:
		"wood":
			return tap_sound_wood
		"paper":
			return tap_sound_paper
		"soft":
			return tap_sound_soft
		"plant":
			return tap_sound_plant
		_:
			return tap_sound_wood

const SOUND_COOLDOWN = 0.05
const NOISE_COOLDOWN = 0.3
const SETTLE_GRACE_PERIOD = 1500
const FREEZE_VELOCITY_THRESHOLD = 20.0

var dragging = false
var rotating = false
var spawn_position: Vector2
var is_spawner = true
var placed_in_tower = false
var has_been_picked_up = false
var audio_player: AudioStreamPlayer2D
var last_sound_time = 0.0
var last_noise_time = 0.0
var ready_time_ms = 0
var pre_impact_speed = 0.0
var placed_in_tower_time_ms = 0
var released_time_ms = 0
var settled_since_ms = -1
var has_played_land_squash = false
var sprite_base_scale = Vector2.ONE
var cached_image: Image

func _ready():
	add_to_group("physics_item")
	can_sleep = false
	input_pickable = true
	get_viewport().physics_object_picking = true
	input_event.connect(_on_input_event)

	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp = angular_damp_amount
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = 0.0

	var stack_friction = PhysicsMaterial.new()
	stack_friction.friction = 0.8
	physics_material_override = stack_friction

	collision_layer = ITEM_LAYER
	collision_mask = NORMAL_MASK
	spawn_position = global_position

	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)

	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite_base_scale = sprite.scale
		if sprite.texture:
			cached_image = sprite.texture.get_image()

	ready_time_ms = Time.get_ticks_msec()

func _on_body_entered(body):
	if dragging:
		return
	if Time.get_ticks_msec() - ready_time_ms < SETTLE_GRACE_PERIOD:
		return

	var speed = max(linear_velocity.length(), pre_impact_speed)

	_play_impact_sound(speed)

	if placed_in_tower and body.collision_layer == 8 and global_position.y > 80 and speed > floor_crash_speed_threshold:
		GameManager.noise_level = GameManager.noise_threshold
		await get_tree().create_timer(0.4).timeout
		GameManager.wake_cat()
		return

	if speed > silent_speed_threshold:
		var now = Time.get_ticks_msec() / 1000.0
		if now - last_noise_time >= NOISE_COOLDOWN:
			last_noise_time = now
			var amount = clamp(max_noise_per_hit * pow(speed / noise_velocity_scale, 2), min_noise_per_hit, max_noise_per_hit)
			GameManager.register_noise(amount)

func _play_land_squash():
	var sprite = get_node_or_null("Sprite2D")
	if sprite == null:
		return
	sprite.scale = sprite_base_scale
	var tween = create_tween()
	tween.tween_property(sprite, "scale", sprite_base_scale * Vector2(1.18, 0.82), 0.06)
	tween.tween_property(sprite, "scale", sprite_base_scale, 0.14)

func _play_impact_sound(speed):
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_sound_time < SOUND_COOLDOWN:
		return
	last_sound_time = now

	var t = clamp(speed / loud_impact_velocity, 0.0, 1.0)
	t = lerp(0.1, 1.0, t)
	if speed > loud_tap_threshold:
		audio_player.stream = loud_tap_sound
	elif is_glass:
		audio_player.stream = glass_tap_sound
	else:
		audio_player.stream = _tap_sound_for_category()
	audio_player.volume_db = lerp(-24.0, -2.0, t)
	audio_player.pitch_scale = randf_range(0.9, 1.1)
	audio_player.play()

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		start_drag()

func start_drag():
	dragging = true
	has_been_picked_up = true
	GameManager.unregister_tower_item(self)
	placed_in_tower = false
	settled_since_ms = -1
	has_played_land_squash = false
	if freeze:
		freeze = false

func try_pixel_hit(global_click_pos: Vector2) -> bool:
	var sprite = get_node_or_null("Sprite2D")
	if sprite == null or cached_image == null:
		return false
	var local = sprite.to_local(global_click_pos)
	var tex_size = cached_image.get_size()
	var px = int(local.x + tex_size.x / 2.0)
	var py = int(local.y + tex_size.y / 2.0)
	if px < 0 or py < 0 or px >= tex_size.x or py >= tex_size.y:
		return false
	return cached_image.get_pixel(px, py).a > 0.1

func force_freeze():
	if freeze:
		return
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	freeze = true

func _is_touching_floor() -> bool:
	for other in get_colliding_bodies():
		if other.collision_layer == FLOOR_LAYER:
			return true
	return false

func enter_tower_zone():
	if has_been_picked_up and not dragging:
		if not placed_in_tower:
			placed_in_tower_time_ms = Time.get_ticks_msec()
		placed_in_tower = true

func _spawn_replacement():
	var clone = duplicate()
	get_parent().add_child(clone)
	clone.global_position = spawn_position
	clone.spawn_position = spawn_position
	clone.rotation = 0
	clone.linear_velocity = Vector2.ZERO
	clone.angular_velocity = 0
	clone.placed_in_tower = false
	clone.has_been_picked_up = false
	clone.collision_layer = ITEM_LAYER
	clone.collision_mask = NORMAL_MASK
	clone.z_index = 0
	clone.settled_since_ms = -1
	clone.has_played_land_squash = false
	if clone.freeze:
		clone.freeze = false
	clone.sprite_base_scale = sprite_base_scale
	var clone_sprite = clone.get_node_or_null("Sprite2D")
	if clone_sprite:
		clone_sprite.scale = sprite_base_scale

func _unhandled_input(event):
	if not dragging:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			dragging = false
			rotating = false
			released_time_ms = Time.get_ticks_msec()
			if GameManager.sandbox_mode and is_spawner:
				_spawn_replacement()
				is_spawner = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			rotating = event.pressed
	elif event is InputEventKey and event.keycode == KEY_R:
		rotating = event.pressed

func _physics_process(delta):
	pre_impact_speed = linear_velocity.length()

	if dragging:
		var to_mouse = get_global_mouse_position() - global_position
		var vel = to_mouse * drag_speed
		if vel.length() > max_drag_speed:
			vel = vel.normalized() * max_drag_speed
		linear_velocity = vel
		collision_layer = TOUCHED_LAYER if GameManager.sandbox_mode else (ITEM_LAYER | TOUCHED_LAYER)
		collision_mask = SANDBOX_DRAG_MASK if GameManager.sandbox_mode else 0
		z_index = 10
		linear_damp = 0.0
		angular_damp = angular_damp_amount

		if rotating:
			rotation += rotate_speed * delta
	elif placed_in_tower:
		collision_layer = TOWER_LAYER | (TOUCHED_LAYER if has_been_picked_up else 0)
		collision_mask = TOWER_MASK
		z_index = 10
		var target_linear_damp = 6.0 if linear_velocity.length() < 80.0 else 0.0
		var target_angular_damp = 16.0 if linear_velocity.length() < 80.0 else angular_damp_amount
		linear_damp = lerp(linear_damp, target_linear_damp, delta * 4.0)
		angular_damp = lerp(angular_damp, target_angular_damp, delta * 4.0)

		if not freeze:
			if linear_velocity.length() < FREEZE_VELOCITY_THRESHOLD and abs(angular_velocity) < 0.5:
				if settled_since_ms < 0:
					settled_since_ms = Time.get_ticks_msec()
					GameManager.register_tower_item(self)
					if not has_played_land_squash:
						has_played_land_squash = true
						_play_land_squash()
			else:
				settled_since_ms = -1
	else:
		collision_layer = ITEM_LAYER | (TOUCHED_LAYER if has_been_picked_up else 0)
		if has_been_picked_up:
			collision_mask = SANDBOX_DRAG_MASK
		else:
			collision_mask = NORMAL_MASK
		if has_been_picked_up and (linear_velocity.length() > 5.0 or _is_touching_floor()):
			z_index = 10
		else:
			z_index = 0
		linear_damp = 0.0
		angular_damp = angular_damp_amount
