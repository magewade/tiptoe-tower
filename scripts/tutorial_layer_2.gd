extends CanvasLayer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$InputCatcher.gui_input.connect(_on_input)

func _on_input(event):
	if event is InputEventMouseButton and event.pressed:
		visible = false
