class_name Chatter
extends RefCounted
## 종목토론방. 장 상황에 개미들이 한마디씩 한다.
## 시장과 다른 난수를 써서, 대사를 고쳐도 시세 흐름은 그대로다.


class Line:
	var time: String
	var nick: String
	var text: String

	func _init(p_time: String, p_nick: String, p_text: String) -> void:
		time = p_time
		nick = p_nick
		text = p_text


const NICKS := [
	"물린개미", "존버는승리", "익절요정", "손절장인", "차트도사", "세력추적자",
	"가즈아", "평단13200", "월급루팡", "새벽주식", "주린이", "무릎에사서",
	"어깨에팔자", "뉴스보고옴", "퇴근시켜줘", "지나가던개미", "오늘만산다",
	"배당생활자", "호가창중독", "ㅇㅇ",
]

const LINES := {
	"ambient": [
		"여기 세력 있냐", "평단 {avg}인데 구조대 언제 오냐", "차트는 거짓말 안 함",
		"뉴스도 없는데 왜 움직임?", "{price} 지지 보고 들어간다", "{price} 뚫으면 진짜 간다",
		"단타 치다 장투 됨", "익절은 언제나 옳다", "물타기 한 번만 더", "손절 라인 어디로 잡음?",
		"형들 이거 들어가도 됨?", "종토방 믿지 마라", "호가창 보는 맛에 산다",
		"매도벽 두꺼운 거 보이냐", "누가 자꾸 매수벽 쌓네", "오늘 거래량 좀 붙는다",
	],
	"morning": ["장초반 변동성 조심", "시초가 먹고 튄다", "출근 도장 찍었습니다"],
	"lunch": ["점심 뭐 먹지", "거래량 실종", "점심시간엔 쉽시다", "밥 먹고 오면 올라 있겠지"],
	"afternoon": ["막판 수급 들어온다", "오후장 무섭다", "종가 어디서 끝나냐"],
	"preopen": ["시가 어디서 뜰까", "예상체결가 보는 중", "동시호가 눈치싸움 시작", "밤사이 뉴스 봤냐"],
	"gap_up": ["시가부터 날아가네", "갭상 ㄷㄷ", "시작부터 빨갛다"],
	"gap_down": ["시가부터 파랗다", "출근하자마자 물림", "갭하락 실화냐"],
	"flat_open": ["보합 출발", "시가 무난하네", "오늘은 조용하려나"],
	"closing": ["종가 싸움 시작", "마지막 10분", "종가 관리 들어오나", "예상체결가 계속 바뀐다"],
	"closing_buy": ["막판에 누가 쓸어 담냐", "종가 올리기 들어왔다"],
	"closing_sell": ["막판에 누가 던지냐", "종가 누르기 들어왔다"],
	"close_up": ["종가 빨간색 감사합니다", "오늘은 이겼다", "내일도 부탁한다"],
	"close_down": ["종가 파랗다", "내일 보자", "오늘은 졌다"],
	"close_flat": ["보합 마감. 싸움만 하다 끝남", "본전이면 됐다"],
	"surge": ["누가 이렇게 사냐", "슈팅 나온다", "가즈아", "빨간불 들어왔다", "매도벽 녹는다"],
	"drop": ["누가 던지냐", "아 물렸다", "지하실 구경 가자", "개미 털기 시작", "매수벽 다 뚫림"],
	"vi_up": ["VI 걸렸다 ㄷㄷ", "VI 풀리면 한 번 더 간다", "단일가 눈치싸움"],
	"vi_down": ["VI 떴다 무섭다", "여기서 받쳐야 됨", "단일가에서 누가 받냐"],
	"limit_up": ["상 찍었다!!!", "상한가 잠가라", "문 닫아라"],
	"limit_down": ["하한가... 할 말이 없다", "탈출은 지능순", "내일 시가만 보자"],
	"big_buy": ["방금 누가 크게 긁음", "큰손 들어왔다", "세력 형님 오셨다"],
	"big_sell": ["방금 큰 물량 던짐", "누가 이렇게 파냐", "큰손 탈출?"],
	"whale_buy": ["고래 떴다", "세력 들어왔네", "누가 한 번에 쓸었다"],
	"whale_sell": ["고래가 던졌다", "세력 빠진다", "물량 한 번에 쏟아짐"],
	"skill_bull": ["{pattern} 나왔다", "차트 이쁘게 나온다", "{pattern}이면 간다"],
	"skill_bear": ["{pattern} 떴다 조심", "{pattern}이면 빠진다", "차트 망가졌다"],
	"news_good": ["재료 떴다", "기사 보고 들어옴", "이건 호재 맞다"],
	"news_bad": ["악재 떴네", "이거 설거지 각", "기사 보고 튄다"],
}

## 뉴스 제목에 이 말이 들어 있으면 이 대사를 쓴다.
const NEWS_LINES := {
	"주주배정 유상증자": ["유증 또 함?", "주주를 ATM으로 아네"],
	"제3자배정": ["대기업이 들어온다고?", "이런 유증은 환영"],
	"무상증자": ["무증 못 참지", "권리락 전에 탄다"],
	"흡수합병": ["합병 재료 좋다", "변동성 장난 아니겠네"],
	"합병비율": ["합병비율 실화냐", "매수청구가 밑으로는 안 간다"],
	"자사주 취득": ["자사주 사주면 땡큐"],
	"소각": ["소각까지? 주주 챙기네"],
	"블록딜": ["대주주가 판다고? 나도 판다"],
	"전환사채": ["CB 또 찍냐", "오버행 무섭다"],
	"전환청구": ["전환 물량 나온다 조심"],
	"피인수설": ["조회공시 답 기다리는 중", "루머에 사서 뉴스에 팔아라"],
	"사실무근": ["사실무근 ㅋㅋ 역시", "루머 매수 다 물림"],
	"검토 중": ["검토 중이면 인정이지"],
	"기술이전 계약": ["대박 떴다", "이 맛에 존버한다"],
	"결렬": ["결렬이라니 멘탈 나감", "기대감 다 빠진다"],
	"공매도": ["공매도 리포트 또 나왔네", "공매도 세력 신났다"],
	"횡령": ["횡령이면 끝이다", "거래정지만은 제발"],
	"MSCI": ["패시브 들어온다"],
	"연준": ["연준 한마디에 들썩인다"],
	"환율": ["환율 무섭다", "외국인 빠지겠네"],
	"사이드카": ["사이드카 떴다. 시장 전체가 빠짐"],
	"중동": ["전쟁 뉴스 나오면 일단 빠진다"],
	"관세": ["관세 타결 호재"],
	"엔캐리": ["엔캐리 청산이면 다 빠진다"],
	"컨센서스": ["실적 보고 들어간다"],
	"어닝 쇼크": ["실적 쇼크면 답 없다"],
	"공급계약": ["수주 공시 좋다"],
	"목표주가": ["리포트 나왔다"],
	"투자의견": ["매도 리포트는 처음 본다"],
}

var rng := RandomNumberGenerator.new()
## 최신이 앞.
var lines: Array = []
## 대사가 추가될 때마다 1씩 오른다 (화면 갱신용).
var serial := 0
var _last_nick := ""


func _init(seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value * 7919 + 17
	else:
		rng.randomize()


## pool 대사 중 하나를 누군가 말한다.
func say(time: String, pool: String, vars := {}) -> void:
	var options: Array = LINES.get(pool, [])
	if options.is_empty():
		return
	_post(time, options[rng.randi_range(0, options.size() - 1)], vars)


## 뉴스 제목에 맞는 반응. 딱 맞는 게 없으면 호재·악재 일반 반응.
func react_to_news(time: String, title: String, tone: int) -> void:
	for key: String in NEWS_LINES:
		if title.contains(key):
			var options: Array = NEWS_LINES[key]
			_post(time, options[rng.randi_range(0, options.size() - 1)], {})
			return
	if tone == War.Faction.BULL:
		say(time, "news_good")
	elif tone == War.Faction.BEAR:
		say(time, "news_bad")


func chance(p: float) -> bool:
	return rng.randf() < p


func _post(time: String, template: String, vars: Dictionary) -> void:
	var text := template
	for key: String in vars:
		text = text.replace("{%s}" % key, str(vars[key]))
	var nick: String = NICKS[rng.randi_range(0, NICKS.size() - 1)]
	if nick == _last_nick:
		nick = NICKS[(NICKS.find(nick) + 1) % NICKS.size()]
	_last_nick = nick
	lines.push_front(Line.new(time, nick, text))
	serial += 1
	if lines.size() > 60:
		lines.pop_back()
