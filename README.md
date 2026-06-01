# quant_hermes

개인용 퀀트 **리서치 + Q&A/알림 어시스턴트** harness. "종목 추세를 묻고, 룰을 백테스트로 검증하고, 기준이 오면 알림 받는" 것이 목표. 실거래 자동매매·배포 아님(혼자 씀).

> 권위 있는 설계 문서는 **[`SPEC.md`](SPEC.md)** 하나다. 구조·인터페이스·결정이 바뀌면 SPEC.md를 **같은 커밋에서** 갱신한다. (옛 상세 설계는 [`ARCHITECTURE.md`](ARCHITECTURE.md) — 일부 과거 방향 포함, 현재 기준은 SPEC.md.)

## 무엇인가 (한 줄)
`backtesting.py`(리서치 엔진) + `quant_cli.py`(에이전트가 호출하는 도구) + hermes 스킬(harness) → **hermes 에이전트가 질문받으면 실제 백테스트를 돌려 숫자로 답한다.**

## 개발 ≠ 실행 (핵심 분리)
```
[개발] Claude Code / Codex 로 작성  →  [형상관리] GitHub(이 레포)  →  [실행] hermes 가 로드·실행 (Discord/터미널)
```
hermes 안에서 코딩하지 않는다. 코드는 여기서 짜고 커밋, hermes는 symlink로 로드해 실행만.

## 구조
```
quant_hermes/
├── SPEC.md                 # 권위 설계 문서 (단일 기준)
├── ARCHITECTURE.md         # 상세/과거 설계 (참고)
├── bt/
│   ├── run_backtest.py     # 종목 묶음 SMA 백테스트 (참고/탐색용)
│   └── quant_cli.py        # 에이전트 호출용 CLI (backtest/signal/compare)  [harness 생성 후]
│   └── .venv/              # backtesting.py·yfinance (gitignore)
└── hermes/
    └── skills/quant-analyst/SKILL.md   # hermes harness 스킬  [harness 생성 후]
```

## 빠른 사용 (도구 직접)
```bash
bt/.venv/bin/python bt/run_backtest.py            # 현재 종목들 SMA 백테스트
# (harness 생성 후) bt/.venv/bin/python bt/quant_cli.py backtest --symbol NVDA
```

## 대상 종목 / 룰
- 종목: 미국주식(TSLA, NVDA, PLTR …) + 크립토(BTC-USD)
- 현재 룰: SMA 20/50 추세 크로스 (데모 — 백테스트상 buy&hold에 짐. 룰 개선은 진행 중)

## 다른 노트북에서 재현 (Harness)

새 머신에서 마갈량(quant + hermes)을 똑같이 띄우기:

1. **hermes 설치** (없으면): `pip install hermes-agent && hermes setup`
2. **클론 + 부트스트랩**:
   ```bash
   git clone https://github.com/SeokjuCh0/quant_hermes
   cd quant_hermes && bash setup.sh
   ```
   `setup.sh`가 자동으로: bt venv+의존성, macOS SSL 인증서, quant-analyst 스킬·SOUL(마갈량) 배치(`__QUANT_DIR__`→클론경로 치환), hermes config(모델 sonnet-4-5·디스코드·curl허용) 적용.
3. **수동(시크릿/계정)**: `hermes model`(anthropic 로그인) → `~/.hermes/.env`에 `DISCORD_BOT_TOKEN=…` + `GATEWAY_ALLOW_ALL_USERS=true` → `hermes gateway setup` → `hermes gateway start`.

**이식성**: 스킬은 `__QUANT_DIR__` placeholder, `setup.sh`가 클론 위치로 치환. quant_cli 차트 출력도 스크립트 상대경로(`__file__`).
