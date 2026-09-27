class_name Sfx
extends Node
## 효과음. 파일 없이 코드로 만든다.
##   체결: HTS 체결음 같은 짧은 틱 (매수는 높게, 매도는 낮게)
##   종: 장 시작과 끝
##   스킬: 한쪽으로 쓸려 가는 소리 (사자는 올라가고 팔자는 내려간다)
##   VI: 두 음 경보

const RATE := 22050

var muted := false
var _players: Array[AudioStreamPlayer] = []
var _sounds := {}
var _last_tick_ms := 0


func _ready() -> void:
	for i in 6:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_sounds["buy"] = _tone(1480.0, 0.018, 0.25, "square")
	_sounds["sell"] = _tone(990.0, 0.018, 0.25, "square")
	_sounds["click"] = _tone(2200.0, 0.006, 0.2, "square")
	_sounds["bell"] = _bell()
	_sounds["skill_up"] = _sweep(220.0, 880.0, 0.35)
	_sounds["skill_down"] = _sweep(880.0, 180.0, 0.35)
	_sounds["vi"] = _alarm()
	_sounds["reveal"] = _chord()


func play(sound: String, volume_db := -8.0) -> void:
	if muted or not _sounds.has(sound):
		return
	for player in _players:
		if not player.playing:
			player.stream = _sounds[sound]
			player.volume_db = volume_db
			player.play()
			return


## 체결음은 너무 잦으면 시끄러우니 70ms에 한 번만.
func tick(buy: bool) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_tick_ms < 70:
		return
	_last_tick_ms = now
	play("buy" if buy else "sell", -16.0)


func _stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream


func _tone(freq: float, length: float, volume: float, wave: String) -> AudioStreamWAV:
	var n := int(RATE * length)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / RATE
		var phase := fmod(t * freq, 1.0)
		var v := (1.0 if phase < 0.5 else -1.0) if wave == "square" else sin(TAU * phase)
		samples[i] = v * volume * (1.0 - float(i) / n)
	return _stream(samples)


func _bell() -> AudioStreamWAV:
	var n := int(RATE * 1.4)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 3.2)
		samples[i] = env * 0.35 * (sin(TAU * 880.0 * t) + 0.6 * sin(TAU * 1318.5 * t) + 0.3 * sin(TAU * 2637.0 * t)) / 1.9
	return _stream(samples)


func _sweep(from: float, to: float, length: float) -> AudioStreamWAV:
	var n := int(RATE * length)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	var noise := RandomNumberGenerator.new()
	noise.seed = 7
	for i in n:
		var k := float(i) / n
		phase += lerpf(from, to, k) / RATE
		var square := 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		samples[i] = (square * 0.18 + noise.randf_range(-1, 1) * 0.12) * (1.0 - k)
	return _stream(samples)


func _alarm() -> AudioStreamWAV:
	var n := int(RATE * 0.5)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / RATE
		var freq := 1200.0 if int(t / 0.125) % 2 == 0 else 900.0
		samples[i] = (1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0) * 0.15
	return _stream(samples)


func _chord() -> AudioStreamWAV:
	var n := int(RATE * 0.6)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 5.0)
		samples[i] = env * 0.25 * (sin(TAU * 523.25 * t) + sin(TAU * 659.25 * t) + sin(TAU * 783.99 * t)) / 3.0
	return _stream(samples)
