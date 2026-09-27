class_name Company
extends RefCounted
## 전장이 되는 가상 종목.

var name: String
var sector: String
## 전일 종가 = 오늘의 기준가.
var base_price: int


func _init(p_name: String, p_sector: String, p_base_price: int) -> void:
	name = p_name
	sector = p_sector
	base_price = p_base_price


static func roster() -> Array:
	return [
		Company.new("모두전자", "전자부품", 12000),
		Company.new("한빛바이오", "바이오", 3150),
		Company.new("새벽엔터", "엔터테인먼트", 8600),
		Company.new("파랑에너지", "2차전지", 96000),
		Company.new("누리로보틱스", "로봇", 23400),
	]
