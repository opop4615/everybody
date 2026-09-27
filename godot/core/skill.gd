class_name Skill
extends RefCounted
## 차트 패턴이 완성되면 그 방향 편이 얻는 한 수. 이름은 패턴 이름 그대로 쓴다.
##
## 스킬은 편 전체의 시장가 물량이 한 방향으로 호가를 쓸고 올라가거나(사자) 내려가는(팔자) 공격이다.
## power는 '표준 호가 잔량 몇 칸 분량'이라서 상대가 벽을 두껍게 쌓아 두면 덜 나간다.

var pattern: int
## 한 번 칠 때 쓰는 물량 (표준 잔량 칸 수).
var power: float
## 몇 분(틱)에 걸쳐 연속으로 치는지.
var waves: int
## 발동할 때 우리 편 최우선 호가에 쌓는 벽 (표준 잔량 칸 수).
var wall: float
## 발동할 때 시장 심리가 우리 편으로 움직이는 정도 (0~1).
var morale: float
## 한 줄 효과 설명.
var effect: String

static var _all: Array = []

const P := ChartPatterns.Pattern


func _init(p_pattern: int, p_power: float, p_effect: String, p_waves := 1, p_wall := 0.0, p_morale := 0.0) -> void:
	pattern = p_pattern
	power = p_power
	effect = p_effect
	waves = p_waves
	wall = p_wall
	morale = p_morale


## 패턴 이름 (적삼병, 골든크로스 ...)
var name: String:
	get:
		return ChartPatterns.label(pattern)


func faction() -> int:
	return ChartPatterns.faction(pattern)


## 스킬 등급: 패턴이 크고 드물수록 세다.
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
			Skill.new(P.BULLISH_ENGULFING, 6, "매도 호가를 한 번에 친다", 1, 0, 0.12),
			Skill.new(P.HAMMER, 3, "매수벽을 세우고 받아친다", 1, 6, 0.08),
			Skill.new(P.THREE_WHITE_SOLDIERS, 4, "3분 동안 연달아 올려 친다", 3, 0, 0.15),
			Skill.new(P.GOLDEN_CROSS, 10, "매도 호가를 뚫고 올라간다", 1, 0, 0.25),
			Skill.new(P.DOUBLE_BOTTOM, 11, "바닥에 벽을 치고 크게 올려 친다", 1, 5, 0.25),
			Skill.new(P.INVERSE_HEAD_AND_SHOULDERS, 9, "두 번 연달아 크게 올려 친다", 2, 0, 0.35),
			Skill.new(P.BEARISH_ENGULFING, 6, "매수 호가를 한 번에 친다", 1, 0, 0.12),
			Skill.new(P.SHOOTING_STAR, 3, "매도벽을 세우고 내리찍는다", 1, 6, 0.08),
			Skill.new(P.THREE_BLACK_CROWS, 4, "3분 동안 연달아 내려 친다", 3, 0, 0.15),
			Skill.new(P.DEAD_CROSS, 10, "매수 호가를 뚫고 내려간다", 1, 0, 0.25),
			Skill.new(P.DOUBLE_TOP, 11, "천장에 벽을 치고 크게 내려 친다", 1, 5, 0.25),
			Skill.new(P.HEAD_AND_SHOULDERS, 9, "두 번 연달아 크게 내려 친다", 2, 0, 0.35),
		]
	return _all
