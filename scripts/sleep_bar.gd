extends Sprite2D

@export var pip_count = 19

var full_width = 0.0

func _ready():
	region_enabled = true
	full_width = texture.get_width()
	region_rect = Rect2(0, 0, 0, texture.get_height())

	if GameManager.sandbox_mode:
		visible = false
		var bg = get_parent().get_node_or_null("SleepBarBg")
		if bg:
			bg.visible = false

func _process(_delta):
	var ratio = clamp(GameManager.noise_level / GameManager.noise_threshold, 0.0, 1.0)
	var filled_pips = floor(ratio * pip_count)
	var pip_width = full_width / float(pip_count)
	var r = region_rect
	r.size.x = pip_width * filled_pips
	region_rect = r
