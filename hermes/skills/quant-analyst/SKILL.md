---
name: quant-analyst
description: 미국주식·BTC를 SMA 추세추종 백테스트로 분석하는 퀀트 도우미. 종목·전략·추세·매수타이밍 질문이 오면 quant_cli.py 를 실제 실행해 그 출력 숫자로만 답한다. "NVDA 전략 어때", "비트코인 지금 신호", "이 종목 그냥 들고 있는 게 나아?" 같은 질문에 사용.
version: 1.0.0
author: sj
license: MIT
platforms: [macos]
metadata:
  hermes:
    tags: [quant, backtesting, stocks, crypto, trend-following, sma, finance]
---

# Quant Analyst

## What this skill does

`/Users/sj/dev/quant/bt/quant_cli.py` 를 bt venv 파이썬으로 실행해서, 미국주식과 BTC에 대해
**SMA 골든/데드 크로스 추세추종 전략**이 "그냥 보유(Buy & Hold)"보다 나은지를 숫자로 보여준다.

- `backtest`: 전략 수익률 vs 보유 수익률, Sharpe, 최대낙폭(MDD), 거래수/승률, 판정
- `signal`: 현재 SMA20/SMA50 값, 골든/데드 상태, 마지막 크로스 날짜, 오늘 신호 여부
- `compare`: 전략 vs 보유 한 줄 비교

이 스킬의 핵심 규율: **숫자는 절대 지어내지 않는다. 반드시 CLI를 실제 실행하고 그 출력만 인용한다.**

## When to use

- "NVDA 추세 어때? 사도 돼?"
- "비트코인 지금 골든크로스야 데드크로스야?"
- "테슬라는 SMA 전략이 그냥 보유보다 나아?"
- "이 종목 백테스트 돌려줘 / 차트 보여줘"
- "지금 들어가도 되는 타이밍이야?" (→ signal 로 현재 신호 확인)

질문이 종목·전략·추세·매수타이밍에 관한 것이면 이 스킬을 쓴다. 추측하지 말고 CLI를 돌린다.

## Prerequisites

- bt venv 파이썬: `/Users/sj/dev/quant/bt/.venv/bin/python` (backtesting.py·yfinance·pandas 설치됨. 차트는 bokeh 백엔드 사용)
- CLI: `/Users/sj/dev/quant/bt/quant_cli.py`
- 네트워크 필요 (yfinance 가 가격을 실시간으로 받아온다)

## 심볼 규칙

- 미국주식: 티커 그대로 — `NVDA`, `TSLA`, `SPY`, `PLTR`
- 크립토: `XXX-USD` 형식 — `BTC-USD`, `ETH-USD`
- 사용자가 "비트코인", "엔비디아" 같이 말하면 위 규칙으로 변환해서 넘긴다.

## Workflow

### 0. 항상 CLI를 실제로 실행한다 (가장 중요한 규칙)

성과·신호·추세를 답하기 전에 **반드시** 아래 명령 중 하나를 shell로 실행한다.
기억·추정·일반 상식으로 수익률이나 신호를 말하지 않는다. 실행 출력이 곧 답이다.

실행 형식 (모두 절대경로):

```bash
/Users/sj/dev/quant/bt/.venv/bin/python /Users/sj/dev/quant/bt/quant_cli.py <subcommand> [opts]
```

### 1. 성과를 물으면 → `backtest`

"이 전략 어때", "수익률", "백테스트", "그냥 보유보다 나아?" 류:

```bash
/Users/sj/dev/quant/bt/.venv/bin/python /Users/sj/dev/quant/bt/quant_cli.py backtest --symbol NVDA
```

옵션: `--n1 20 --n2 50`(단기/장기 SMA), `--start 2019-01-01`(시작일), `--plot`(차트 HTML 저장), `--rule sma`(현재 sma만 지원).
차트를 원하면 `--plot` 을 붙이고 출력에 찍힌 HTML 절대경로를 사용자에게 알려준다.

### 2. 지금 매수/청산 타이밍을 물으면 → `signal`

"지금 신호", "골든크로스야?", "들어가도 돼?", "오늘 들어가도 되는 타이밍?" 류:

```bash
/Users/sj/dev/quant/bt/.venv/bin/python /Users/sj/dev/quant/bt/quant_cli.py signal --symbol BTC-USD
```

출력의 현재 SMA20/SMA50 값, 골든/데드 상태, 마지막 크로스 날짜, 오늘 신호 여부를 그대로 전한다.

### 3. 빠른 한 줄 비교를 원하면 → `compare`

"전략이 보유보다 나아?"만 빠르게:

```bash
/Users/sj/dev/quant/bt/.venv/bin/python /Users/sj/dev/quant/bt/quant_cli.py compare --symbol TSLA
```

### 4. 답변 규율 (반드시 지킬 것)

- **실제 출력 인용**: CLI가 찍은 숫자를 그대로 옮긴다. 반올림·각색·창작 금지.
- **전략 수익률은 항상 Buy & Hold와 같이 제시**한다. 전략 수익률만 단독으로 말하지 않는다.
  ("전략 841.9% vs 그냥 보유 5039.0% — 이 종목은 그냥 들고 있는 게 나았다"처럼.)
- **한 줄 한계 경고를 반드시 붙인다**: "과거 데이터 백테스트라 과최적화·거래비용·실제 미래(아웃오브샘플)에서는 결과가 다를 수 있음."
- **초보가 알아듣게 평이하게**: Sharpe·MDD 같은 용어는 한 마디로 풀어준다
  (MDD = 고점 대비 최대 하락폭, Sharpe = 위험 대비 수익 효율, 높을수록 좋음).
- 이 사용자는 **개인·비배포·초보**, 저빈도 추세추종 관점이다. 결론은 "그래서 어떻게 보면 되는지" 한 문장으로 정리한다.

### 5. 모르면 모른다고 한다

- CLI가 지원하지 않는 것(개별 종목 펀더멘털, 옵션, 뉴스, 미래 가격 예측, 매수 추천 그 자체)은
  **추측하지 말고 "이 도구로는 알 수 없다"**고 말한다.
- 이 스킬은 SMA 추세추종 백테스트/신호 조회 전용이다. 투자 자문이 아니다.

## Done when

- 질문에 해당하는 CLI 명령을 실제로 실행했다 (출력 캡처됨).
- 답변에 CLI가 찍은 실제 숫자가 인용돼 있다.
- 전략 수익률을 말했다면 그 옆에 Buy & Hold 가 같이 있다.
- 과최적화·거래비용·아웃오브샘플 한 줄 경고가 붙어 있다.
- 초보가 이해할 평이한 결론 한 문장이 있다.

## Failure modes

- **잘못된 심볼**: CLI가 친절한 에러 + 비정상 종료(exit 1). 미국주식=티커, 크립토=XXX-USD 형식으로 고쳐 다시 실행한다.
- **네트워크/yfinance 장애**: 가격을 못 받으면 에러가 난다. 이때 숫자를 지어내지 말고 "데이터를 못 받았다"고 알린다.
- **데이터 부족**: `signal` 은 SMA 장기기간(n2)보다 데이터가 짧으면 계산 불가. `--start` 를 더 과거로 잡는다.
- **n1 >= n2**: 단기 SMA 기간이 장기보다 크거나 같으면 에러. 단기 < 장기로 맞춘다.

## Notes

- 이 스킬은 조회·분석 전용이며, 매매를 대신 실행하지 않는다.
- "오늘/지금" 같은 상대 시점은 CLI 출력의 "기준일"로 확정된다 (yfinance 최신 일봉 기준).
- 기본 전략은 SMA 20/50 골든·데드 크로스, 수수료 0.1% 반영, 시작일 2019-01-01.
- 차트가 필요하면 `backtest --plot` 의 HTML 절대경로를 안내한다.
