extends Sprite2D

@export var bob_amount = 3.0
@export var bob_speed = 2.0
@export var phase_offset = 0.0

var base_position: Vector2

func _ready():
	base_position = position

func _process(_delta):
	position.y = base_position.y + sin(Time.get_ticks_msec() / 1000.0 * bob_speed + phase_offset) * bob_amount
