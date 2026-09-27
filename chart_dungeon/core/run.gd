class_name Run
extends RefCounted
## 한 판 (시대 하나). 계좌, 덱, 데스크 팀원, 지도 위치, 투자 노트를 들고 다닌다.

const MAX_MEMBERS := 4
const DEPOSIT_COST := 50
const DEPOSIT_AMOUNT := 250.0
const UPGRADE_COST := 60

## 데스크 팀원.
const MEMBERS := {
	"quant": {"name": "퀀트", "text": "매일 전망표에 방향 신호를 하나 적는다 (맞을 확률 62%).", "cost": 0, "sprite": "analyst_bull"},
	"risk": {"name": "리스크 매니저", "text": "하루 손실이 계좌의 5%를 넘으면 그 자리에서 정리한다.", "cost": 110, "sprite": "inst_bull"},
	"crowd": {"name": "개미 커뮤니티", "text": "개미들이 몰리는 쪽을 알려 준다. 역지표라 반대로 읽는다 (58%).", "cost": 70, "sprite": "ant_bull"},
	"macro": {"name": "매크로 이코노미스트", "text": "발표일 거래와 보스에서 신호가 5%p 정확해지고, 뉴스 선택의 결과를 미리 읽는다.", "cost": 120, "sprite": "analyst_bear"},
	"broker": {"name": "브로커", "text": "수수료가 절반이 된다.", "cost": 60, "sprite": "lp_gold"},
	"foreign_desk": {"name": "외국계 데스크", "text": "달러 선물 거래에서 신호를 하나 더 준다 (60%).", "cost": 90, "sprite": "airship_bull"},
}

var run_seed: int
var account := Era2020.START_ACCOUNT
var margin_line := Era2020.FLOOR
## 성과급: 데스크에서 쓰는 돈.
var bonus := 60
var deck: Array[Card] = []
var members: Array[String] = ["quant"]
var notes: Notes
var acts: Array[Dictionary]
var act_index := 0
var column := 0
var lane := 1
var visited: Array[String] = []
var flags := {}
var history: Array[Dictionary] = []
var stats := {"trades": 0, "won": 0, "failed": 0, "patterns": 0, "best": 0.0}
var removal_cost := 75
var over := false
var victory := false
var act_start_account := 0.0
var act_start_date := ""
## 지금 데스크에 걸린 물건 (칸마다 새로 뽑는다).
var shop := {}
var rng := RandomNumberGenerator.new()


func _init(p_seed := 0, p_notes: Notes = null) -> void:
	run_seed = p_seed if p_seed != 0 else randi()
	rng.seed = run_seed
	notes = p_notes if p_notes != null else Notes.new()
	deck = CardDB.starter_deck()
	acts = Era2020.acts()
	act_start_account = account
	act_start_date = act()["columns"][0][0]["date"]
	visited.append(act()["columns"][0][0]["id"])


func act() -> Dictionary:
	return acts[act_index]


func columns() -> Array:
	return act()["columns"]


func has_member(id: String) -> bool:
	return members.has(id)


func record(date: String) -> void:
	history.append({"date": date, "account": account, "act": act_index})


## 다음에 갈 수 있는 칸들.
func available() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if column + 1 >= columns().size():
		return list
	for node: Dictionary in columns()[column + 1]:
		if absi(int(node["lane"]) - lane) <= 1 or column == 0:
			list.append(node)
	return list


func is_available(node: Dictionary) -> bool:
	for item in available():
		if item["id"] == node["id"]:
			return true
	return false


## 칸으로 옮긴다. 들어간 칸의 종류를 돌려준다.
func enter(node: Dictionary) -> String:
	column += 1
	lane = int(node["lane"])
	visited.append(node["id"])
	if node["kind"] == "desk":
		_stock_shop()
	return node["kind"]


func start_trade(node: Dictionary) -> Trade:
	var trade := Trade.new(self, node)
	trade.start()
	return trade


## 거래가 끝났을 때. 보상 정보를 돌려준다: {won, bonus, cards, learned}
func finish_trade(trade: Trade) -> Dictionary:
	stats["trades"] += 1
	var won := trade.state == Trade.State.WON
	var result := {"won": won, "bonus": 0, "cards": [], "learned": [], "pnl": trade.trade_pnl()}
	stats["best"] = maxf(float(stats["best"]), trade.trade_pnl())
	notes.learn("settlement")
	notes.learn("long" if trade.position.qty >= 0 else "short")
	for id in trade.unknown_patterns:
		if notes.learn(id):
			result["learned"].append(id)
	if trade.state == Trade.State.BUSTED:
		over = true
		return result
	if won:
		stats["won"] += 1
		var base := 60 if trade.kind == "boss" else (35 if trade.kind == "elite" else 20)
		var extra := clampi(int((trade.trade_pnl() - trade.target) / 5.0), 0, 40)
		result["bonus"] = base + extra
		bonus += result["bonus"]
		result["cards"] = reward_cards(3, trade.kind != "trade")
	else:
		stats["failed"] += 1
		var habit := "h_average" if rng.randf() < 0.5 else "h_fomo"
		deck.append(Card.new(habit))
		result["habit"] = habit
	if trade.kind == "boss":
		_finish_act()
	return result


func _finish_act() -> void:
	if act_index + 1 >= acts.size():
		victory = true
		over = true


## 막이 끝난 뒤 다음 막으로.
func next_act() -> void:
	if act_index + 1 >= acts.size():
		return
	act_index += 1
	column = 0
	lane = 1
	act_start_account = account
	act_start_date = act()["columns"][0][0]["date"]
	visited.append(act()["columns"][0][0]["id"])


func at_boss_done() -> bool:
	return column >= columns().size() - 1


func reward_cards(count: int, better: bool) -> Array[Card]:
	var picks: Array[Card] = []
	var pool: Array = CardDB.REWARD_POOL.duplicate()
	while picks.size() < count and not pool.is_empty():
		var roll := rng.randf()
		var want := 0
		if roll < (0.30 if better else 0.12):
			want = 2
		elif roll < (0.75 if better else 0.5):
			want = 1
		var choices := pool.filter(func(id: String) -> bool: return CardDB.DEFS[id].get("rarity", 0) == want)
		if choices.is_empty():
			choices = pool
		var id: String = choices[rng.randi_range(0, choices.size() - 1)]
		pool.erase(id)
		picks.append(Card.new(id, better and rng.randf() < 0.25))
	return picks


func take_card(card: Card) -> void:
	deck.append(card)


# ── 뉴스 ──────────────────────────────────────────────────────────

func news(id: String) -> Dictionary:
	return Era2020.NEWS[id]


func open_news(id: String) -> void:
	for note: String in news(id).get("notes", []):
		notes.learn(note)


func choice_locked(choice: Dictionary) -> bool:
	if not choice.has("need"):
		return false
	var need: Array = choice["need"]
	return notes.level(need[0]) < int(need[1])


## 선택지 효과를 적용하고 한 줄 결과를 돌려준다.
func apply_choice(choice: Dictionary) -> String:
	var lines: Array[String] = []
	for effect: String in String(choice["effect"]).split(","):
		lines.append(_apply_effect(effect.strip_edges()))
	return " · ".join(lines.filter(func(line: String) -> bool: return not line.is_empty()))


func _apply_effect(effect: String) -> String:
	var parts := effect.split(":")
	var key := parts[0]
	var arg := parts[1] if parts.size() > 1 else ""
	match key:
		"alert":
			flags["alert"] = 1
			return "다음 거래 첫날 주문 한도 +1"
		"bonus":
			bonus += int(arg)
			return "성과급 +%s" % arg
		"study":
			notes.study(arg)
			return "투자 노트 · %s %d단계" % [NoteDB.name_of(arg), notes.level(arg)]
		"card", "card+":
			var card := Card.new(arg, key == "card+")
			deck.append(card)
			return "%s 카드를 얻었다" % card.name()
		"habit":
			var habit := Card.new(arg)
			deck.append(habit)
			return "덱에 %s이 들어왔다" % habit.name()
		"cleanse":
			if remove_habit():
				return "습관 카드 한 장을 지웠다"
			bonus += 20
			return "지울 습관이 없어 성과급 +20"
		"upgrade":
			var card := upgrade_random()
			return "%s 카드를 강화했다" % card.name() if card else ""
		"insight":
			flags["insight_" + arg] = float(flags.get("insight_" + arg, 0.0)) + (0.1 if arg == "a1_boss" else 0.08)
			return "보스전 신호 정확도가 오른다"
	return ""


func habits() -> Array[Card]:
	var list: Array[Card] = []
	for card in deck:
		if card.is_habit():
			list.append(card)
	return list


func remove_habit() -> bool:
	var list := habits()
	if list.is_empty():
		return false
	deck.erase(list[0])
	return true


func upgrade_random() -> Card:
	var list: Array[Card] = []
	for card in deck:
		if card.can_upgrade():
			list.append(card)
	if list.is_empty():
		return null
	var card: Card = list[rng.randi_range(0, list.size() - 1)]
	card.upgraded = true
	return card


# ── 데스크 (상점) ─────────────────────────────────────────────────

func _stock_shop() -> void:
	var cards: Array = []
	for card in reward_cards(4, false):
		cards.append({"card": card, "price": [45, 75, 120][card.rarity()] + (15 if card.upgraded else 0), "sold": false})
	var hire := ""
	var candidates: Array = MEMBERS.keys().filter(func(id: String) -> bool: return not members.has(id))
	if not candidates.is_empty() and members.size() < MAX_MEMBERS:
		hire = candidates[rng.randi_range(0, candidates.size() - 1)]
	shop = {"cards": cards, "hire": hire, "hired": false}


func buy_card(index: int) -> bool:
	var item: Dictionary = shop["cards"][index]
	if item["sold"] or bonus < item["price"]:
		return false
	bonus -= item["price"]
	item["sold"] = true
	deck.append(item["card"])
	return true


func hire(id: String) -> bool:
	var cost: int = MEMBERS[id]["cost"]
	if members.has(id) or members.size() >= MAX_MEMBERS or bonus < cost:
		return false
	bonus -= cost
	members.append(id)
	shop["hired"] = true
	return true


func remove_card(card: Card) -> bool:
	if bonus < removal_cost or not deck.has(card):
		return false
	bonus -= removal_cost
	removal_cost += 25
	deck.erase(card)
	return true


func upgrade_card(card: Card, paid := true) -> bool:
	if not card.can_upgrade():
		return false
	if paid:
		if bonus < UPGRADE_COST:
			return false
		bonus -= UPGRADE_COST
	card.upgraded = true
	return true


func deposit() -> bool:
	if bonus < DEPOSIT_COST:
		return false
	bonus -= DEPOSIT_COST
	account += DEPOSIT_AMOUNT
	return true


# ── 퇴근 (쉬는 칸) ────────────────────────────────────────────────

## 공부: 아는 항목 중 가장 낮은 단계 하나를 올린다.
func study_something() -> String:
	var best := ""
	var best_level := 9
	for id: String in NoteDB.ENTRIES:
		var level := notes.level(id)
		if level >= 1 and level < notes._cap(id) and level < best_level:
			best = id
			best_level = level
	if best.is_empty():
		return ""
	notes.study(best)
	return best
