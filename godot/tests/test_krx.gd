extends TestCase


func test_tick_size_by_band() -> void:
	eq(Krx.tick_size(1999), 1)
	eq(Krx.tick_size(2000), 5)
	eq(Krx.tick_size(12000), 10)
	eq(Krx.tick_size(23400), 50)
	eq(Krx.tick_size(96000), 100)
	eq(Krx.tick_size(250000), 500)
	eq(Krx.tick_size(700000), 1000)


func test_ticks_across_band_boundary() -> void:
	eq(Krx.next_tick(19990), 20000)
	eq(Krx.next_tick(20000), 20050)
	eq(Krx.prev_tick(20000), 19990)
	eq(Krx.prev_tick(2000), 1999)
	eq(Krx.shift_ticks(19980, 3), 20050)
	eq(Krx.ticks_between(19980, 20050), 3)
	eq(Krx.ticks_between(20050, 19980), -3)


func test_round_to_tick() -> void:
	eq(Krx.floor_to_tick(12345), 12340)
	eq(Krx.ceil_to_tick(12345), 12350)
	eq(Krx.ceil_to_tick(19995), 20000)
	eq(Krx.ceil_to_tick(12340), 12340)


func test_price_limits() -> void:
	eq(Krx.upper_limit(12000), 15600)
	eq(Krx.lower_limit(12000), 8400)
	eq(Krx.upper_limit(3150), 4095)
	eq(Krx.lower_limit(3150), 2205)
	eq(Krx.upper_limit(23400), 30400)
	eq(Krx.lower_limit(23400), 16380)


func test_formatting() -> void:
	eq(Krx.format_number(0), "0")
	eq(Krx.format_number(999), "999")
	eq(Krx.format_number(1234567), "1,234,567")
	eq(Krx.format_number(-45000), "-45,000")
	eq(Krx.signed_percent(0.0123), "+1.23%")
	eq(Krx.compact_won(340000000), "3.4억")
	eq(Krx.compact_won(52000000), "5,200만")
