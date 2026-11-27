class_name ControllerScreen
extends Control
## Phone as a controller: full-screen touch pad streamed over Wi-Fi to OpenPitchbox
## running on a computer or TV box in the same network.

var link: RemoteLink
var status: Label
var pad: TouchControls


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	status = UiTheme.label("Looking for OpenPitchbox on this Wi-Fi…", 22, UiTheme.MUTED)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(status)
	status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	status.offset_top = 92
	status.offset_bottom = 132
	var hint := UiTheme.label("Start a match on the computer and pick “Phone 1” as the controller.", 17, UiTheme.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = 132
	hint.offset_bottom = 162
	var exit := UiTheme.button("Exit", func(): Game.show_menu(), 140)
	exit.position = Vector2(24, 20)
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
