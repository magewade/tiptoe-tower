extends TextureButton

@export var pulse_amount = 0.06
@export var pulse_speed = 2.0
@export var hover_scale_boost = 0.12
@export var hover_modulate = Color(1.15, 1.15, 1.15)

var base_scale: Vector2
var is_hovered = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	base_scale = scale
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered():
	is_hovered = true
	modulate = hover_modulate

func _on_mouse_exited():
	is_hovered = false
	modulate = Color(1, 1, 1)

func _process(_delta):
	pivot_offset = size / 2.0
	var t = sin(Time.get_ticks_msec() / 1000.0 * pulse_speed)
	var extra = hover_scale_boost if is_hovered else 0.0
	scale = base_scale * (1.0 + t * pulse_amount + extra)
