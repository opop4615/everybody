extends TestCase
## 포지션 계산과 주문.


func test_add_and_close_long() -> void:
	var p := Position.new()
	eq(p.fill(3, 100.0, 1.0), 0.0, "처음 사면 실현 손익 없음")
	p.fill(2, 110.0, 1.0)
	eq(p.qty, 5)
	check(is_equal_approx(p.avg, 104.0), "평단 104")
	var realized := p.fill(-2, 120.0, 1.0)
	check(is_equal_approx(realized, 32.0), "2계약 × 16 = 32, 실제 %s" % realized)
	eq(p.qty, 3)


func test_flip_to_short() -> void:
	var p := Position.new()
	p.fill(2, 50.0, 10.0)
	var realized := p.fill(-5, 45.0, 10.0)
	check(is_equal_approx(realized, -100.0), "2계약 × -5 × 10")
	eq(p.qty, -3)
	check(is_equal_approx(p.avg, 45.0), "남은 숏은 45에서 시작")


func test_settlement_moves_basis() -> void:
	var p := Position.new()
	p.fill(4, 1238.0, 1.0)
	check(is_equal_approx(p.settle(1245.7, 1.0), 30.8), "4계약 × 7.7")
	check(is_equal_approx(p.basis, 1245.7), "정산 뒤 basis 는 종가")
	check(is_equal_approx(p.avg, 1238.0), "평단은 그대로")
	check(is_equal_approx(p.fill(-4, 1295.0, 1.0), 197.2), "오늘 손익은 정산가부터")


func test_orders_cross() -> void:
	var stop := Order.stop(1, 95.0)
	check(stop.crossed(100.0, 90.0), "롱 손절은 내려갈 때 닿는다")
	check(not stop.crossed(90.0, 100.0), "올라갈 때는 아니다")
	check(stop.hit_at(94.0), "시가가 이미 아래면 갭")
	var take := Order.take(-1, 80.0)
	check(take.crossed(90.0, 79.0), "숏 익절은 내려갈 때")
	var trail := Order.trailing(1, 100.0, 5.0)
	trail.follow(110.0)
	check(is_equal_approx(trail.price, 105.0), "트레일링은 고가 5 아래로 따라온다")
	trail.follow(104.0)
	check(is_equal_approx(trail.price, 105.0), "내려갈 때는 그대로")
