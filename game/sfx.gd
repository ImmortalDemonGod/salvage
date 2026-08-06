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
	SfxEvents.Kind.PAYOFF:   [880.0, 0.55, 0.40],
	SfxEvents.Kind.READ:     [1180.0, 0.10, 0.16],
}

# One player meant a batch of events overwrote itself and only the LAST
# thing that happened in a turn was audible. Round-robin so a turn sounds
# like the turn it was.
var _voices: Array = []
var _next := 0
var _muted := false
var fired: Array = []      # measured, for verification

# --- the score ------------------------------------------------------------
# Ported in shape from the last prototype, which had an adaptive procedural
# score and was the single cheapest source of feel in either project. Four
# moods keyed off what beat you are on, and the deeper you go the tighter
# and lower it gets. No assets: Marc owns the real score, this is the brief.
const MOODS := {
	"scene":  {"notes": [196.00, 233.08, 261.63, 311.13], "period": 2.10, "gain": 0.13},
	"puzzle": {"notes": [174.61, 207.65, 233.08, 261.63], "period": 1.70, "gain": 0.12},
	"combat": {"notes": [146.83, 174.61, 196.00, 233.08], "period": 1.30, "gain": 0.15},
	"deep":   {"notes": [110.00, 130.81, 146.83, 174.61], "period": 0.95, "gain": 0.17},
}
var _music: AudioStreamPlayer
var _mood := "scene"
var _step := 0
var _next_note := 0.0
var _depth := 0.0

func _ready() -> void:
	for i in range(4):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	set_process(true)

# the scene tells the score where it is; the score does not guess
func set_mood(mood: String, depth: float) -> void:
	if mood != _mood:
		_mood = mood
		_step = 0
		_next_note = 0.0
	_depth = clampf(depth, 0.0, 1.0)

func _process(dt: float) -> void:
	if _muted or _music == null:
		return
	_next_note -= dt
	if _next_note > 0.0:
		return
	var m: Dictionary = MOODS.get(_mood, MOODS["scene"])
	var notes: Array = m.notes
	# a pull toward the low end as the dive gets deeper
	var hz: float = float(notes[_step % notes.size()]) * (1.0 - 0.16 * _depth)
	_step += 1
	# the pulse tightens with depth: the same phrase, more urgent
	_next_note = float(m.period) * (1.0 - 0.28 * _depth)
	_music.stream = _tone(hz, float(m.period) * 0.92, float(m.gain), true)
	_music.play()

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
	if v.is_empty() or _voices.is_empty():
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
	var p: AudioStreamPlayer = _voices[_next % _voices.size()]
	_next += 1
	p.stream = stream
	p.play()

# a soft pad note: slow attack, long tail, so it sits under the effects
func _tone(hz: float, secs: float, gain: float, pad: bool) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * secs)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / float(rate)
		var f := float(i) / float(n)
		var env: float = 1.0 - f
		if pad:
			env = min(1.0, f * 7.0) * (1.0 - f) * (1.0 - f)
		var sample: float = sin(TAU * hz * t) * gain * env
		if pad:
			sample += sin(TAU * hz * 2.0 * t) * gain * 0.22 * env
		var q := int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, q)
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = rate
	st.data = data
	return st
