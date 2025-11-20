extends CanvasLayer

@onready var help_button: Button = $HelpButton
@onready var panel_bg: TextureRect = $PanelBg

var help_visible := false

func _ready() -> void:
	help_button.text = "Help"
	help_button.pressed.connect(_on_help_button_pressed)

func _on_help_button_pressed() -> void:
	help_visible = !help_visible
	panel_bg.visible = help_visible
