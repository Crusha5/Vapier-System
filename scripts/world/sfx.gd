class_name Sfx
extends Node
## Prozedural erzeugte Soundeffekte und Ambient-Dröhnen (keine Audiodateien nötig).

const RATE := 22050

var streams := {}
var players: Array[AudioStreamPlayer] = []
var ambient: AudioStreamPlayer
var _next := 0
var _last := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		players.append(p)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	streams.swing = _make(0.14, func(t, d): return _noise(rng) * _env(t, d, 0.01) * 0.5, 0.35)
	streams.hit = _make(0.16, func(t, d): return (sin(TAU * (90.0 - t * 300.0) * t) * 0.9 + _noise(rng) * 0.6 * exp(-t * 40.0)) * _env(t, d, 0.002), 0.0)
	streams.dash = _make(0.2, func(t, d): return _noise(rng) * sin(PI * t / d) * 0.45, 0.6)
	streams.hurt = _make(0.22, func(t, d): return (sin(TAU * (160.0 - t * 400.0) * t) * 0.8 + _noise(rng) * 0.3) * _env(t, d, 0.004), 0.1)
	streams.scythe = _make(0.4, func(t, d): return (_noise(rng) * 0.4 + sin(TAU * (220.0 + 200.0 * t) * t) * 0.3) * sin(PI * t / d), 0.5)
	streams.lance = _make(0.3, func(t, d): return (sin(TAU * (900.0 - t * 2200.0) * t) * 0.4 + _noise(rng) * 0.2) * _env(t, d, 0.005), 0.2)
	streams.drink = _make(0.3, func(t, d): return sin(TAU * (120.0 + 40.0 * sin(t * 40.0)) * t) * 0.6 * sin(PI * t / d), 0.0)
	streams.level = _make(0.9, func(t, d): return _chime(t, [523.25, 659.25, 783.99, 1046.5], 0.11) * 0.45, 0.0)
	streams.quest = _make(0.55, func(t, d): return _chime(t, [659.25, 987.77], 0.13) * 0.4, 0.0)
	streams.warn = _make(0.45, func(t, d): return sign(sin(TAU * 220.0 * t)) * 0.18 * (1.0 if fmod(t, 0.22) < 0.13 else 0.0), 0.0)
	streams.tick = _make(0.03, func(t, d): return sin(TAU * 1800.0 * t) * _env(t, d, 0.001) * 0.3, 0.0)
	streams.step = _make(0.06, func(t, d): return _noise(rng) * _env(t, d, 0.001) * 0.18, 0.7)
	streams.perfect = _make(0.6, func(t, d): return (_noise(rng) * 0.2 * (1.0 - t / d) + sin(TAU * 1320.0 * t) * 0.25 * exp(-t * 6.0) + sin(TAU * 1760.0 * t) * 0.15 * exp(-t * 4.0)), 0.3)
	streams.awaken = _make(2.4, func(t, d): return (sin(TAU * 45.0 * t) * exp(-t * 1.5) * 0.9 + sin(TAU * (110.0 + t * 160.0) * t) * 0.25 * (t / d) + _noise(rng) * 0.15 * exp(-t * 3.0)), 0.0)
	streams.boom = _make(0.6, func(t, d): return (sin(TAU * (60.0 - t * 50.0) * t) + _noise(rng) * 0.5 * exp(-t * 10.0)) * exp(-t * 5.0) * 0.8, 0.0)
	streams.swing_enemy = streams.swing
	ambient = AudioStreamPlayer.new()
	ambient.stream = _drone()
	ambient.volume_db = -16.0
	add_child(ambient)

func start_ambient() -> void:
	if not ambient.playing:
		ambient.play()

func _noise(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(-1.0, 1.0)

func _env(t: float, d: float, attack: float) -> float:
	if t < attack:
		return t / attack
	return pow(1.0 - (t - attack) / max(0.0001, d - attack), 2.0)

func _chime(t: float, notes: Array, step: float) -> float:
	var v := 0.0
	for i in notes.size():
		var st := t - i * step
		if st > 0.0:
			v += sin(TAU * float(notes[i]) * st) * exp(-st * 4.0) + sin(TAU * float(notes[i]) * 2.0 * st) * 0.2 * exp(-st * 7.0)
	return v / sqrt(notes.size())

## smooth: einfacher Tiefpass (0 = aus, 0.9 = sehr dumpf)
func _make(dur: float, f: Callable, smooth: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var v: float = f.call(t, dur)
		prev = lerp(v, prev, smooth)
		var s := int(clamp(prev, -1.0, 1.0) * 30000.0)
		data.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

func _drone() -> AudioStreamWAV:
	var dur := 8.0
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var lfo := 0.5 + 0.5 * sin(TAU * t / dur)
		lp = lerp(rng.randf_range(-1.0, 1.0), lp, 0.985)
		var v := sin(TAU * 55.0 * t) * 0.35 + sin(TAU * 82.5 * t) * 0.18 * lfo + sin(TAU * 110.0 * t + sin(TAU * 0.25 * t)) * 0.08 + lp * 2.0
		data.encode_s16(i * 2, int(clamp(v, -1.0, 1.0) * 20000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w

func play(name: String, vol_db := 0.0, pitch_var := 0.08) -> void:
	if not streams.has(name):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(name, 0)) < 35:
		return
	_last[name] = now
	var p := players[_next]
	_next = (_next + 1) % players.size()
	p.stream = streams[name]
	p.volume_db = vol_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()
