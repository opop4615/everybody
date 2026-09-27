#!/usr/bin/env python3
"""거래소나 증권사에서 받은 일별 시세 CSV를 게임 형식으로 바꾼다.

    python3 tools/import_ohlc_csv.py <받은 파일.csv> <상품 id>
    예) python3 tools/import_ohlc_csv.py ~/Downloads/달러선물.csv usdkrw

한국거래소 정보데이터시스템에서 받은 CSV(일자·시가·고가·저가·종가, CP949)와
영문 머리글(Date, Open, High, Low, Close)을 모두 읽는다. 결과는 data/market/<상품 id>.csv
를 덮어쓰고, 시가·고가·저가가 실제 값이므로 est=0 으로 적는다.
"""

import csv
import datetime as dt
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ALIASES = {
    "date": ("date", "일자", "날짜", "거래일"),
    "open": ("open", "시가"),
    "high": ("high", "고가"),
    "low": ("low", "저가"),
    "close": ("close", "종가", "price", "현재가"),
}


def read_text(path):
    raw = open(path, "rb").read()
    for encoding in ("utf-8-sig", "cp949", "euc-kr"):
        try:
            return raw.decode(encoding)
        except UnicodeDecodeError:
            continue
    sys.exit("글자 인코딩을 알 수 없다")


def number(text):
    return float(text.replace(",", "").strip())


def parse_day(text):
    text = text.strip().replace("/", "-").replace(".", "-")
    return dt.date.fromisoformat(text[:10])


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    source, instrument = sys.argv[1], sys.argv[2]
    rows = list(csv.reader(read_text(source).splitlines()))
    header = [cell.strip().lower() for cell in rows[0]]
    columns = {}
    for key, names in ALIASES.items():
        for index, cell in enumerate(header):
            if cell in names:
                columns[key] = index
                break
        else:
            sys.exit(f"'{key}' 열을 찾지 못했다: {rows[0]}")
    out = []
    for row in rows[1:]:
        if not row or not row[columns["close"]].strip():
            continue
        out.append((parse_day(row[columns["date"]]), *(number(row[columns[k]]) for k in ("open", "high", "low", "close"))))
    out.sort()
    path = os.path.join(ROOT, "data", "market", instrument + ".csv")
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["date", "open", "high", "low", "close", "est"])
        for day, o, h, l, c in out:
            writer.writerow([day.isoformat(), o, h, l, c, 0])
    print(f"{path}: {len(out)}일")


if __name__ == "__main__":
    main()
