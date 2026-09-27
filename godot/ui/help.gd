class_name Help
extends Control
## [0999] 도움말. 길게 설명하지 않는다.

const LINES := [
	["호가전쟁", true],
	["호가창 한 줄이 탑의 한 층이다. 위 열 층은 팔자(매도), 아래 열 층은 사자(매수)가 지킨다.", false],
	["층에 선 병사 수가 그 호가의 잔량이다. 가운데 노란 이음매가 체결가다.", false],
	["", false],
	["승패", true],
	["15:30 종가가 기준가보다 높으면 사자, 낮으면 팔자가 이긴다. 상·하한가를 10분 지켜도 끝난다.", false],
	["", false],
	["하루", true],
	["08:50 장전 동시호가: 주문이 쌓였다가 09:00에 시가 한 가격으로 체결된다.", false],
	["장중에 10% 급변하면 VI. 2분 동안 다시 동시호가다.", false],
	["15:20 장 마감 동시호가: 마지막 10분의 주문이 종가를 정한다.", false],
	["", false],
	["손", true],
	["A 시장가 돌격 · S 지정가 벽 · D 포지션 정리 · F 미체결 취소 · 1~4 수량", false],
	["Q W E 스킬 카드 · 호가를 누르면 그 가격에 주문 · Space 멈춤 · X 배속 · M 소리", false],
	["", false],
	["스킬", true],
	["5분봉에 차트 패턴이 완성되면 그쪽 편이 한 번 크게 친다. 내 편 패턴은 카드로 들어오고", false],
	["30분 안에 써야 한다. 상대 편 패턴은 3분 뒤 알아서 날아온다. 벽이 두꺼우면 덜 뚫린다.", false],
]


func _draw() -> void:
	Hts.well(self, Rect2(Vector2.ZERO, size))
	var y := 3.0
	for line: Array in LINES:
		if line[0].is_empty():
			y += 5
			continue
		Hts.text(self, Vector2(6, y), line[0], Hts.SELECT if line[1] else Hts.INK, 12, line[1])
		y += Hts.LINE
