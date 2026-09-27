class_name MarketEvent
extends RefCounted
## 전장에 떨어지는 뉴스·공시·매크로·세계정세 이벤트.
##
## 모든 수치는 진영 중립적이다: 양수는 매수세, 음수는 매도세 편.
## 물량 단위는 '표준 호가 잔량 칸 수'라서 종목 가격과 관계없이 같은 무게를 가진다.

enum Category { DISCLOSURE, BREAKING, REPORT, RUMOR, MACRO, WORLD }

const CATEGORY_LABELS := ["공시", "속보", "리포트", "루머", "매크로", "세계정세"]

var category: int
## {name}은 종목명으로 바뀐다.
var title: String
var detail: String
## 즉시 바뀌는 시장 심리 (-1 ~ 1).
var sentiment := 0.0
## 즉시 쏟아지는 시장가 물량 (칸 수, +매수 / -매도).
var shock := 0.0
## pressure_ticks분 동안 매 분 들어오는 시장가 물량 (칸 수, +매수 / -매도).
var pressure := 0.0
var pressure_ticks := 0
## volatility_ticks분 동안 적용되는 거래량 배수.
var volatility := 1.0
var volatility_ticks := 0
## 현재가 대비 wall_offset 위치에 쌓이는 대형 벽 (음수면 매수벽, 양수면 매도벽).
var wall_offset := 0.0
var wall_size := 0.0
var wall_tag := ""
## 후속 이벤트 후보. follow_up_delay분 뒤 하나가 무작위로 터진다.
var follow_ups: Array = []
var follow_up_delay := 0
## 무작위 뽑기 가중치.
var weight := 1

static var _deck: Array = []

const C := Category


func _init(spec: Dictionary) -> void:
	for key in spec:
		set(key, spec[key])


func category_label() -> String:
	return CATEGORY_LABELS[category]


func title_for(company: String) -> String:
	return title.replace("{name}", company)


func detail_for(company: String) -> String:
	return detail.replace("{name}", company)


## 무작위로 터지는 이벤트 덱. 후속 이벤트는 여기 없고 선행 이벤트를 통해서만 나온다.
static func deck() -> Array:
	if not _deck.is_empty():
		return _deck
	var specs := [
		# ── 기업 공시 ──
		{category = C.DISCLOSURE, title = "{name}, 1,200억 주주배정 유상증자 결정",
			detail = "발행가 할인율 25%. 신주 물량 부담에 매도세 급증, 위쪽에 물량벽",
			sentiment = -0.5, shock = -5.0, pressure = -0.4, pressure_ticks = 20,
			wall_offset = 0.02, wall_size = 6.0, wall_tag = "신주물량", weight = 3},
		{category = C.DISCLOSURE, title = "{name}, 대기업 대상 제3자배정 유상증자",
			detail = "할증 발행에 전략적 투자자 등장. 유증이라고 다 악재는 아니다",
			sentiment = 0.45, shock = 5.0, weight = 2},
		{category = C.DISCLOSURE, title = "{name}, 1주당 1주 무상증자 결정",
			detail = "권리락 착시 기대감에 개미 매수세 몰려듦",
			sentiment = 0.55, shock = 6.0, pressure = 0.3, pressure_ticks = 15, weight = 3},
		{category = C.DISCLOSURE, title = "{name}, 알짜 비상장사 흡수합병 결정",
			detail = "합병비율 유리 평가. 변동성 확대 주의",
			sentiment = 0.4, shock = 4.0, volatility = 1.8, volatility_ticks = 30, weight = 2},
		{category = C.DISCLOSURE, title = "{name}, 계열사와 합병 결정… 합병비율 논란",
			detail = "소액주주 반발. 주식매수청구가(-6%)에 거대한 매수벽 형성",
			sentiment = -0.4, shock = -4.0, volatility = 1.5, volatility_ticks = 20,
			wall_offset = -0.06, wall_size = 12.0, wall_tag = "매수청구", weight = 2},
		{category = C.DISCLOSURE, title = "{name}, 300억 자사주 취득 결정",
			detail = "장중 꾸준한 회사 매수 물량, 아래에 지지벽",
			sentiment = 0.2, pressure = 0.5, pressure_ticks = 40,
			wall_offset = -0.02, wall_size = 5.0, wall_tag = "자사주", weight = 2},
		{category = C.DISCLOSURE, title = "{name}, 자사주 전량 소각 결정",
			detail = "주주환원 강화. 주당가치 상승",
			sentiment = 0.35, shock = 3.0},
		{category = C.BREAKING, title = "{name} 최대주주, 시간외 블록딜로 지분 매각",
			detail = "할인율 8% 대량 물량이 장중으로 출회",
			sentiment = -0.35, shock = -8.0, weight = 2},
		{category = C.DISCLOSURE, title = "{name}, 영업이익 컨센서스 40% 상회",
			detail = "어닝 서프라이즈. 기관 매수 유입",
			sentiment = 0.5, shock = 6.0, weight = 2},
		{category = C.DISCLOSURE, title = "{name}, 적자전환… 어닝 쇼크",
			detail = "실망 매물 쏟아짐",
			sentiment = -0.5, shock = -6.0, weight = 2},
		{category = C.DISCLOSURE, title = "{name}, 매출액 45% 규모 단일판매·공급계약 체결",
			detail = "대형 수주에 매수세 유입",
			sentiment = 0.4, shock = 5.0, weight = 2},
		{category = C.DISCLOSURE, title = "{name}, 500억 전환사채(CB) 발행 결정",
			detail = "잠재 오버행 우려. 나중에 전환 물량이 풀릴 수 있다",
			sentiment = -0.25, shock = -2.0, follow_up_delay = 45, weight = 2,
			follow_ups = [
				{category = C.DISCLOSURE, title = "{name}, CB 전환청구권 행사… 추가상장 예정",
					detail = "전환 물량이 시장에 풀린다. 위쪽에 물량벽",
					sentiment = -0.3, pressure = -0.5, pressure_ticks = 20,
					wall_offset = 0.015, wall_size = 6.0, wall_tag = "전환물량"},
			]},
		{category = C.RUMOR, title = "{name}, 대기업 피인수설 확산",
			detail = "거래소 조회공시 요구. 15분 뒤 답변 예정",
			sentiment = 0.25, shock = 3.0, follow_up_delay = 15, weight = 2,
			follow_ups = [
				{category = C.DISCLOSURE, title = "{name} 조회공시 답변: \"지분 매각 검토 중\"",
					detail = "사실상 인정. 인수 프리미엄 기대", sentiment = 0.45, shock = 5.0},
				{category = C.DISCLOSURE, title = "{name} 조회공시 답변: \"사실무근\"",
					detail = "루머 매수세 일제히 이탈", sentiment = -0.5, shock = -5.0},
			]},
		{category = C.BREAKING, title = "{name}, 글로벌 기술이전 협상 결과 발표 임박",
			detail = "20분 뒤 결과 발표. 양쪽 모두 숨죽임",
			sentiment = 0.1, volatility = 1.5, volatility_ticks = 20, follow_up_delay = 20,
			follow_ups = [
				{category = C.DISCLOSURE, title = "{name}, 1조원 규모 기술이전 계약 체결",
					detail = "대박. 매도 호가가 증발한다", sentiment = 0.7, shock = 8.0},
				{category = C.BREAKING, title = "{name}, 기술이전 협상 최종 결렬",
					detail = "기대감 붕괴. 투매 발생", sentiment = -0.7, shock = -8.0},
			]},
		{category = C.BREAKING, title = "해외 공매도 리서치, {name} 저격 보고서 발간",
			detail = "회계 의혹 제기. 공매도 세력 총공세",
			sentiment = -0.55, shock = -6.0, pressure = -0.3, pressure_ticks = 15},
		{category = C.BREAKING, title = "{name}, 경영진 횡령·배임 혐의 피소",
			detail = "거래정지 공포. 투매", sentiment = -0.7, shock = -8.0},
		{category = C.BREAKING, title = "{name}, MSCI 지수 편입 확정",
			detail = "패시브 자금이 꾸준히 들어온다",
			sentiment = 0.3, pressure = 0.5, pressure_ticks = 25},
		{category = C.REPORT, title = "증권사, {name} 목표주가 30% 상향",
			detail = "\"업사이드 충분\" 매수 의견", sentiment = 0.2, shock = 2.0, weight = 2},
		{category = C.REPORT, title = "증권사, {name} 투자의견 \"매도\"로 하향",
			detail = "보기 드문 매도 리포트", sentiment = -0.25, shock = -2.0, weight = 2},
		# ── 매크로 ──
		{category = C.MACRO, title = "미 연준, 기준금리 0.5%p 인하 (빅컷)",
			detail = "유동성 기대에 위험자산 선호", sentiment = 0.3, shock = 3.0},
		{category = C.MACRO, title = "연준 의장 \"금리 인하 서두르지 않겠다\"",
			detail = "매파 발언에 증시 냉각", sentiment = -0.3, shock = -3.0},
		{category = C.MACRO, title = "미국 CPI 예상치 상회… 인플레이션 재점화",
			detail = "금리 인하 기대 후퇴", sentiment = -0.25, shock = -3.0},
		{category = C.MACRO, title = "원·달러 환율 1,450원 돌파",
			detail = "외국인 순매도가 이어진다",
			sentiment = -0.2, pressure = -0.3, pressure_ticks = 20},
		{category = C.MACRO, title = "간밤 나스닥 3% 급등 마감",
			detail = "국내 증시 동반 강세 출발", sentiment = 0.25, shock = 2.0},
		{category = C.MACRO, title = "정부, 증시 밸류업 세제 지원 발표",
			detail = "저평가 해소 기대", sentiment = 0.25, shock = 2.0},
		{category = C.MACRO, title = "코스피200 선물 급락, 매도 사이드카 발동",
			detail = "프로그램 매도 5분 정지. 시장 전체 공포",
			sentiment = -0.3, shock = -4.0, volatility = 1.5, volatility_ticks = 10},
		# ── 세계정세 ──
		{category = C.WORLD, title = "중동 무력 충돌 격화… 국제유가 급등",
			detail = "지정학 리스크로 변동성 확대",
			sentiment = -0.35, shock = -4.0, volatility = 1.6, volatility_ticks = 25},
		{category = C.WORLD, title = "미·중 관세 협상 전격 타결",
			detail = "무역분쟁 완화에 수출주 강세", sentiment = 0.35, shock = 4.0},
		{category = C.WORLD, title = "대만해협 군사 긴장 고조",
			detail = "공급망 불안", sentiment = -0.3, shock = -3.0},
		{category = C.WORLD, title = "일본 금리 인상… 엔캐리 트레이드 청산 공포",
			detail = "글로벌 위험자산 동반 급락",
			sentiment = -0.4, shock = -5.0, volatility = 1.8, volatility_ticks = 20},
		{category = C.WORLD, title = "동유럽 휴전 협정 서명",
			detail = "재건 수혜 기대, 위험선호 회복", sentiment = 0.25, shock = 3.0},
	]
	for spec: Dictionary in specs:
		_deck.append(_build(spec))
	return _deck


static func _build(spec: Dictionary) -> MarketEvent:
	var copy := spec.duplicate()
	var follow_specs: Array = copy.get("follow_ups", [])
	copy.erase("follow_ups")
	var event := MarketEvent.new(copy)
	for follow: Dictionary in follow_specs:
		event.follow_ups.append(_build(follow))
	return event
