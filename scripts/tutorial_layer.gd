extends CanvasLayer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	if GameManager.tutorial_shown:
		visible = false
		return
	GameManager.tutorial_shown = true
	$InputCatcher.gui_input.connect(_on_input)

func _on_input(event):
	if event is InputEventMouseButton and event.pressed:
		visible = false
		var next = get_parent().get_node_or_null("TutorialLayer2")
		if next:
			next.visible = true
