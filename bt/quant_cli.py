"""
quant_cli.py — hermes 에이전트가 shell로 호출하는 퀀트 분석 CLI.

미국주식 + BTC, 저빈도 추세추종(SMA 골든/데드 크로스) 기준으로
"전략이 그냥 보유보다 나은가"를 숫자로 답한다.

실행:
  /Users/sj/dev/quant/bt/.venv/bin/python /Users/sj/dev/quant/bt/quant_cli.py <subcommand> [opts]

서브커맨드:
  backtest --symbol SYM [--rule sma] [--n1 20] [--n2 50] [--start 2019-01-01] [--plot]
  signal   --symbol SYM [--n1 20] [--n2 50] [--start 2019-01-01]
  compare  --symbol SYM [--n1 20] [--n2 50] [--start 2019-01-01]

심볼 규칙: 미국주식=티커(NVDA), 크립토=XXX-USD(BTC-USD).

run_backtest.py 의 SmaCross / load 로직을 그대로 복사해 재사용한다.
(run_backtest.py 는 모듈 레벨에서 백테스트를 실행하므로 import 하지 않는다.)
"""
import argparse
import os
import sys
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
        if crossover(self.sma1, self.sma2):       # 골든크로스 -> 매수
            self.buy()
        elif crossover(self.sma2, self.sma1):      # 데드크로스 -> 청산
            self.position.close()


def load(symbol: str, start="2019-01-01"):
    df = yf.Ticker(symbol).history(start=start, auto_adjust=True)
    df = df[["Open", "High", "Low", "Close", "Volume"]].dropna()
    return df


def _die(msg: str, code: int = 1):
    """친절한 에러 메시지 + 비정상 종료."""
    print(f"[에러] {msg}", file=sys.stderr)
    sys.exit(code)


def _guarded_load(symbol: str, start: str):
    """심볼 로딩 실패를 사람이 읽는 에러로 변환."""
    try:
        df = load(symbol, start=start)
    except Exception as e:
        _die(
            f"'{symbol}' 데이터를 가져오지 못했습니다 ({e}). "
            "미국주식은 티커(NVDA), 크립토는 XXX-USD(BTC-USD) 형식인지 확인하세요."
        )
    if df is None or len(df) == 0:
        _die(
            f"'{symbol}' 에 대한 가격 데이터가 비어 있습니다. "
            "심볼 철자를 확인하세요 (미국주식=NVDA, 크립토=BTC-USD)."
        )
    return df


def _run_backtest(df, n1: int, n2: int):
    class _S(SmaCross):
        pass
    _S.n1 = n1
    _S.n2 = n2
    bt = Backtest(df, _S, cash=10_000, commission=0.001)  # 수수료 0.1% 반영
    return bt, bt.run()


def cmd_backtest(args):
    if args.rule != "sma":
        _die(f"지원하지 않는 전략 규칙입니다: '{args.rule}' (현재 'sma'만 지원).")
    if args.n1 >= args.n2:
        _die(f"--n1({args.n1}) 은 --n2({args.n2}) 보다 작아야 합니다 (단기 < 장기).")

    df = _guarded_load(args.symbol, args.start)
    bt, s = _run_backtest(df, args.n1, args.n2)

    period = f"{df.index[0].date()} ~ {df.index[-1].date()}, {len(df)}일봉"
    print("=" * 56)
    print(f"{args.symbol}   ({period})")
    print(f"  전략: SMA {args.n1}/{args.n2} 골든·데드 크로스 추세추종, 수수료 0.1% 반영")
    print(f"  전략 수익률 (SMA크로스) : {s['Return [%]']:>8.1f}%")
    print(f"  그냥 보유 (Buy & Hold)  : {s['Buy & Hold Return [%]']:>8.1f}%   <- 비교 기준")
    print(f"  Sharpe                 : {s['Sharpe Ratio']:>8.2f}")
    print(f"  최대낙폭 (MDD)         : {s['Max. Drawdown [%]']:>8.1f}%")
    n_trades = int(s['# Trades'])
    wr = s['Win Rate [%]']
    wr_str = "N/A" if wr != wr else f"{wr:.0f}%"   # 거래 0회면 NaN -> N/A
    print(f"  거래수 / 승률           : {n_trades:>4} 회 / {wr_str}")

    strat = s["Return [%]"]
    bh = s["Buy & Hold Return [%]"]
    verdict = "전략이 보유보다 나음" if strat > bh else "전략이 보유보다 못함 (그냥 보유가 유리)"
    print(f"  판정                   : {verdict}")

    if args.plot:
        out = os.path.join(os.path.dirname(os.path.abspath(__file__)), f"plot_{args.symbol.replace('-', '_')}.html")
        bt.plot(filename=out, open_browser=False)
        print(f"  차트 HTML              : {out}")
    print("=" * 56)


def cmd_signal(args):
    if args.n1 >= args.n2:
        _die(f"--n1({args.n1}) 은 --n2({args.n2}) 보다 작아야 합니다 (단기 < 장기).")

    df = _guarded_load(args.symbol, args.start)
    if len(df) < args.n2:
        _die(
            f"데이터가 {len(df)}일봉뿐이라 SMA{args.n2} 를 계산할 수 없습니다. "
            "--start 를 더 과거로 잡으세요."
        )

    close = df["Close"]
    sma1 = close.rolling(args.n1).mean()
    sma2 = close.rolling(args.n2).mean()
    diff = (sma1 - sma2).dropna()

    sign = (diff > 0)
    state = "골든크로스 상태 (단기>장기, 상승추세)" if bool(sign.iloc[-1]) else \
            "데드크로스 상태 (단기<장기, 하락추세)"

    # 마지막 부호 전환(크로스) 지점 찾기
    flips = sign.ne(sign.shift())
    flips.iloc[0] = False  # 첫 값은 전환이 아님
    flip_idxs = flips[flips].index
    last_cross_date = flip_idxs[-1].date() if len(flip_idxs) else None
    cross_today = bool(len(flip_idxs)) and flip_idxs[-1] == diff.index[-1]

    if cross_today:
        kind = "골든크로스(매수)" if bool(sign.iloc[-1]) else "데드크로스(청산)"
        today_signal = f"오늘 새 신호 발생: {kind}"
    else:
        today_signal = "오늘 새 신호 없음 (기존 추세 유지)"

    last_dt = df.index[-1].date()
    print("=" * 56)
    print(f"{args.symbol}   현재 신호 (기준일 {last_dt})")
    print(f"  종가                   : {close.iloc[-1]:>12.2f}")
    print(f"  SMA{args.n1:<3}                : {sma1.iloc[-1]:>12.2f}")
    print(f"  SMA{args.n2:<3}                : {sma2.iloc[-1]:>12.2f}")
    print(f"  상태                   : {state}")
    if last_cross_date:
        print(f"  마지막 크로스 날짜     : {last_cross_date}")
    else:
        print(f"  마지막 크로스 날짜     : (관측 구간 내 전환 없음)")
    print(f"  오늘 신호              : {today_signal}")
    print("=" * 56)


def cmd_compare(args):
    if args.n1 >= args.n2:
        _die(f"--n1({args.n1}) 은 --n2({args.n2}) 보다 작아야 합니다 (단기 < 장기).")

    df = _guarded_load(args.symbol, args.start)
    _bt, s = _run_backtest(df, args.n1, args.n2)
    strat = s["Return [%]"]
    bh = s["Buy & Hold Return [%]"]
    winner = "전략 승" if strat > bh else "보유 승"
    print(
        f"{args.symbol}: 전략(SMA{args.n1}/{args.n2}) {strat:.1f}% vs 보유 {bh:.1f}% "
        f"-> {winner}  ({df.index[0].date()}~{df.index[-1].date()})"
    )


def build_parser():
    p = argparse.ArgumentParser(
        prog="quant_cli.py",
        description="미국주식+BTC SMA 추세추종 백테스트/신호 CLI",
    )
    sub = p.add_subparsers(dest="cmd", required=True)

    def add_common(sp):
        sp.add_argument("--symbol", required=True,
                        help="미국주식=티커(NVDA), 크립토=XXX-USD(BTC-USD)")
        sp.add_argument("--n1", type=int, default=20, help="단기 SMA 기간 (기본 20)")
        sp.add_argument("--n2", type=int, default=50, help="장기 SMA 기간 (기본 50)")
        sp.add_argument("--start", default="2019-01-01", help="시작일 YYYY-MM-DD")

    bp = sub.add_parser("backtest", help="전략 vs 보유 전체 성과")
    add_common(bp)
    bp.add_argument("--rule", default="sma", help="전략 규칙 (현재 'sma'만)")
    bp.add_argument("--plot", action="store_true", help="차트 HTML 저장")
    bp.set_defaults(func=cmd_backtest)

    sp = sub.add_parser("signal", help="현재 SMA 상태/마지막 크로스/오늘 신호")
    add_common(sp)
    sp.set_defaults(func=cmd_signal)

    cp = sub.add_parser("compare", help="전략 vs 보유 한 줄 비교")
    add_common(cp)
    cp.set_defaults(func=cmd_compare)

    return p


def main():
    args = build_parser().parse_args()
    if args.n1 <= 0 or args.n2 <= 0:
        _die("SMA 기간(--n1, --n2)은 양의 정수여야 합니다.")
    args.func(args)


if __name__ == "__main__":
    main()
