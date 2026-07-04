extends Node

const BGM_BATTLE12 := "res://assets/audio/bgm_battle12.ogg"
const BGM_BATTLE3  := "res://assets/audio/bgm_battle3_dragon.ogg"
const BGM_MENU     := "res://assets/audio/bgm_menu.mp3"

const SE_START         := "res://assets/audio/se_start.ogg"
const SE_DECIDE        := "res://assets/audio/se_decide.ogg"
const SE_CURSOR        := "res://assets/audio/se_cursor.ogg"
const SE_CANCEL        := "res://assets/audio/se_cancel.ogg"
const SE_SLASH         := "res://assets/audio/se_slash.ogg"
const SE_PUNCH         := "res://assets/audio/se_punch.ogg"
const SE_MAGIC         := "res://assets/audio/se_magic.ogg"
const SE_ARROW         := "res://assets/audio/se_arrow.ogg"
const SE_ENEMY_HIT     := "res://assets/audio/se_enemy_hit.ogg"
const SE_ENEMY_ROW     := "res://assets/audio/se_enemy_row.ogg"
const SE_HEAL_SELF     := "res://assets/audio/se_heal_self.ogg"
const SE_HEAL_ROW      := "res://assets/audio/se_heal_row.ogg"
const SE_PETRIFY       := "res://assets/audio/se_petrify.ogg"
const SE_STONE_CLEAR   := "res://assets/audio/se_stone_clear.ogg"
const SE_CRITICAL      := "res://assets/audio/se_critical.ogg"
const SE_DIE           := "res://assets/audio/se_die.ogg"
const SE_ROTATE_SELECT := "res://assets/audio/se_rotate_select.ogg"
const SE_ROTATE_STEP   := "res://assets/audio/se_rotate_step.ogg"
const SE_SUPPORT       := "res://assets/audio/se_support.ogg"
const SE_SHIELD        := "res://assets/audio/se_shield.ogg"

@export var volume_db: float = -5.0

const _SETTINGS_PATH := "user://settings.cfg"

var _player: AudioStreamPlayer
var master_volume: float = 1.0

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = volume_db
	add_child(_player)
	_player.finished.connect(_player.play)
	_load_settings()

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

func play_se(path: String, extra_db: float = 0.0) -> void:
	var p := AudioStreamPlayer.new()
	p.volume_db = extra_db
	add_child(p)
	var stream: AudioStream = load(path)
	if not stream:
		p.queue_free()
		return
	p.stream = stream
	p.play()
	p.finished.connect(p.queue_free)

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_master_volume()
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.save(_SETTINGS_PATH)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_SETTINGS_PATH) == OK:
		master_volume = float(cfg.get_value("audio", "master_volume", 1.0))
	_apply_master_volume()

func _apply_master_volume() -> void:
	var idx: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(idx, linear_to_db(master_volume))
