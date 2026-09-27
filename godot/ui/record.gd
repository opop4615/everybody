class_name Record
## 전적. user://record.cfg 에 남는다.

## 테스트는 다른 파일을 쓴다.
static var path := "user://record.cfg"


static func load_record() -> Dictionary:
	var cfg := ConfigFile.new()
	var data := {"plays": 0, "wins": 0, "losses": 0, "draws": 0, "best": 0.0, "history": []}
	if cfg.load(path) == OK:
		for key in data:
			data[key] = cfg.get_value("record", key, data[key])
	return data


static func add(result: BattleEngine.BattleResult, company: String) -> void:
	var data := load_record()
	data.plays += 1
	if result.winner == War.NEUTRAL:
		data.draws += 1
	elif result.victory():
		data.wins += 1
	else:
		data.losses += 1
	if data.plays == 1 or result.return_rate() > data.best:
		data.best = result.return_rate()
	var history: Array = data.history
	history.push_front({
		"company": company, "side": War.label(result.player_faction),
		"outcome": "무" if result.winner == War.NEUTRAL else ("승" if result.victory() else "패"),
		"return": result.return_rate(), "grade": result.grade(),
	})
	data.history = history.slice(0, 5)
	var cfg := ConfigFile.new()
	for key in data:
		cfg.set_value("record", key, data[key])
	cfg.save(path)
