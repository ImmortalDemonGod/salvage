# The audible side. Procedural tones only: no assets, nothing to license,
# and every voice is a couple of numbers a composer can throw away. Marc and
# Glass_Goat own the real sound; this exists so the EVENTS are wired and
# provable, not because it is music.
extends Node

const SfxEvents := preload("res://sim/sfx_events.gd")

# event -> [frequency, seconds, waveform-ish gain]
const VOICE := {
	SfxEvents.Kind.HIT:      [420.0, 0.07, 0.30],
	SfxEvents.Kind.BREAK:    [180.0, 0.30, 0.45],
	SfxEvents.Kind.SHUTDOWN: [900.0, 0.16, 0.22],
	SfxEvents.Kind.TAKE:     [140.0, 0.12, 0.35],
	SfxEvents.Kind.DOWN:     [90.0,  0.45, 0.40],
	SfxEvents.Kind.WIN:      [660.0, 0.50, 0.35],
	SfxEvents.Kind.LOSE:     [70.0,  0.70, 0.40],
	SfxEvents.Kind.MOVE:     [300.0, 0.05, 0.14],
	SfxEvents.Kind.REFUSE:   [200.0, 0.06, 0.18],
	SfxEvents.Kind.VALVE:    [520.0, 0.09, 0.22],
	SfxEvents.Kind.LOCK:     [780.0, 0.40, 0.32],
	SfxEvents.Kind.CUT:      [110.0, 0.22, 0.38],
}

var _player: AudioStreamPlayer
var _muted := false
var fired: Array = []      # measured, for verification

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)

func mute(on: bool) -> void:
	_muted = on

# Drain new lines from a sim log and voice whatever they classify as.
func drain(lines: Array, from: int) -> int:
	for i in range(from, lines.size()):
		var k: int = SfxEvents.classify(String(lines[i]))
		if k == SfxEvents.Kind.NONE:
			continue
		fired.append(k)
		if not _muted:
			_play(k)
	return lines.size()

func _play(k: int) -> void:
	var v: Array = VOICE.get(k, [])
	if v.is_empty() or _player == null:
		return
	var hz: float = float(v[0])
	var secs: float = float(v[1])
	var gain: float = float(v[2])
	var rate := 22050
	var n := int(rate * secs)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / float(rate)
		var env: float = 1.0 - (float(i) / float(n))
		var sample: float = sin(TAU * hz * t) * gain * env * env
		var q := int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, q)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	_player.stream = stream
	_player.play()
