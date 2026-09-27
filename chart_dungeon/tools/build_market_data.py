#!/usr/bin/env python3
"""게임에 쓰는 일별 시세 CSV를 만든다.

    python3 tools/build_market_data.py            # 원본을 내려받아 data/market/*.csv 생성
    python3 tools/build_market_data.py --offline  # data/raw/에 있는 원본만 쓴다

출력 형식 (data/market/<상품>.csv):
    date,open,high,low,close,est
    est=1 이면 시가·고가·저가가 종가로 추정한 값이다.

원본
  usdkrw  미 연준 H.10 원/달러 (뉴욕 정오 기준, 종가만)  datasets/exchange-rates
  wti     미 에너지정보청 WTI 쿠싱 현물 (종가만)          datasets/oil-prices
  gold    XAUUSD 일봉 (MT4, 시가·고가·저가·종가)          ejtraderLabs/historical-data

거래소 CSV(시가·고가·저가·종가가 다 있는 것)는 tools/import_ohlc_csv.py로 바꿔 넣는다.
"""

import csv
import datetime as dt
import hashlib
import io
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "data", "raw")
OUT = os.path.join(ROOT, "data", "market")
START = dt.date(2019, 9, 2)
END = dt.date(2020, 12, 31)

SOURCES = {
    "fx_daily.csv": "https://raw.githubusercontent.com/datasets/exchange-rates/main/data/daily.csv",
    "wti_daily.csv": "https://raw.githubusercontent.com/datasets/oil-prices/main/data/wti-daily.csv",
    "xau_d1.csv": "https://raw.githubusercontent.com/ejtraderLabs/historical-data/main/XAUUSD/XAUUSDd1.csv",
}


def fetch(name, offline):
    path = os.path.join(RAW, name)
    if not os.path.exists(path):
        if offline:
            sys.exit(f"{path} 가 없다")
        os.makedirs(RAW, exist_ok=True)
        print("내려받는 중", SOURCES[name])
        with urllib.request.urlopen(SOURCES[name], timeout=60) as response:
            data = response.read()
        with open(path, "wb") as f:
            f.write(data)
    with open(path, encoding="utf-8") as f:
        return f.read()


def in_range(day):
    return START <= day <= END and day.weekday() < 5


def unit(seed, salt):
    digest = hashlib.sha256(f"{seed}:{salt}".encode()).digest()
    return int.from_bytes(digest[:4], "big") / 0xFFFFFFFF


def estimate(closes, digits):
    """종가만 있는 계열에 시가·고가·저가를 붙인다. 날짜마다 같은 값이 나오도록 해시로 흔든다."""
    rows = []
    moves = []
    prev = None
    for day, close in closes:
        if prev is None:
            prev = close
            continue
        move = close - prev
        recent = moves[-10:] or [abs(move) or abs(close) * 0.005]
        typical = max(sum(abs(m) for m in recent) / len(recent), abs(close) * 0.002)
        seed = day.isoformat()
        opening = prev + move * unit(seed, "gap") * 0.35
        top, bottom = max(opening, close), min(opening, close)
        high = top + typical * (0.1 + 0.5 * unit(seed, "high"))
        low = bottom - typical * (0.1 + 0.5 * unit(seed, "low"))
        rows.append((day, round(opening, digits), round(high, digits), round(low, digits), round(close, digits), 1))
        moves.append(move)
        prev = close
    return rows


def build_usdkrw(offline):
    closes = []
    for row in csv.DictReader(io.StringIO(fetch("fx_daily.csv", offline))):
        if row["Country"] != "South Korea" or not row["Exchange rate"]:
            continue
        day = dt.date.fromisoformat(row["Date"])
        if in_range(day):
            closes.append((day, float(row["Exchange rate"])))
    return estimate(closes, 2)


# 추정 대신 실제 장중 흐름을 따르는 날.
# 2020-04-20 WTI 5월물: 17.73에서 시작해 장중 -40.32까지 밀리고 -37.63에 정산했다
# (미 의회조사국 IN11354, 미 에너지정보청 Today in Energy 43495).
# 현물 계열(전일 18.31, 당일 -36.98)에 맞춰 시가는 전일 대비 같은 폭(-0.54), 저가는 종가 대비 같은 폭(-2.69)으로 옮긴다.
WTI_SESSIONS = {
    "2020-04-20": {"open_from_prev": 17.73 - 18.27, "low_from_close": -40.32 - (-37.63)},
}


def build_wti(offline):
    closes = []
    for row in csv.reader(io.StringIO(fetch("wti_daily.csv", offline))):
        if not row or row[0] == "Date" or not row[1]:
            continue
        day = dt.date.fromisoformat(row[0])
        if in_range(day):
            closes.append((day, float(row[1])))
    rows = estimate(closes, 2)
    for i, row in enumerate(rows):
        session = WTI_SESSIONS.get(row[0].isoformat())
        if session and i > 0:
            prev_close = rows[i - 1][4]
            opening = round(prev_close + session["open_from_prev"], 2)
            low = round(row[4] + session["low_from_close"], 2)
            rows[i] = (row[0], opening, opening, low, row[4], 1)
    return rows


def build_gold(offline):
    rows = []
    for row in csv.DictReader(io.StringIO(fetch("xau_d1.csv", offline))):
        day = dt.date.fromisoformat(row["Date"][:10])
        if in_range(day):
            o, h, l, c = (float(row[k]) / 100.0 for k in ("open", "high", "low", "close"))
            rows.append((day, round(o, 2), round(h, 2), round(l, 2), round(c, 2), 0))
    return rows


def write(name, rows):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".csv")
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["date", "open", "high", "low", "close", "est"])
        for row in rows:
            writer.writerow([row[0].isoformat(), *row[1:]])
    print(f"{path}: {len(rows)}일")


def main():
    offline = "--offline" in sys.argv
    write("usdkrw", build_usdkrw(offline))
    write("wti", build_wti(offline))
    write("gold", build_gold(offline))


if __name__ == "__main__":
    main()
