class_name ControllerScreen
extends Control
## Phone as a controller: full-screen touch pad streamed over Wi-Fi to OpenPitchbox
## running on a computer or TV box in the same network.

var link: RemoteLink
var status: Label
var pad: TouchControls


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var bg := ColorRect.new()
	bg.color = Color("0b1220")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	status = UiTheme.label("Looking for a game on this Wi-Fi…", 22, UiTheme.MUTED)
	status.set_anchors_preset(Control.PRESET_CENTER_TOP)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.position = Vector2(-400, 90)
	status.size = Vector2(800, 40)
	add_child(status)
	var exit := UiTheme.button("Exit", func(): Game.show_menu(), 160)
	exit.position = Vector2(20, 16)
	add_child(exit)
	if Game.remote:
		Game.remote.stop()          # this phone is a controller now, not a host
	link = RemoteLink.new()
	add_child(link)
	link.start_client()
	pad = TouchControls.new()
	pad.device = "remote"
	add_child(pad)
	pad.pause_pressed.connect(func():
		VirtualPads.set_button("remote", "pause", true)
		get_tree().create_timer(0.15).timeout.connect(func(): VirtualPads.set_button("remote", "pause", false)))
	DisplayServer.screen_set_keep_on(true)


func _process(_dt: float) -> void:
	if link.host_ip != "":
		status.text = "Connected to %s (%s)" % [link.host_name, link.host_ip]
		status.add_theme_color_override("font_color", UiTheme.ACCENT)


func _exit_tree() -> void:
	DisplayServer.screen_set_keep_on(false)
	Game.start_phone_link.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Game.show_menu()
