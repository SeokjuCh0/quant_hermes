"""
표준 알고리즘이 '그냥 보유'보다 나은지 미국주식+BTC에서 본다.
전략: SMA 20/50 골든크로스 매수 / 데드크로스 청산 (추세추종).
같은 코드가 주식(SPY)과 크립토(BTC-USD) 둘 다에 돌아간다.
실행: /Users/sj/dev/quant/bt/.venv/bin/python run_backtest.py
"""
import warnings
warnings.filterwarnings("ignore")

import yfinance as yf
from backtesting import Backtest, Strategy
from backtesting.lib import crossover
from backtesting.test import SMA


class SmaCross(Strategy):
    n1 = 20   # 단기 이평
    n2 = 50   # 장기 이평

    def init(self):
        close = self.data.Close
        self.sma1 = self.I(SMA, close, self.n1)
        self.sma2 = self.I(SMA, close, self.n2)

    def next(self):
        if crossover(self.sma1, self.sma2):      # 골든크로스 → 매수
            self.buy()
        elif crossover(self.sma2, self.sma1):     # 데드크로스 → 청산
            self.position.close()


def load(symbol: str, start="2019-01-01"):
    df = yf.Ticker(symbol).history(start=start, auto_adjust=True)
    df = df[["Open", "High", "Low", "Close", "Volume"]].dropna()
    return df


TARGETS = [("테슬라 TSLA", "TSLA"), ("엔비디아 NVDA", "NVDA"),
           ("팔란티어 PLTR", "PLTR"), ("비트코인 BTC-USD", "BTC-USD")]

for label, sym in TARGETS:
    df = load(sym)
    bt = Backtest(df, SmaCross, cash=10_000, commission=0.001)  # 수수료 0.1% 반영
    s = bt.run()
    print("=" * 56)
    print(f"{label}   ({df.index[0].date()} ~ {df.index[-1].date()}, {len(df)}일봉)")
    print(f"  전략 수익률 (SMA크로스) : {s['Return [%]']:>8.1f}%")
    print(f"  그냥 보유 (Buy & Hold)  : {s['Buy & Hold Return [%]']:>8.1f}%   <- 비교 기준")
    print(f"  Sharpe                 : {s['Sharpe Ratio']:>8.2f}")
    print(f"  최대낙폭 (MDD)         : {s['Max. Drawdown [%]']:>8.1f}%")
    print(f"  거래수 / 승률           : {s['# Trades']:>4} 회 / {s['Win Rate [%]']:.0f}%")
    out = f"/Users/sj/dev/quant/bt/plot_{sym.replace('-', '_')}.html"
    bt.plot(filename=out, open_browser=False)
    print(f"  차트 HTML              : {out}")

print("=" * 56)
print("판정: '전략 수익률'이 '그냥 보유'보다 높아야 알고리즘이 의미 있는 것.")
