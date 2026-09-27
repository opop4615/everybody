class_name CardDB
extends RefCounted
## 카드 정의. 수치는 거래 상품의 예상 변동폭(atr)과 증거금에 맞춰 계산한다.

const TYPE_LABEL := {
	"long": "롱 진입",
	"short": "숏 진입",
	"entry": "진입",
	"order": "주문 관리",
	"hedge": "헤지·옵션",
	"info": "분석",
	"pattern": "패턴 스킬",
	"habit": "습관",
}

const RARITY_LABEL := ["일반", "고급", "희귀"]

const DEFS := {
	"long": {"name": "롱 진입", "type": "long", "cost": 1, "rarity": 0, "budget": 250.0, "budget_up": 375.0, "note": "long"},
	"short": {"name": "숏 진입", "type": "short", "cost": 1, "rarity": 0, "budget": 250.0, "budget_up": 375.0, "note": "short"},
	"stop": {"name": "손절 주문", "type": "order", "cost": 0, "rarity": 0, "dist": 0.6, "draw_up": 1, "note": "stop"},
	"take": {"name": "지정가 익절", "type": "order", "cost": 0, "rarity": 0, "dist": 0.9, "draw_up": 1, "note": "limit"},
	"close": {"name": "청산", "type": "order", "cost": 1, "cost_up": 0, "rarity": 0, "note": "close"},
	"wait": {"name": "관망", "type": "info", "cost": 0, "rarity": 0, "draw": 2, "draw_up": 3, "note": "wait"},
	"moc": {"name": "종가 청산", "type": "order", "cost": 0, "rarity": 1, "draw_up": 1, "note": "close"},
	"half": {"name": "분할 청산", "type": "order", "cost": 0, "rarity": 0, "draw_up": 1, "note": "close"},
	"pyramid": {"name": "피라미딩", "type": "entry", "cost": 1, "rarity": 1, "budget": 250.0, "budget_up": 375.0, "note": "pyramid"},
	"contra": {"name": "역추세 진입", "type": "entry", "cost": 1, "rarity": 1, "budget": 300.0, "budget_up": 400.0, "dist": 0.5, "note": "contrarian"},
	"trail": {"name": "트레일링 스톱", "type": "order", "cost": 1, "cost_up": 0, "rarity": 1, "dist": 0.7, "note": "trailing"},
	"option": {"name": "보호 옵션", "type": "hedge", "cost": 1, "rarity": 1, "strike": 0.4, "premium": 0.25, "premium_up": 0.16, "note": "option"},
	"straddle": {"name": "스트래들", "type": "hedge", "cost": 2, "cost_up": 1, "rarity": 2, "units": 3, "premium": 0.75, "note": "straddle"},
	"foreign": {"name": "외국인 수급", "type": "info", "cost": 0, "rarity": 0, "acc": 0.62, "acc_up": 0.68, "note": "foreign_flow"},
	"research": {"name": "리서치 보고서", "type": "info", "cost": 1, "cost_up": 0, "rarity": 1, "acc": 0.72, "draw": 1, "note": "research"},
	"leverage": {"name": "레버리지", "type": "entry", "cost": 1, "rarity": 2, "cost_up": 0, "note": "leverage"},
	"p_rebound": {"name": "반등 매수", "type": "pattern", "cost": 0, "ethereal": true, "dir": 1, "budget": 375.0, "dist": 0.45, "pattern": "hammer"},
	"p_fall": {"name": "반락 매도", "type": "pattern", "cost": 0, "ethereal": true, "dir": -1, "budget": 375.0, "dist": 0.45, "pattern": "shooting_star"},
	"p_trend_up": {"name": "추세 매수", "type": "pattern", "cost": 0, "ethereal": true, "dir": 1, "budget": 250.0, "dist": 0.6, "pattern": "bullish_engulfing"},
	"p_trend_down": {"name": "추세 매도", "type": "pattern", "cost": 0, "ethereal": true, "dir": -1, "budget": 250.0, "dist": 0.6, "pattern": "bearish_engulfing"},
	"p_golden": {"name": "골든크로스 매수", "type": "pattern", "cost": 0, "ethereal": true, "dir": 1, "budget": 500.0, "pattern": "golden_cross"},
	"p_dead": {"name": "데드크로스 매도", "type": "pattern", "cost": 0, "ethereal": true, "dir": -1, "budget": 500.0, "pattern": "dead_cross"},
	"p_w": {"name": "쌍바닥 매수", "type": "pattern", "cost": 0, "ethereal": true, "dir": 1, "budget": 500.0, "dist": 0.5, "pattern": "double_bottom"},
	"p_m": {"name": "쌍봉 매도", "type": "pattern", "cost": 0, "ethereal": true, "dir": -1, "budget": 500.0, "dist": 0.5, "pattern": "double_top"},
	"h_average": {"name": "물타기 충동", "type": "habit", "cost": 0, "unplayable": true, "note": "averaging_down"},
	"h_revenge": {"name": "복수 매매", "type": "habit", "cost": 0, "unplayable": true, "note": "revenge"},
	"h_fomo": {"name": "FOMO", "type": "habit", "cost": 0, "unplayable": true, "note": "fomo"},
	"h_fear": {"name": "공포", "type": "habit", "cost": 0, "unplayable": true, "note": "margin_call"},
}

## 거래에 이긴 뒤 보상으로 나올 수 있는 카드.
const REWARD_POOL := ["long", "short", "stop", "take", "wait", "moc", "half", "pyramid", "contra", "trail",
	"option", "straddle", "foreign", "research", "leverage"]

const STARTER := ["long", "long", "long", "short", "short", "short", "stop", "stop", "take", "close", "close", "wait"]


static func starter_deck() -> Array[Card]:
	var deck: Array[Card] = []
	for id: String in STARTER:
		deck.append(Card.new(id))
	return deck


## 카드 글: [앞, 키워드, 뒤]. 키워드는 투자 노트 항목과 이어진다.
static func text(card: Card, trade: Trade) -> Array:
	var inst: Instrument = trade.instrument if trade != null else null
	var n := func(budget: float) -> String:
		if inst == null:
			return "증거금 %d만어치" % roundi(budget)
		return "%d계약" % inst.contracts_for(budget)
	var draw_text := func() -> String:
		var draw: int = card.value("draw", 0)
		return " 카드 %d장 뽑기." % draw if draw > 0 else ""
	match card.id:
		"long":
			return ["", "롱", " %s. 오르면 번다." % n.call(card.value("budget"))]
		"short":
			return ["", "숏", " %s. 내리면 번다." % n.call(card.value("budget"))]
		"stop":
			return ["불리한 쪽으로 예상 폭의 %d%%에 " % roundi(card.value("dist") * 100), "손절", "을 건다." + draw_text.call()]
		"take":
			return ["유리한 쪽으로 예상 폭의 %d%%에 " % roundi(card.value("dist") * 100), "지정가", " 익절을 건다." + draw_text.call()]
		"close":
			return ["모든 포지션을 시가에 ", "청산", "한다."]
		"moc":
			return ["오늘 ", "종가", "에 모두 정리한다. 밤을 넘기지 않는다." + draw_text.call()]
		"half":
			return ["포지션 절반을 시가에 ", "분할 청산", "한다." + draw_text.call()]
		"wait":
			return ["", "관망", " — 아무것도 안 하고 %d장 뽑는다." % card.value("draw")]
		"pyramid":
			return ["수익 중인 방향으로 %s 더. " % n.call(card.value("budget")), "피라미딩", ""]
		"contra":
			return ["어제 캔들과 반대로 %s. " % n.call(card.value("budget")), "역추세", " 진입이라 손절이 저절로 걸린다."]
		"trail":
			return ["", "트레일링 스톱", " — 손절선이 좋은 가격을 예상 폭의 %d%% 뒤에서 따라간다." % roundi(card.value("dist") * 100)]
		"option":
			return ["오늘만. 예상 폭의 %d%% 넘게 밀리면 그 아래 손실을 메워 준다. 값은 포지션 크기에 비례. " % roundi(card.value("strike") * 100), "옵션", ""]
		"straddle":
			return ["콜과 풋을 같이 산다. 오늘 어느 쪽이든 크게 움직이면 번다. ", "스트래들", ""]
		"foreign":
			return ["", "외국인 수급", "을 본다. 방향 신호 하나 (맞을 확률 %d%%)." % roundi(card.value("acc") * 100)]
		"research":
			return ["", "리서치", " 보고서 — 방향 신호 하나 (맞을 확률 %d%%)." % roundi(card.value("acc") * 100) + draw_text.call()]
		"leverage":
			return ["지금 포지션을 두 배로 불린다. ", "레버리지", "는 양쪽으로 커진다."]
		"p_rebound", "p_fall", "p_trend_up", "p_trend_down", "p_golden", "p_dead", "p_w", "p_m":
			var d := card.def()
			var side := "롱" if d["dir"] > 0 else "숏"
			var tail := " 손절 자동." if d.has("dist") else ""
			return ["", Patterns.label(d["pattern"]), " 완성 — %s %s.%s 오늘만." % [side, n.call(d["budget"]), tail]]
		"h_average":
			return ["뽑히면 손실 중인 포지션에 1계약이 저절로 붙는다. ", "물타기", ""]
		"h_revenge":
			return ["손에 있으면 진입을 해야 장을 마칠 수 있다. ", "복수 매매", ""]
		"h_fomo":
			return ["손에 있으면 주문 한도 -1, 진입 카드 비용 0. ", "FOMO", ""]
		"h_fear":
			return ["손에 있으면 주문 한도 -1. 마진콜이 남긴 ", "공포", ""]
	return ["", card.name(), ""]


## 그림 칸에 쓸 짧은 글.
static func art(card: Card, trade: Trade) -> String:
	var inst: Instrument = trade.instrument if trade != null else null
	match card.id:
		"long":
			return "▲ %d" % inst.contracts_for(card.value("budget")) if inst else "▲"
		"short":
			return "▼ %d" % inst.contracts_for(card.value("budget")) if inst else "▼"
		"stop":
			return "손절선"
		"take":
			return "익절선"
		"close":
			return "0계약"
		"moc":
			return "종가"
		"half":
			return "½"
		"wait":
			return "···"
		"pyramid":
			return "+%d" % inst.contracts_for(card.value("budget")) if inst else "+"
		"contra":
			return "반대로"
		"trail":
			return "따라간다"
		"option":
			return "보험"
		"straddle":
			return "콜+풋"
		"foreign":
			return "외국인"
		"research":
			return "보고서"
		"leverage":
			return "×2"
		"h_average":
			return "평단↓"
		"h_revenge":
			return "!"
		"h_fomo":
			return "!!"
		"h_fear":
			return "…"
	if card.type() == "pattern":
		return "▲" if card.def()["dir"] > 0 else "▼"
	return ""
