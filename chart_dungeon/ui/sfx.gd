class_name Sfx
extends Node
## 효과음. 파일 없이 코드로 만든다.
##   card    종이 카드를 내려놓는 소리
##   buy/sell 체결음 (매수는 높게, 매도는 낮게)
##   bell    장 시작·마감 종
##   coin    정산 숫자가 올라갈 때
##   win     목표 달성
##   alarm   마진콜

const RATE := 22050

var muted := false
var _players: Array[AudioStreamPlayer] = []
var _sounds := {}
var _last_ms := {}


func _ready() -> void:
	for i in 8:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_sounds["card"] = _flick()
	_sounds["click"] = _tone(2200.0, 0.006, 0.2)
	_sounds["buy"] = _tone(1480.0, 0.03, 0.22)
	_sounds["sell"] = _tone(990.0, 0.03, 0.22)
	_sounds["bell"] = _bell()
	_sounds["coin"] = _tone(2637.0, 0.025, 0.12)
	_sounds["win"] = _chord([523.25, 659.25, 783.99, 1046.5], 0.9)
	_sounds["lose"] = _chord([392.0, 466.16, 554.37], 0.8)
	_sounds["alarm"] = _alarm()
	_sounds["page"] = _flick(0.12)


func play(sound: String, volume_db := -8.0, min_gap_ms := 0) -> void:
	if muted or not _sounds.has(sound):
		return
	var now := Time.get_ticks_msec()
	if min_gap_ms > 0 and now - int(_last_ms.get(sound, -100000)) < min_gap_ms:
		return
	_last_ms[sound] = now
	for player in _players:
		if not player.playing:
			player.stream = _sounds[sound]
			player.volume_db = volume_db
			player.play()
			return


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


func _tone(freq: float, length: float, volume: float) -> AudioStreamWAV:
	var n := int(RATE * length)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / RATE
		var phase := fmod(t * freq, 1.0)
		samples[i] = (1.0 if phase < 0.5 else -1.0) * volume * (1.0 - float(i) / n)
	return _stream(samples)


func _flick(length := 0.07) -> AudioStreamWAV:
	var n := int(RATE * length)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var noise := RandomNumberGenerator.new()
	noise.seed = 11
	var last := 0.0
	for i in n:
		var k := float(i) / n
		# 높은 주파수만 남긴 잡음이 빠르게 줄어든다.
		var white := noise.randf_range(-1.0, 1.0)
		var high := white - last
		last = white
		samples[i] = high * 0.35 * pow(1.0 - k, 3.0)
	return _stream(samples)


func _bell() -> AudioStreamWAV:
	var n := int(RATE * 1.2)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 3.5)
		samples[i] = env * 0.3 * (sin(TAU * 880.0 * t) + 0.6 * sin(TAU * 1318.5 * t) + 0.3 * sin(TAU * 2637.0 * t)) / 1.9
	return _stream(samples)


func _chord(freqs: Array, length: float) -> AudioStreamWAV:
	var n := int(RATE * length)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / RATE
		var total := 0.0
		for k in freqs.size():
			# 아르페지오: 음이 조금씩 늦게 들어온다.
			var start := k * 0.06
			if t >= start:
				total += sin(TAU * float(freqs[k]) * t) * exp(-(t - start) * 4.0)
		samples[i] = total * 0.22 / freqs.size() * 2.0
	return _stream(samples)


func _alarm() -> AudioStreamWAV:
	var n := int(RATE * 0.6)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / RATE
		var freq := 1200.0 if int(t / 0.15) % 2 == 0 else 900.0
		samples[i] = (1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0) * 0.12
	return _stream(samples)
