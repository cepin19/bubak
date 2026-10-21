extends Node
## Sound effects and music. Sfx.play("coin") plays assets/sounds/coin.ogg; the sounds are made by
## tools/gen_sounds.py. Settings > Sound turns effects and music on or off (kept in settings.cfg).

const DIR := "res://assets/sounds/"
const VOICES := 10
const MUSIC_DB := -9.0
const NIGHT_DB := -6.0       # the music is a little quieter at night
## Per-sound loudness (dB) and the shortest gap between two plays, so busy moments don't clatter.
const LEVEL := {"tap": -8.0, "hop": -14.0, "love": -10.0, "notify": -6.0, "purr": 4.0, "star": -8.0,
	"chirp": -6.0, "huh": -4.0, "surprise": -4.0}
const GAP := {"hop": 0.25, "love": 0.4, "star": 0.3, "tap": 0.05, "notify": 0.5, "dig": 0.3, "munch": 0.4}

var sound_on := true
var music_on := true
var muted := false            # scripted playtests and screenshots stay silent
var _streams := {}
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _last := {}
var _music: AudioStreamPlayer
var _night := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--autotest") or a.begins_with("--shot"):
			muted = true
	var cfg := ConfigFile.new()
	if cfg.load(Game.SETTINGS_PATH) == OK:
		sound_on = cfg.get_value("general", "sound_on", true)
		music_on = cfg.get_value("general", "music_on", true)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_DB
	add_child(_music)
	_update_music()


func _stream(name: String) -> AudioStream:
	if not _streams.has(name):
		var path := DIR + name + ".ogg"
		_streams[name] = load(path) if ResourceLoader.exists(path) else null
	return _streams[name]


## Plays a sound effect. pitch: 1 = as recorded; a little random variation keeps repeats lively.
func play(name: String, pitch := 1.0, vary := 0.06, db := 0.0) -> void:
	if muted or not sound_on:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(name, -10.0)) < GAP.get(name, 0.03):
		return
	_last[name] = now
	var s := _stream(name)
	if s == null:
		return
	var p := _voices[_next]
	_next = (_next + 1) % VOICES
	p.stream = s
	p.pitch_scale = pitch * randf_range(1.0 - vary, 1.0 + vary)
	p.volume_db = LEVEL.get(name, 0.0) + db
	p.play()


func set_sound_on(on: bool) -> void:
	sound_on = on
	_save("sound_on", on)


func set_music_on(on: bool) -> void:
	music_on = on
	_save("music_on", on)
	_update_music()


## Day or night: the music softens after dark.
func set_night(night: bool) -> void:
	if night == _night:
		return
	_night = night
	if _music.playing:
		_music.create_tween().tween_property(_music, "volume_db", MUSIC_DB + (NIGHT_DB if night else 0.0), 3.0)


func _update_music() -> void:
	var want := music_on and not muted
	if want and not _music.playing:
		var m := _stream("music") as AudioStreamOggVorbis
		if m == null:
			return
		m.loop = true
		_music.stream = m
		_music.volume_db = -40.0
		_music.play()
		_music.create_tween().tween_property(_music, "volume_db", MUSIC_DB + (NIGHT_DB if _night else 0.0), 2.0)
	elif not want and _music.playing:
		_music.stop()


func _save(key: String, value: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(Game.SETTINGS_PATH)
	cfg.set_value("general", key, value)
	cfg.save(Game.SETTINGS_PATH)
