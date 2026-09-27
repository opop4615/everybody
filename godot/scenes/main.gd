extends Control
## 루트: 관심종목(로비)과 전투 화면을 오간다.

var sfx: Sfx
var _screen: Control


func _ready() -> void:
	theme = Hts.make_theme()
	sfx = Sfx.new()
	add_child(sfx)
	show_lobby()


func show_lobby(company: Company = null) -> Lobby:
	var lobby := Lobby.new(company)
	lobby.sfx = sfx
	lobby.join_requested.connect(func(c: Company, f: int) -> void: start_battle(c, f))
	_swap(lobby)
	return lobby


func start_battle(company: Company, faction: int, seed_value := -1) -> BattleScreen:
	var battle := BattleScreen.new(company, faction, seed_value, sfx)
	battle.exit_requested.connect(func() -> void: show_lobby(company))
	battle.rematch_requested.connect(func() -> void: start_battle(company, faction))
	_swap(battle)
	return battle


func current_screen() -> Control:
	return _screen


func _swap(screen: Control) -> void:
	if _screen != null:
		_screen.queue_free()
	_screen = screen
	add_child(screen)
