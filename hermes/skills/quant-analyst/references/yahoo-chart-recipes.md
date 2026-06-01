# Yahoo Chart API 보조 지표 레시피

종토방/디스코드 컨텍스트에서 quant_cli가 다루지 않는 보조 지표를 빠르게 뽑을 때 사용. **SMA·백테스트·전략 판정은 절대 이걸로 하지 마라 — quant_cli만 사용한다.**

## 엔드포인트

- 무인증, 즉시 호출 가능: `https://query1.finance.yahoo.com/v8/finance/chart/<TICKER>?interval=1d&range=<RANGE>`
- range: `5d`, `1mo`, `3mo`, `6mo`, `1y`, `2y`, `5y`, `max`
- **주의**: v7 quote API (`/v7/finance/quote?symbols=...`)는 401 Unauthorized 떨어진다. chart API만 사용.

## 표준 시드

```bash
curl -s "https://query1.finance.yahoo.com/v8/finance/chart/NVDA?interval=1d&range=6mo" -H "User-Agent: Mozilla/5.0" | python3 -c "
import sys, json
d = json.load(sys.stdin)['chart']['result'][0]
m = d['meta']
closes = [c for c in d['indicators']['quote'][0]['close'] if c is not None]
vols = [v for v in d['indicators']['quote'][0]['volume'] if v is not None]
# ... 여기서 지표 계산
"
```

## 레시피

### 1. 최근 N일 OHLCV

```python
import datetime
ts = d['timestamp']; q = d['indicators']['quote'][0]
for i,t in enumerate(ts[-5:]):
    j = i + len(ts) - 5
    print(f"{datetime.datetime.fromtimestamp(t).strftime('%m-%d')}  O:{q['open'][j]:.2f} H:{q['high'][j]:.2f} L:{q['low'][j]:.2f} C:{q['close'][j]:.2f} V:{q['volume'][j]/1e6:.0f}M")
```

### 2. 이평선 + 정배열 + 200일선 쿠션

`range=1y` 필요 (MA200 계산).

```python
price = closes[-1]
ma20 = sum(closes[-20:])/20
ma50 = sum(closes[-50:])/50
ma200 = sum(closes[-200:])/200
# 정배열: MA200 < MA50 < MA20
aligned = ma200 < ma50 < ma20
# 200일선 기울기 (30일 전 MA200과 비교)
ma200_30d_ago = sum(closes[-230:-30])/200
slope_pct = (ma200/ma200_30d_ago - 1) * 100
# 200일선까지 쿠션
cushion_pct = (price/ma200 - 1) * 100
```

### 3. MACD (12/26/9)

`range=6mo` 충분 (EMA26 + signal 9일 필요).

```python
def ema(data, period):
    k = 2/(period+1)
    e = [sum(data[:period])/period]
    for p in data[period:]:
        e.append(p*k + e[-1]*(1-k))
    return e

ema12 = ema(closes, 12)
ema26 = ema(closes, 26)
offset = len(ema12) - len(ema26)
ema12_a = ema12[offset:]
macd_line = [a-b for a,b in zip(ema12_a, ema26)]
signal = ema(macd_line, 9)
macd_a = macd_line[-len(signal):]
hist = [m-s for m,s in zip(macd_a, signal)]

# 크로스 판정
if macd_a[-1] > signal[-1] and macd_a[-2] <= signal[-2]:
    cross = "🟢 골든크로스 발생 (오늘)"
elif macd_a[-1] < signal[-1] and macd_a[-2] >= signal[-2]:
    cross = "🔴 데드크로스 발생 (오늘)"
elif macd_a[-1] > signal[-1]:
    cross = "🟢 골든크로스 유지 중"
else:
    cross = "🔴 데드크로스 유지 중"

# 0선 위치 — 0선 위면 장기 강세, 아래면 약세
zero = "위 (강세)" if macd_a[-1] > 0 else "아래 (약세)"

# 골든크로스까지 며칠 추정 (히스토그램 축소 속도 기반)
if macd_a[-1] < signal[-1]:  # 데드크로스 상태
    recent_change = (hist[-1] - hist[-3]) / 2
    if recent_change > 0:
        days = abs(hist[-1]) / recent_change
        # "현 추세 유지시 골든크로스까지 약 N일"
```

### 4. 거래량 vs 평균

```python
avg_vol_20d = sum(vols[-20:])/20
today_ratio = vols[-1] / avg_vol_20d * 100
# 200% 넘으면 폭발적 거래량, 50% 미만이면 관망 분위기
```

### 5. 52주 고가/저가 위치

```python
hi = max(closes); lo = min(closes)
from_high_pct = (1 - price/hi) * 100  # 고점 대비 -X%
from_low_pct = (price/lo - 1) * 100   # 저점 대비 +X%
```

## 데이터 검증 체크리스트

- **현재가가 비상식적이면 의심하라** (예: 분할/병합으로 가격 점프). `meta.chartPreviousClose`와 비교해 +30% 이상 점프면 corporate action 가능성. `range=1mo`로 한 달 흐름 다시 보고 확인.
- **`closes`에 None이 섞일 수 있다.** 반드시 `[c for c in ... if c is not None]`로 필터.
- **거래일 기준**: yahoo는 거래일만 반환. 주말/공휴일은 없음.

## 한계

- 이 레시피는 **현재 시점 스냅샷** 답변용이다. 백테스트·전략 수익률 비교가 필요하면 quant_cli로 가야 한다.
- 옵션·펀더멘털·뉴스·실적은 이 API로 안 나온다. "이 도구로는 알 수 없다"고 답한다.
