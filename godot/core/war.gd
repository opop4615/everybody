class_name War
## 호가창 전쟁의 두 진영.

enum Faction { BULL, BEAR }

## 어느 진영 편도 아님.
const NEUTRAL := -1


static func label(faction: int) -> String:
	return "매수군" if faction == Faction.BULL else "매도군"


static func force(faction: int) -> String:
	return "매수세" if faction == Faction.BULL else "매도세"


static func enemy(faction: int) -> int:
	return Faction.BEAR if faction == Faction.BULL else Faction.BULL


## 이 진영이 공격(시장가)할 때 내는 주문 방향.
static func attack_side(faction: int) -> int:
	return OrderBook.Side.BUY if faction == Faction.BULL else OrderBook.Side.SELL


## 가격이 이 진영에 유리하게 움직이는 방향 (+1 위, -1 아래).
static func direction(faction: int) -> int:
	return 1 if faction == Faction.BULL else -1


## 주문 방향이 어느 진영의 공격인지.
static func of_side(side: int) -> int:
	return Faction.BULL if side == OrderBook.Side.BUY else Faction.BEAR
