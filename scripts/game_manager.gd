extends Node

const SETTLE_VELOCITY_THRESHOLD = 15.0
const MIN_SETTLE_WAIT = 0.2
const MAX_ACTIVE_TOWER_ITEMS = 5
const MAX_RELOAD_SETTLE_WAIT = 1.5

var tower_order: Array = []

var noise_level = 0.0
var noise_threshold = 15.0
var cat_awake = false
var game_won = false
var sandbox_mode = false

var settle_check_active = false
var settle_wait_elapsed = 0.0

var transition_rect: ColorRect
var transition_material: ShaderMaterial
var mode_toggle_btn: TextureButton
var toggle_blue_tex: Texture2D
var toggle_half_tex: Texture2D
var toggle_red_tex: Texture2D
var toggle_switching = false
var toggle_label: Label
var toggle_hint: Label
var height_label: Label
var restarting = false
var tutorial_shown = false
var click_player: AudioStreamPlayer
var click_sound: AudioStream = preload("res://sounds/click.wav")
var failure_sound: AudioStream = preload("res://sounds/failure.wav")
var pickup_sound: AudioStream = preload("res://sounds/pickup.wav")
var win_sound: AudioStream = preload("res://sounds/win.wav")
var win_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
const MUSIC_VOLUME = -14.0
const MUSIC_DUCKED_VOLUME = -19.0

func _ready():
	var layer = CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	click_player = AudioStreamPlayer.new()
	click_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(click_player)

	win_player = AudioStreamPlayer.new()
	win_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(win_player)

	music_player = AudioStreamPlayer.new()
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.stream = preload("res://music/BeepBox-Song.wav")
	music_player.volume_db = MUSIC_VOLUME
	music_player.finished.connect(func(): music_player.play())
	add_child(music_player)
	music_player.play()

	transition_rect = ColorRect.new()
	transition_rect.anchor_right = 1.0
	transition_rect.anchor_bottom = 1.0
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_material = ShaderMaterial.new()
	transition_material.shader = load("res://shaders/blur_transition.gdshader")
	transition_material.set_shader_parameter("blur_amount", 0.0)
	transition_rect.material = transition_material
	transition_rect.visible = false
	layer.add_child(transition_rect)

	_setup_mode_toggle(layer)

func _setup_mode_toggle(layer):
	toggle_blue_tex = load("res://sprites/toggle_blue.png")
	toggle_half_tex = load("res://sprites/toggle_half.png")
	toggle_red_tex = load("res://sprites/toggle_red.png")

	mode_toggle_btn = TextureButton.new()
	mode_toggle_btn.position = Vector2(10, 8)
	mode_toggle_btn.texture_normal = toggle_blue_tex if sandbox_mode else toggle_red_tex
	mode_toggle_btn.ignore_texture_size = true
	mode_toggle_btn.stretch_mode = TextureButton.STRETCH_SCALE
	mode_toggle_btn.custom_minimum_size = Vector2(47.5, 27.5)
	mode_toggle_btn.size = Vector2(47.5, 27.5)
	mode_toggle_btn.pressed.connect(_on_toggle_pressed)
	mode_toggle_btn.mouse_entered.connect(_on_toggle_hover_start)
	mode_toggle_btn.mouse_exited.connect(_on_toggle_hover_end)
	layer.add_child(mode_toggle_btn)

	toggle_hint = Label.new()
	toggle_hint.text = _hint_text()
	toggle_hint.position = Vector2(62, 28)
	toggle_hint.visible = false
	toggle_hint.add_theme_font_override("font", load("res://fonts/PixelOperator8.ttf"))
	toggle_hint.add_theme_font_size_override("font_size", 8)
	toggle_hint.add_theme_color_override("font_color", Color(0.552941, 0.623529, 0.705882, 1))
	toggle_hint.add_theme_color_override("font_outline_color", Color(0.945098, 0.823529, 0.741176, 1))
	toggle_hint.add_theme_constant_override("outline_size", 2)
	layer.add_child(toggle_hint)

	toggle_label = Label.new()
	toggle_label.text = "sandbox mode: on" if sandbox_mode else "sandbox mode: off"
	toggle_label.position = Vector2(62, 14)
	toggle_label.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle_label.mouse_entered.connect(_on_toggle_hover_start)
	toggle_label.mouse_exited.connect(_on_toggle_hover_end)
	toggle_label.add_theme_font_override("font", load("res://fonts/PixelOperator8.ttf"))
	toggle_label.add_theme_font_size_override("font_size", 13)
	toggle_label.add_theme_color_override("font_color", Color(0.552941, 0.623529, 0.705882, 1))
	toggle_label.add_theme_color_override("font_outline_color", Color(0.945098, 0.823529, 0.741176, 1))
	toggle_label.add_theme_constant_override("outline_size", 5)
	layer.add_child(toggle_label)

	height_label = Label.new()
	height_label.text = "height: 0"
	height_label.anchor_left = 1.0
	height_label.anchor_right = 1.0
	height_label.offset_left = -220
	height_label.offset_right = -10
	height_label.offset_top = 14
	height_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	height_label.add_theme_font_override("font", load("res://fonts/PixelOperator8.ttf"))
	height_label.add_theme_font_size_override("font_size", 13)
	height_label.add_theme_color_override("font_color", Color(0.552941, 0.623529, 0.705882, 1))
	height_label.add_theme_color_override("font_outline_color", Color(0.945098, 0.823529, 0.741176, 1))
	height_label.add_theme_constant_override("outline_size", 5)
	layer.add_child(height_label)

func _on_toggle_hover_start():
	toggle_hint.visible = true

func _on_toggle_hover_end():
	toggle_hint.visible = false

func _hint_text() -> String:
	if sandbox_mode:
		return "sandbox mode - infinite items, no consequences"
	return "challenge mode - build carefully - don't wake the cat"

func play_click():
	click_player.stream = click_sound
	click_player.play()

func duck_music():
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(music_player, "volume_db", MUSIC_DUCKED_VOLUME, 0.3)

func unduck_music():
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(music_player, "volume_db", MUSIC_VOLUME, 0.3)

func _on_toggle_pressed():
	if toggle_switching:
		return
	play_click()
	toggle_switching = true
	var new_sandbox = not sandbox_mode
	mode_toggle_btn.texture_normal = toggle_half_tex
	await get_tree().create_timer(0.12).timeout
	mode_toggle_btn.texture_normal = toggle_blue_tex if new_sandbox else toggle_red_tex
	toggle_label.text = "sandbox mode: on" if new_sandbox else "sandbox mode: off"
	sandbox_mode = new_sandbox
	toggle_hint.text = _hint_text()
	_set_mode(new_sandbox)
	toggle_switching = false

func _set_mode(sandbox: bool):
	sandbox_mode = sandbox
	restart()

func register_tower_item(item):
	if tower_order.has(item):
		return
	tower_order.append(item)
	while tower_order.size() > MAX_ACTIVE_TOWER_ITEMS:
		var oldest = tower_order.pop_front()
		if is_instance_valid(oldest):
			oldest.force_freeze()

func unregister_tower_item(item):
	tower_order.erase(item)

func register_noise(amount):
	if cat_awake or game_won:
		return

	noise_level += amount
	print("Noise: ", noise_level, " / ", noise_threshold)
	if noise_level >= noise_threshold:
		wake_cat()

func wake_cat():
	if cat_awake or game_won or sandbox_mode:
		return
	cat_awake = true
	settle_check_active = true
	settle_wait_elapsed = 0.0

func win_game():
	if cat_awake or game_won:
		return
	game_won = true
	get_tree().paused = true
	duck_music()
	click_player.stream = pickup_sound
	click_player.play()
	var layer = get_tree().current_scene.get_node_or_null("WinLayer")
	if layer:
		layer.visible = true
	win_player.stream = win_sound
	win_player.play()

func _process(delta):
	if not settle_check_active:
		return
	settle_wait_elapsed += delta
	if settle_wait_elapsed < MIN_SETTLE_WAIT:
		return
	if _all_items_settled():
		_show_game_over()

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_pixel_pick_fallback()

func _try_pixel_pick_fallback():
	var items = get_tree().get_nodes_in_group("physics_item")
	for item in items:
		if item.dragging:
			return

	var scene = get_tree().current_scene
	if scene == null:
		return
	var click_pos = scene.get_global_mouse_position()

	var best_item = null
	var best_z = -INF
	for item in items:
		if item.try_pixel_hit(click_pos) and item.z_index > best_z:
			best_item = item
			best_z = item.z_index

	if best_item:
		best_item.start_drag()

func _show_game_over():
	settle_check_active = false
	get_tree().paused = true
	duck_music()
	click_player.stream = failure_sound
	click_player.play()
	var layer = get_tree().current_scene.get_node_or_null("GameOverLayer")
	if layer:
		layer.visible = true

func _all_items_settled() -> bool:
	for body in get_tree().get_nodes_in_group("physics_item"):
		if body.linear_velocity.length() > SETTLE_VELOCITY_THRESHOLD:
			return false
	return true

func restart():
	if restarting:
		return
	restarting = true

	transition_rect.visible = true
	var tween_in = create_tween()
	tween_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_in.tween_method(_set_blur, 0.0, 16.0, 0.2)
	await tween_in.finished
	await get_tree().create_timer(0.08).timeout

	_do_reload()

	var waited = 0.0
	while waited < MAX_RELOAD_SETTLE_WAIT:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if _all_items_settled():
			break

	var tween_out = create_tween()
	tween_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_out.tween_method(_set_blur, 16.0, 0.0, 0.3)
	await tween_out.finished
	transition_rect.visible = false

	restarting = false

func _do_reload():
	noise_level = 0.0
	cat_awake = false
	game_won = false
	settle_check_active = false
	tower_order.clear()

	var game_over_layer = get_tree().current_scene.get_node_or_null("GameOverLayer")
	if game_over_layer:
		game_over_layer.visible = false
	var win_layer = get_tree().current_scene.get_node_or_null("WinLayer")
	if win_layer:
		win_layer.visible = false

	unduck_music()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _set_blur(value: float):
	transition_material.set_shader_parameter("blur_amount", value)
