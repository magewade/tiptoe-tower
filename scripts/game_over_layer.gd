extends CanvasLayer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$RetryButton.pressed.connect(_on_retry_pressed)

func _on_retry_pressed():
	GameManager.play_click()
	GameManager.restart()
