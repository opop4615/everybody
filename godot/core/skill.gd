class_name Skill
extends RefCounted
## 차트 패턴이 완성되면 해당 진영이 얻는 스킬.
##
## 스킬은 진영 병력(시장가 물량)이 한 방향으로 호가를 쓸어버리는 공격이다.
## power는 '표준 호가 잔량 몇 칸 분량'의 물량이라서, 상대가 두껍게 쌓은 벽에 막히면
## 그만큼 덜 나간다.

var name: String
var pattern: int
## 한 번 공격할 때 쓰는 물량 (표준 잔량 칸 수).
var power: float
## 몇 분(틱)에 걸쳐 연속으로 공격하는지.
var waves: int
## 발동 시 아군 최우선 호가에 쌓는 방어벽 (표준 잔량 칸 수).
var wall: float
## 발동 시 시장 심리 변화량 (진영 방향 기준, 0~1).
var morale: float
var description: String

static var _all: Array = []

const P := ChartPatterns.Pattern


func _init(p_name: String, p_pattern: int, p_power: float, p_description: String,
		p_waves := 1, p_wall := 0.0, p_morale := 0.0) -> void:
	name = p_name
	pattern = p_pattern
	power = p_power
	description = p_description
	waves = p_waves
	wall = p_wall
	morale = p_morale


func faction() -> int:
	return ChartPatterns.faction(pattern)


## 스킬 등급: 패턴이 크고 드물수록 강하다.
func tier() -> int:
	var total := power * waves
	if total >= 18:
		return 3
	if total >= 10:
		return 2
	return 1


static func of(p: int) -> Skill:
	for skill: Skill in all():
		if skill.pattern == p:
			return skill
	return null


static func all() -> Array:
	if _all.is_empty():
		_all = [
			Skill.new("장악 돌파", P.BULLISH_ENGULFING, 6, "직전 음봉을 삼킨 기세로 매도 호가를 들이받는다", 1, 0, 0.12),
			Skill.new("망치 방패", P.HAMMER, 3, "아래꼬리 지지선에 거대한 매수벽을 세우고 반격한다", 1, 6, 0.08),
			Skill.new("삼병 돌격", P.THREE_WHITE_SOLDIERS, 4, "세 병사가 3분 동안 연속으로 매도 호가를 들이받는다", 3, 0, 0.15),
			Skill.new("골든 브레이크", P.GOLDEN_CROSS, 10, "단기선이 장기선을 뚫는 순간 매도 호가를 관통", 1, 0, 0.25),
			Skill.new("W 반격", P.DOUBLE_BOTTOM, 11, "두 번 버틴 바닥에 벽을 세우고 넥라인 위로 역습한다", 1, 5, 0.25),
			Skill.new("넥라인 붕괴", P.INVERSE_HEAD_AND_SHOULDERS, 9, "궁극기. 머리를 딛고 넥라인을 부수며 2연속 돌파한다", 2, 0, 0.35),
			Skill.new("장악 붕괴", P.BEARISH_ENGULFING, 6, "직전 양봉을 덮친 기세로 매수 호가를 짓밟는다", 1, 0, 0.12),
			Skill.new("유성 낙하", P.SHOOTING_STAR, 3, "윗꼬리 저항선에 매도벽을 세우고 내리꽂는다", 1, 6, 0.08),
			Skill.new("삼까마귀 급강하", P.THREE_BLACK_CROWS, 4, "까마귀 세 마리가 3분 동안 매수 호가를 연속 강타한다", 3, 0, 0.15),
			Skill.new("데드 슬래시", P.DEAD_CROSS, 10, "단기선이 장기선 아래로 꺾이며 매수 호가를 베어낸다", 1, 0, 0.25),
			Skill.new("M 폭격", P.DOUBLE_TOP, 11, "두 번 막힌 천장에 벽을 치고 넥라인 아래로 폭격한다", 1, 5, 0.25),
			Skill.new("목 베기", P.HEAD_AND_SHOULDERS, 9, "궁극기. 넥라인을 베어내며 2연속 하방 돌파한다", 2, 0, 0.35),
		]
	return _all
