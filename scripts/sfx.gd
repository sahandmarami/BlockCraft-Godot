extends Node
## Autoload "Sfx" — procedural sound effects (16-bit mono WAV, generated at boot).

var streams := {}
var pool: Array = []
var volume := 0.8  # linear 0..1


func _ready() -> void:
	streams["break"] = _gen_break()
	streams["place"] = _gen_place()
	streams["hurt"] = _gen_sweep(300.0, 110.0, 0.3, 0.85)
	streams["mob_hurt"] = _gen_sweep(190.0, 80.0, 0.22, 0.7)
	streams["click"] = _gen_tone(880.0, 0.05, 0.4)
	streams["jump"] = _gen_tone(320.0, 0.09, 0.25)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		pool.append(p)


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.001)


func play(name: String, pitch := 1.0, vol_db := 0.0) -> void:
	if not streams.has(name) or volume <= 0.001:
		return
	for p in pool:
		if not p.playing:
			p.stream = streams[name]
			p.pitch_scale = pitch
			p.volume_db = vol_db
			p.play()
			return


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		bytes[i * 2] = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	w.stereo = false
	w.data = bytes
	return w


func _gen_tone(freq: float, dur: float, amp: float) -> AudioStreamWAV:
	var n := int(22050.0 * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / 22050.0
		s[i] = sin(TAU * freq * t) * exp(-t * 55.0) * amp
	return _wav(s)


func _gen_sweep(f0: float, f1: float, dur: float, amp: float) -> AudioStreamWAV:
	var n := int(22050.0 * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		ph += TAU * f / 22050.0
		s[i] = sin(ph) * exp(-t * 9.0) * amp
	return _wav(s)


func _gen_break() -> AudioStreamWAV:
	var dur := 0.16
	var n := int(22050.0 * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp := 0.0
	for i in n:
		var t := float(i) / 22050.0
		var white := rng.randf_range(-1.0, 1.0)
		lp = lp * 0.6 + white * 0.4  # cheap low-pass
		s[i] = (lp * exp(-t * 26.0) * 0.9 + sin(TAU * 85.0 * t) * exp(-t * 18.0) * 0.45)
	return _wav(s)


func _gen_place() -> AudioStreamWAV:
	var dur := 0.12
	var n := int(22050.0 * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in n:
		var t := float(i) / 22050.0
		s[i] = sin(TAU * 165.0 * t) * exp(-t * 30.0) * 0.7 + rng.randf_range(-1.0, 1.0) * exp(-t * 90.0) * 0.25
	return _wav(s)
