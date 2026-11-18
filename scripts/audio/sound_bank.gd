extends Node

## Short names for the clips that match moments already in the game.
## Call SoundBank.play("gunshot"), SoundBank.loop("rain"), or SoundBank.music("title").
## volume_db is that clip's loudness. 0 is full level. Rain, wind, typing, and music start quieter.
const _CLIPS := {
	"rain": {
		"stream": preload("res://audio/Free Sounds Pack/Ambient Rain Moderate Loop 1.wav"),
		"volume_db": -6.0,
	},
	"wind": {
		"stream": preload("res://audio/Free Sounds Pack/Ambient Wind Loop 1.wav"),
		"volume_db": -6.0,
	},
	"gunshot": {
		"stream": preload("res://audio/Free Sounds Pack/Sci-Fi Gun 1-1.wav"),
		"volume_db": 0.0,
	},
	"shotgun": {
		"stream": preload("res://audio/Free Sounds Pack/Gunshot 1-1.wav"),
		"volume_db": 0.0,
	},
	"gunshot_heavy": {
		"stream": preload("res://audio/Free Sounds Pack/Gunshot 7-1.wav"),
		"volume_db": 0.0,
	},
	"missile": {
		"stream": preload("res://audio/Free Sounds Pack/Fire Whoosh 2-15.wav"),
		"volume_db": 0.0,
	},
	"explosion": {
		"stream": preload("res://audio/Free Sounds Pack/Explosion Medium 2-1.wav"),
		"volume_db": 0.0,
	},
	"explosion_large": {
		"stream": preload("res://audio/Free Sounds Pack/Explosion Large 1-1.wav"),
		"volume_db": 0.0,
	},
	"hit": {
		"stream": preload("res://audio/Free Sounds Pack/Hit Generic 5-1.wav"),
		"volume_db": 0.0,
	},
	"melee": {
		"stream": preload("res://audio/Free Sounds Pack/Punch 2-1.wav"),
		"volume_db": 0.0,
	},
	"blade": {
		"stream": preload("res://audio/Free Sounds Pack/Stab 4-1.wav"),
		"volume_db": 0.0,
	},
	"guard": {
		"stream": preload("res://audio/Free Sounds Pack/Shield Metal Impact 1-3.wav"),
		"volume_db": 0.0,
	},
	"dodge": {
		"stream": preload("res://audio/Free Sounds Pack/Whoosh 4-1.wav"),
		"volume_db": 0.0,
	},
	"step": {
		"stream": preload("res://audio/Free Sounds Pack/Rock Impact 11.wav"),
		"volume_db": 0.0,
	},
	"draw": {
		"stream": preload("res://audio/Free Sounds Pack/Draw Weapon Metal 1-1.wav"),
		"volume_db": 0.0,
	},
	"ui": {
		"stream": preload("res://audio/Free Sounds Pack/Sci-Fi Interface 8-1.wav"),
		"volume_db": 0.0,
	},
	"upgrade": {
		"stream": preload("res://audio/Free Sounds Pack/Special Collectible 9-1.wav"),
		"volume_db": 0.0,
	},
	"typing": {
		"stream": preload("res://audio/Free Sounds Pack/Interface 3-3.wav"),
		"volume_db": -10.0,
	},
	## Title, the mission pick, and mech select share this track.
	"title": {
		"stream": preload("res://audio/CraftPix.com/Music/WAV/Main_theme_sewerage.wav"),
		"volume_db": -10.0,
	},
	"overworld": {
		"stream": preload("res://audio/CraftPix.com/Music/WAV/Alternative_theme_prison.wav"),
		"volume_db": -10.0,
	},
	"battle": {
		"stream": preload("res://audio/CraftPix.com/Music/WAV/Prisoners_escape_theme.wav"),
		"volume_db": -10.0,
	},
	## Plays for the rest of the fight once Overdrive is activated.
	"overdrive": {
		"stream": preload("res://audio/CraftPix.com/Music/WAV/Track race.wav"),
		"volume_db": -10.0,
	},
}

## Rockets, missiles, and the barrage that throws them.
const _MISSILES: PackedStringArray = [
	"Rocket", "Heavy Missile", "Missle Volley", "Salvo", "Slide & Fire",
]
## Close strikes that read as a fist or a ram.
const _MELEE: PackedStringArray = ["Piledriver", "Smash", "Strike"]
## Close strikes that read as a blade.
const _BLADES: PackedStringArray = ["Spike", "Cut", "Lance"]
## Loud short-range guns, separate from the standard sci-fi shot.
const _SHOTGUNS: PackedStringArray = ["Shotgun", "Charge"]

const _POOL_SIZE := 6
const _MUSIC_BUS := "Music"
const _EFFECTS_BUS := "SFX"
const _LEVELS_PATH := "user://audio.cfg"
## The letter tick is a short chirp played faster, so it chatters while text types.
const _TYPING_PITCH := 2.0
## Interface 3-3 is one chirp and then silence. Loop only the chirp.
const _TYPING_LOOP_SECONDS := 0.1

var _oneshots: Array[AudioStreamPlayer] = []
var _loop_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _typing_player: AudioStreamPlayer
var _loop_name := ""
var _music_name := ""
## Where each track left off, so a return continues instead of starting over.
var _music_at: Dictionary = {}
var _music_streams: Dictionary = {}
var _music_percent := 100.0
var _effects_percent := 100.0


func _ready() -> void:
	## Round banners pause the tree. Music and beds keep playing through that.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(_MUSIC_BUS)
	_ensure_bus(_EFFECTS_BUS)
	_loop_player = AudioStreamPlayer.new()
	_loop_player.bus = _EFFECTS_BUS
	add_child(_loop_player)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = _MUSIC_BUS
	add_child(_music_player)
	_typing_player = AudioStreamPlayer.new()
	_typing_player.bus = _EFFECTS_BUS
	add_child(_typing_player)
	for _index in _POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = _EFFECTS_BUS
		add_child(player)
		_oneshots.append(player)
	_load_levels()
	_apply_bus(_MUSIC_BUS, _music_percent)
	_apply_bus(_EFFECTS_BUS, _effects_percent)


func music_percent() -> float:
	return _music_percent


func effects_percent() -> float:
	return _effects_percent


func set_music_percent(percent: float) -> void:
	_music_percent = clampf(percent, 0.0, 100.0)
	_apply_bus(_MUSIC_BUS, _music_percent)
	_save_levels()


func set_effects_percent(percent: float) -> void:
	_effects_percent = clampf(percent, 0.0, 100.0)
	_apply_bus(_EFFECTS_BUS, _effects_percent)
	_save_levels()


## One-shot. A second play overlaps instead of cutting the first.
## volume_db is added on top of the clip's own volume.
func play(clip: String, volume_db: float = 0.0) -> void:
	var entry := _entry(clip)
	if entry.is_empty():
		return
	var player := _free_player()
	player.stream = entry["stream"]
	player.volume_db = float(entry["volume_db"]) + volume_db
	player.play()


## Bed under the fight. A new name replaces the one that is playing.
## volume_db is added on top of the clip's own volume.
func loop(clip: String, volume_db: float = 0.0) -> void:
	if clip == _loop_name and _loop_player.playing:
		return
	var entry := _entry(clip)
	if entry.is_empty():
		return
	_loop_player.stream = _looping_copy(entry["stream"])
	_loop_player.volume_db = float(entry["volume_db"]) + volume_db
	_loop_player.play()
	_loop_name = clip


func stop_loop() -> void:
	_loop_player.stop()
	_loop_name = ""


## Score under a screen. The same name keeps playing. A return picks up where it left off.
## volume_db is added on top of the clip's own volume.
func music(clip: String, volume_db: float = 0.0) -> void:
	if clip == _music_name and _music_player.playing:
		return
	var entry := _entry(clip)
	if entry.is_empty():
		return
	if _music_name != "" and _music_player.playing:
		_music_at[_music_name] = _music_player.get_playback_position()
	var stream: AudioStream = _music_streams.get(clip)
	if stream == null:
		stream = _looping_copy(entry["stream"])
		_music_streams[clip] = stream
	_music_player.stream = stream
	_music_player.volume_db = float(entry["volume_db"]) + volume_db
	_music_player.play(float(_music_at.get(clip, 0.0)))
	_music_name = clip


## Chatter under dialogue while letters are still appearing.
func play_typing() -> void:
	var entry := _entry("typing")
	if entry.is_empty():
		return
	_typing_player.stream = _looping_copy(entry["stream"], _TYPING_LOOP_SECONDS)
	_typing_player.pitch_scale = _TYPING_PITCH
	_typing_player.volume_db = float(entry["volume_db"])
	_typing_player.stream_paused = false
	_typing_player.play()


func stop_typing() -> void:
	_typing_player.stream_paused = false
	_typing_player.stop()


## Holds the letter tick while the line rests on a sentence break.
func set_typing_paused(paused: bool) -> void:
	if _typing_player == null:
		return
	_typing_player.stream_paused = paused


## Clip for a card the player or an enemy just played.
func play_card(card: CardData, volume_db: float = 0.0) -> void:
	var clip := id_for_card(card)
	if clip != "":
		play(clip, volume_db)


## Burst Fire, Snap Shot, Strafe, Shot, Volley, Suppress, Flak, Graze, and Dart use gunshot.
func id_for_card(card: CardData) -> String:
	if card == null:
		return ""
	if card.display_name == "Spark":
		return "upgrade"
	if card.is_dodge() or card.card_type == "Move":
		return "dodge"
	if card.is_guard() or card.barrier > 0:
		return "guard"
	var spoken := card.display_name
	if spoken in _MISSILES:
		return "missile"
	if spoken in _BLADES:
		return "blade"
	if spoken in _MELEE:
		return "melee"
	if spoken in _SHOTGUNS:
		return "shotgun"
	if card.card_type == "Attack":
		return "gunshot"
	return ""


## A forward-looping copy. Clips imported without loop points store the end at 0,
## and a forward loop then repeats the first sample and stays silent.
func _looping_copy(source: AudioStream, loop_seconds: float = -1.0) -> AudioStream:
	var stream := source.duplicate() as AudioStream
	var wav := stream as AudioStreamWAV
	if wav == null:
		return stream
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	var frames := maxi(int(round(wav.get_length() * wav.mix_rate)) - 1, 1)
	var end := frames
	if loop_seconds > 0.0:
		end = mini(maxi(int(loop_seconds * wav.mix_rate), 1), frames)
	if wav.loop_end <= wav.loop_begin or loop_seconds > 0.0:
		wav.loop_begin = 0
		wav.loop_end = end
	return wav


func _entry(clip: String) -> Dictionary:
	var entry: Variant = _CLIPS.get(clip)
	if entry is Dictionary:
		return entry
	push_warning("SoundBank has no clip named %s" % clip)
	return {}


func _free_player() -> AudioStreamPlayer:
	for player in _oneshots:
		if not player.playing:
			return player
	return _oneshots[0]


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


func _apply_bus(bus_name: String, percent: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var loudness := -80.0
	if percent > 0.0:
		loudness = linear_to_db(percent / 100.0)
	AudioServer.set_bus_volume_db(index, loudness)


func _load_levels() -> void:
	var config := ConfigFile.new()
	if config.load(_LEVELS_PATH) != OK:
		return
	_music_percent = clampf(float(config.get_value("audio", "music", 100.0)), 0.0, 100.0)
	_effects_percent = clampf(float(config.get_value("audio", "effects", 100.0)), 0.0, 100.0)


func _save_levels() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", _music_percent)
	config.set_value("audio", "effects", _effects_percent)
	config.save(_LEVELS_PATH)
