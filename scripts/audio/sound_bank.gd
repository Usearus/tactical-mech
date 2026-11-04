extends Node

## Short names for the clips that match moments already in the game.
## Call SoundBank.play("gunshot") or SoundBank.loop("rain") from the moment itself.

const _CLIPS := {
	"rain": preload("res://audio/Free Sounds Pack/Ambient Rain Moderate Loop 1.wav"),
	"wind": preload("res://audio/Free Sounds Pack/Ambient Wind Loop 1.wav"),
	"gunshot": preload("res://audio/Free Sounds Pack/Sci-Fi Gun 1-1.wav"),
	"shotgun": preload("res://audio/Free Sounds Pack/Gunshot 1-1.wav"),
	"gunshot_heavy": preload("res://audio/Free Sounds Pack/Gunshot 7-1.wav"),
	"missile": preload("res://audio/Free Sounds Pack/Fire Whoosh 2-15.wav"),
	"explosion": preload("res://audio/Free Sounds Pack/Explosion Medium 2-1.wav"),
	"explosion_large": preload("res://audio/Free Sounds Pack/Explosion Large 1-1.wav"),
	"hit": preload("res://audio/Free Sounds Pack/Hit Generic 5-1.wav"),
	"melee": preload("res://audio/Free Sounds Pack/Punch 2-1.wav"),
	"blade": preload("res://audio/Free Sounds Pack/Stab 4-1.wav"),
	"guard": preload("res://audio/Free Sounds Pack/Shield Metal Impact 1-3.wav"),
	"dodge": preload("res://audio/Free Sounds Pack/Whoosh 4-1.wav"),
	"step": preload("res://audio/Free Sounds Pack/Rock Impact 11.wav"),
	"draw": preload("res://audio/Free Sounds Pack/Draw Weapon Metal 1-1.wav"),
	"ui": preload("res://audio/Free Sounds Pack/Sci-Fi Interface 8-1.wav"),
	"upgrade": preload("res://audio/Free Sounds Pack/Special Collectible 9-1.wav"),
	"typing": preload("res://audio/Free Sounds Pack/Interface 3-3.wav"),
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
const _LOOP_VOLUME_DB := -14.0
## The letter tick is a short chirp played faster, so it chatters while text types.
## -10 dB is half the amplitude of the previous -4 dB level.
const _TYPING_PITCH := 2.0
const _TYPING_VOLUME_DB := -10.0
## Interface 3-3 is one chirp and then silence. Loop only the chirp.
const _TYPING_LOOP_SECONDS := 0.1

var _oneshots: Array[AudioStreamPlayer] = []
var _loop_player: AudioStreamPlayer
var _typing_player: AudioStreamPlayer
var _loop_name := ""


func _ready() -> void:
	_loop_player = AudioStreamPlayer.new()
	add_child(_loop_player)
	_typing_player = AudioStreamPlayer.new()
	add_child(_typing_player)
	for _index in _POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_oneshots.append(player)


## One-shot. A second play overlaps instead of cutting the first.
func play(clip: String, volume_db: float = 0.0) -> void:
	var stream := _stream(clip)
	if stream == null:
		return
	var player := _free_player()
	player.stream = stream
	player.volume_db = volume_db
	player.play()


## Bed under the fight. A new name replaces the one that is playing.
func loop(clip: String, volume_db: float = _LOOP_VOLUME_DB) -> void:
	if clip == _loop_name and _loop_player.playing:
		return
	var source := _stream(clip)
	if source == null:
		return
	_loop_player.stream = _looping_copy(source)
	_loop_player.volume_db = volume_db
	_loop_player.play()
	_loop_name = clip


func stop_loop() -> void:
	_loop_player.stop()
	_loop_name = ""


## Chatter under dialogue while letters are still appearing.
func play_typing() -> void:
	var source := _stream("typing")
	if source == null:
		return
	_typing_player.stream = _looping_copy(source, _TYPING_LOOP_SECONDS)
	_typing_player.pitch_scale = _TYPING_PITCH
	_typing_player.volume_db = _TYPING_VOLUME_DB
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


func _stream(clip: String) -> AudioStream:
	var stream: AudioStream = _CLIPS.get(clip)
	if stream == null:
		push_warning("SoundBank has no clip named %s" % clip)
	return stream


func _free_player() -> AudioStreamPlayer:
	for player in _oneshots:
		if not player.playing:
			return player
	return _oneshots[0]
