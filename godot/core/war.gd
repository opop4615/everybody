class_name War
## 두 편. 사자(매수)와 팔자(매도).

enum Faction { BULL, BEAR }

## 어느 편도 아님.
const NEUTRAL := -1


## 편 이름: 사자 / 팔자.
static func label(faction: int) -> String:
	return "사자" if faction == Faction.BULL else "팔자"


## 시장 용어: 매수세 / 매도세.
static func force(faction: int) -> String:
	return "매수세" if faction == Faction.BULL else "매도세"


static func enemy(faction: int) -> int:
	return Faction.BEAR if faction == Faction.BULL else Faction.BULL


## 이 편이 공격(시장가)할 때 내는 주문 방향.
static func attack_side(faction: int) -> int:
	return OrderBook.Side.BUY if faction == Faction.BULL else OrderBook.Side.SELL


## 가격이 이 편에 유리하게 움직이는 방향 (+1 위, -1 아래).
static func direction(faction: int) -> int:
	return 1 if faction == Faction.BULL else -1


## 주문 방향이 어느 편의 공격인지.
static func of_side(side: int) -> int:
	return Faction.BULL if side == OrderBook.Side.BUY else Faction.BEAR
