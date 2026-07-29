extends CanvasLayer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$PlayAgainButton.pressed.connect(_on_play_again_pressed)

func _on_play_again_pressed():
	GameManager.play_click()
	GameManager.restart()
