class_name Era2020
extends RefCounted
## 2020 팬데믹 시대. 막마다 열(column) 목록이고, 한 열에서 한 칸을 고른다.
## 이웃한 줄(lane 차이 1 이하)로만 건너갈 수 있다.
##
## 칸 kind: start, trade(거래), elite(발표일 거래), boss(막 보스), news(뉴스), desk(데스크), rest(퇴근)

const NAME := "2020 · 팬데믹"
const START_ACCOUNT := 3000.0
const FLOOR := 1900.0


static func acts() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append({
		"title": "1막 · 공포의 3월",
		"period": "2020.01.02 – 03.20",
		"columns": [
			[_n("a1_start", "start", "2020-01-02", 1)],
			[_news("a1_n0103", "2020-01-03", 0, "n_0103"),
				_t("a1_usd1", "trade", "usdkrw", "2020-01-03", 1, 3, 20.0, "연초 원/달러"),
				_n("a1_desk1", "desk", "2020-01-03", 2)],
			[_t("a1_gold1", "trade", "gold", "2020-01-08", 0, 3, 20.0, "이란 보복 · 금 급등락"),
				_t("a1_wti1", "trade", "wti", "2020-01-08", 1, 3, 25.0, "중동 긴장 · 유가"),
				_n("a1_rest1", "rest", "2020-01-08", 2)],
			[_news("a1_n0120", "2020-01-20", 0, "n_0120"),
				_t("a1_usd2", "trade", "usdkrw", "2020-01-20", 1, 3, 20.0, "첫 확진자 뒤 원/달러"),
				_n("a1_desk2", "desk", "2020-01-20", 2)],
			[_t("a1_wti2", "trade", "wti", "2020-01-27", 0, 4, 15.0, "우한 봉쇄 · 수요 공포"),
				_t("a1_gold2", "trade", "gold", "2020-01-27", 1, 4, 20.0, "안전자산으로"),
				_n("a1_rest2", "rest", "2020-01-27", 2)],
			[_news("a1_n0223", "2020-02-24", 0, "n_0223"),
				_t("a1_usd3", "trade", "usdkrw", "2020-02-24", 1, 4, 30.0, "위기경보 뒤 환율"),
				_n("a1_desk3", "desk", "2020-02-24", 2)],
			[_t("a1_gold3", "elite", "gold", "2020-03-02", 0, 4, 90.0, "연준 긴급 인하"),
				_t("a1_wti3", "elite", "wti", "2020-03-06", 1, 4, 140.0, "산유국 합의 결렬"),
				_n("a1_rest3", "rest", "2020-03-06", 2)],
			[_news("a1_n0311", "2020-03-12", 0, "n_0311"),
				_n("a1_desk4", "desk", "2020-03-12", 1),
				_t("a1_usd4", "trade", "usdkrw", "2020-03-11", 2, 3, 30.0, "팬데믹 선언 · 달러로")],
			[_news("a1_n0316", "2020-03-16", 0, "n_0316"),
				_n("a1_rest4", "rest", "2020-03-16", 2)],
			[_t("a1_boss", "boss", "gold", "2020-03-16", 1, 5, 110.0, "현금 확보 매도 · 금마저 무너지다",
				["보스 · 공포의 3월 셋째 주", "현금이 급해진 투자자들이 안전자산인 금까지 판다"])],
		],
	})
	list.append({
		"title": "2막 · 마이너스 유가",
		"period": "2020.03.20 – 04.22",
		"columns": [
			[_n("a2_start", "start", "2020-03-20", 1)],
			[_news("a2_n0319", "2020-03-20", 0, "n_0319"),
				_t("a2_usd1", "trade", "usdkrw", "2020-03-20", 1, 3, 65.0, "통화스와프 다음 날"),
				_n("a2_desk1", "desk", "2020-03-20", 2)],
			[_t("a2_gold1", "trade", "gold", "2020-03-26", 0, 4, 55.0, "금의 반등"),
				_t("a2_wti1", "trade", "wti", "2020-03-26", 1, 4, 85.0, "바닥 모를 유가"),
				_n("a2_rest1", "rest", "2020-03-26", 2)],
			[_t("a2_wti2", "elite", "wti", "2020-04-01", 0, 4, 80.0, "감산 합의 기대"),
				_t("a2_usd2", "trade", "usdkrw", "2020-04-02", 1, 4, 20.0, "달러 되돌림"),
				_n("a2_desk2", "desk", "2020-04-02", 2)],
			[_news("a2_n0412", "2020-04-13", 0, "n_0412"),
				_n("a2_rest2", "rest", "2020-04-13", 1),
				_t("a2_gold2", "trade", "gold", "2020-04-13", 2, 3, 50.0, "금 7년 만의 고점")],
			[_t("a2_boss", "boss", "wti", "2020-04-15", 1, 5, 650.0, "마이너스 유가",
				["보스 · WTI 5월물 만기 주간", "저장할 곳이 모자라 원유를 돈을 주고라도 넘기려 한다"])],
		],
	})
	return list


static func _n(id: String, kind: String, date: String, lane: int) -> Dictionary:
	return {"id": id, "kind": kind, "date": date, "lane": lane}


static func _t(id: String, kind: String, inst: String, date: String, lane: int, days: int, target: float,
		title: String, rules: Array = []) -> Dictionary:
	return {"id": id, "kind": kind, "inst": inst, "date": date, "lane": lane, "days": days, "target": target,
		"title": title, "rules": rules}


static func _news(id: String, date: String, lane: int, news: String) -> Dictionary:
	return {"id": id, "kind": "news", "date": date, "lane": lane, "news": news, "title": NEWS[news]["headline"]}


## 뉴스. choices: {text, detail, effect, need: [노트 id, 단계]}
const NEWS := {
	"n_0103": {
		"date": "2020년 1월 3일 금요일",
		"headline": "미군 공습에 이란 솔레이마니 사령관 숨져",
		"body": "미국이 이라크 바그다드 공항에서 이란 혁명수비대 쿠드스군의 솔레이마니 사령관을 공습해 숨지게 했다. 이란은 보복을 예고했고, 중동 긴장에 금과 유가가 먼저 움직였다.",
		"notes": ["day_0103", "safe_haven"],
		"choices": [
			{"text": "밤새 뉴스를 본다", "detail": "다음 거래 첫날 주문 한도 +1", "effect": "alert"},
			{"text": "금의 성격을 공부한다", "detail": "투자 노트 · 안전자산 한 단계", "effect": "study:safe_haven"},
			{"text": "안전자산으로 돈이 몰릴 걸 안다", "detail": "리서치 보고서 카드를 얻는다", "effect": "card:research", "need": ["safe_haven", 1]},
		],
	},
	"n_0120": {
		"date": "2020년 1월 20일 월요일",
		"headline": "국내 첫 코로나19 확진자 나와",
		"body": "중국 우한에서 입국한 여행객이 국내 첫 확진자로 판정됐다. 시장은 아직 크게 흔들리지 않았다.",
		"notes": ["day_0120"],
		"choices": [
			{"text": "대수롭지 않게 넘긴다", "detail": "성과급 +25", "effect": "bonus:25"},
			{"text": "보험부터 챙긴다", "detail": "보호 옵션 카드를 얻는다", "effect": "card:option"},
			{"text": "관련 기사를 모은다", "detail": "투자 노트 · 변동성 한 단계", "effect": "study:volatility"},
		],
	},
	"n_0223": {
		"date": "2020년 2월 23일 일요일",
		"headline": "감염병 위기경보 최고 단계 '심각'으로 격상",
		"body": "정부가 위기경보를 가장 높은 단계로 올렸다. 다음 날 아침 시장은 공포 속에 열린다.",
		"notes": ["day_0223"],
		"choices": [
			{"text": "기회라고 본다", "detail": "스트래들 카드를 얻는다. 대신 덱에 FOMO", "effect": "card:straddle,habit:h_fomo"},
			{"text": "포지션을 줄이고 쉰다", "detail": "덱에서 습관 카드 한 장을 지운다 (없으면 성과급 +20)", "effect": "cleanse"},
			{"text": "변동성이 커질 걸 안다", "detail": "카드 한 장을 강화한다", "effect": "upgrade", "need": ["volatility", 1]},
		],
	},
	"n_0311": {
		"date": "2020년 3월 11일 수요일 (현지)",
		"headline": "세계보건기구, 코로나19 팬데믹 선언",
		"body": "세계보건기구가 코로나19를 세계적 대유행으로 규정했다. 다음 날 아시아 시장이 흔들렸다.",
		"notes": ["day_0311"],
		"choices": [
			{"text": "보험을 든다", "detail": "강화된 보호 옵션 카드를 얻는다", "effect": "card+:option"},
			{"text": "겁나서 다 판다", "detail": "성과급 +40. 대신 덱에 공포", "effect": "bonus:40,habit:h_fear"},
			{"text": "퀀트와 밤을 샌다", "detail": "투자 노트 · 이동평균 한 단계", "effect": "study:moving_average"},
		],
	},
	"n_0316": {
		"date": "2020년 3월 16일 월요일",
		"headline": "미 연준 제로금리 · 한은 0.75%로 긴급 인하",
		"body": "미 연준이 일요일에 기준금리를 0~0.25%로 내렸고, 한국은행도 임시 금융통화위원회를 열어 1.25%에서 0.75%로 내렸다. 국내 증시는 이날부터 6개월간 공매도가 금지됐다.",
		"notes": ["day_0316", "base_rate"],
		"choices": [
			{"text": "금리 인하의 뜻을 공부한다", "detail": "투자 노트 · 기준금리 한 단계", "effect": "study:base_rate"},
			{"text": "외국인 움직임부터 본다", "detail": "강화된 외국인 수급 카드를 얻는다", "effect": "card+:foreign"},
			{"text": "금마저 팔리는 이유를 안다", "detail": "이번 막 보스에서 신호 정확도 +10%p", "effect": "insight:a1_boss", "need": ["safe_haven", 2]},
		],
	},
	"n_0319": {
		"date": "2020년 3월 19일 목요일 밤",
		"headline": "한미 600억 달러 통화스와프 체결",
		"body": "한국은행과 미 연준이 600억 달러 규모 통화스와프를 맺었다. 2008년의 두 배 규모다. 다음 날 환율은 안정을 찾기 시작했다.",
		"notes": ["day_0319", "swap_line"],
		"choices": [
			{"text": "달러 숏을 준비한다", "detail": "강화된 숏 진입 카드를 얻는다", "effect": "card+:short"},
			{"text": "한숨 돌린다", "detail": "덱에서 습관 카드 한 장을 지운다 (없으면 성과급 +20)", "effect": "cleanse"},
			{"text": "2008년을 떠올린다", "detail": "다음 거래 첫날 주문 한도 +1, 카드 한 장 강화", "effect": "alert,upgrade", "need": ["swap_line", 1]},
		],
	},
	"n_0412": {
		"date": "2020년 4월 12일 일요일",
		"headline": "OPEC+ 하루 970만 배럴 감산 합의",
		"body": "산유국들이 사상 최대 규모 감산에 합의했다. 그러나 수요가 무너진 탓에 원유를 쌓아 둘 곳은 빠르게 바닥나고 있었다.",
		"notes": ["oil_supply"],
		"choices": [
			{"text": "유가 반등에 건다", "detail": "강화된 롱 진입 카드를 얻는다. 대신 덱에 FOMO", "effect": "card+:long,habit:h_fomo"},
			{"text": "저장 공간을 조사한다", "detail": "투자 노트 · 만기와 저장 한 단계, 보스 신호 정확도 +8%p", "effect": "study:storage,insight:a2_boss"},
			{"text": "쉰다", "detail": "덱에서 습관 카드 한 장을 지운다 (없으면 성과급 +20)", "effect": "cleanse"},
		],
	},
}

## 막이 끝나면 나오는 복기 퀴즈.
const QUIZZES := [
	{"question": "3월 20일, 코스피가 하루 7.44% 오른 날 외국인은?",
		"options": ["크게 샀다", "크게 팔았다", "거의 움직이지 않았다"], "answer": 1,
		"explain": "외국인은 이날도 5,851억 원어치를 팔았다. 반등을 이끈 건 기관(+3,068억)과 개인(+2,006억)이었다.",
		"note": "foreign_flow"},
	{"question": "2020년 4월 20일, WTI 5월물이 마이너스로 끝난 가장 큰 까닭은?",
		"options": ["산유국이 증산을 발표했다", "만기에 원유를 받아 둘 저장 공간이 모자랐다", "달러 값이 폭락했다"], "answer": 1,
		"explain": "수요가 무너진 채 만기가 다가오자, 실물을 받아 쌓아 둘 곳이 없는 쪽이 돈을 주고라도 계약을 넘기려 했다.",
		"note": "storage"},
]
