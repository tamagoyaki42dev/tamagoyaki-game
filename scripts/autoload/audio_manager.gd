extends Node

const BGM_BATTLE12 := "res://assets/audio/bgm_battle12.ogg"
const BGM_BATTLE3  := "res://assets/audio/bgm_menu.ogg"
const BGM_MENU     := "res://assets/audio/bgm_battle3.mp3"

@export var volume_db: float = 0.0

var _player: AudioStreamPlayer

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = volume_db
	add_child(_player)
	_player.finished.connect(_player.play)

func play_bgm(path: String) -> void:
	if _player.playing and _player.stream and _player.stream.resource_path == path:
		return
	var stream: AudioStream = load(path)
	if not stream:
		return
	_player.stream = stream
	_player.play()

func stop_bgm() -> void:
	_player.stop()
