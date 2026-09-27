extends SceneTree
## 호가전쟁 밸런스 시뮬레이터 (Dart 원본과 같은 지표).
##   godot --headless --path godot --script res://tools/balance_sim.gd -- [판 수]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var games := int(args[0]) if args.size() > 0 else 100
	for company: Company in Company.roster():
		_report(company, games, false)
	_report(Company.roster()[0], games, true)
	quit()


func _report(company: Company, games: int, active: bool) -> void:
	var changes: Array[float] = []
	var ranges: Array[float] = []
	var vi := 0
	var limit_wins := 0
	var bull_wins := 0
	var player_wins := 0
	var skills := 0
	var enemy_skills := 0
	for seed_value in games:
		var faction := War.Faction.BULL if seed_value % 2 == 0 else War.Faction.BEAR
		var engine := BattleEngine.new(company, faction, seed_value)
		var high := engine.last_price
		var low := engine.last_price
		while not engine.is_over():
			engine.step()
			if active:
				if engine.tick == 3:
					engine.attack(0.5)
				if not engine.hand.is_empty():
					engine.use_skill(0)
				if not engine.incoming.is_empty():
					engine.place_wall(0.25)
			high = maxi(high, engine.last_price)
			low = mini(low, engine.last_price)
		var r := engine.result
		changes.append(r.price_change() * 100.0)
		ranges.append(float(high - low) / engine.base_price * 100.0)
		if r.winner == War.Faction.BULL:
			bull_wins += 1
		if r.victory():
			player_wins += 1
		if r.reason.contains("안착"):
			limit_wins += 1
		for item: BattleEngine.FeedItem in engine.feed:
			if item.title.begins_with("정적 VI"):
				vi += 1
			if item.title.contains("스킬 카드 획득"):
				skills += 1
			if item.kind == BattleEngine.FeedKind.WARNING:
				enemy_skills += 1
	changes.sort()
	ranges.sort()
	var abs_mean := 0.0
	for c in changes:
		abs_mean += absf(c)
	abs_mean /= games
	print("── %s (%s원) %s · %d판" % [company.name, Krx.format_number(company.base_price), "적극 플레이어" if active else "관망 플레이어", games])
	print("  종가 등락 |평균| %.1f%%  p5 %.1f / p50 %.1f / p95 %.1f" % [abs_mean, _pct(changes, 0.05), _pct(changes, 0.5), _pct(changes, 0.95)])
	print("  하루 변동폭 p50 %.1f%%  p95 %.1f%%" % [_pct(ranges, 0.5), _pct(ranges, 0.95)])
	print("  VI %.2f회/판  상·하한가 안착 %.1f%%  사자 승 %d%%" % [float(vi) / games, 100.0 * limit_wins / games, roundi(100.0 * bull_wins / games)])
	print("  스킬 획득 %.1f  적 스킬 %.1f /판  플레이어 승률 %d%%" % [float(skills) / games, float(enemy_skills) / games, roundi(100.0 * player_wins / games)])


func _pct(values: Array[float], q: float) -> float:
	return values[roundi(q * (values.size() - 1))]
