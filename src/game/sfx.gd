class_name Sfx
extends Node
## Plays the generated sound effects in assets/sfx. Missing files are ignored.

var _streams := {}
var _players: Array = []
var crowd: AudioStreamPlayer
var volume_db := 0.0

const NAMES := ["kick", "kick_hard", "bounce", "wall", "post", "net", "whistle", "whistle_end", "tackle", "cheer", "groan", "catch", "goal_jingle"]


func _ready() -> void:
	for n in NAMES:
		var path := "res://assets/sfx/%s.wav" % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	crowd = AudioStreamPlayer.new()
	add_child(crowd)
	if ResourceLoader.exists("res://assets/sfx/crowd_loop.wav"):
		var s: AudioStreamWAV = load("res://assets/sfx/crowd_loop.wav")
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = s.data.size() / 2
		crowd.stream = s
		crowd.volume_db = -12.0
		crowd.play()


func set_volume(linear: float) -> void:
	volume_db = linear_to_db(maxf(linear, 0.001))
	if crowd:
		crowd.volume_db = -12.0 + volume_db


func play(name: String, gain_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(name):
		return
	for p in _players:
		var ap := p as AudioStreamPlayer
		if not ap.playing:
			ap.stream = _streams[name]
			ap.volume_db = gain_db + volume_db
			ap.pitch_scale = pitch
			ap.play()
			return


func crowd_level(db: float) -> void:
	if crowd:
		crowd.volume_db = db + volume_db
