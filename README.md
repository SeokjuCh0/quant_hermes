# quant_hermes

개인용 퀀트 **리서치 + Q&A/알림 어시스턴트** harness. "종목 추세를 묻고, 룰을 백테스트로 검증하고, 기준이 오면 알림 받는" 것이 목표. 실거래 자동매매·배포 아님(혼자 씀).

> 권위 있는 설계 문서는 **[`SPEC.md`](SPEC.md)** 하나다. 구조·인터페이스·결정이 바뀌면 SPEC.md를 **같은 커밋에서** 갱신한다. (옛 상세 설계는 [`ARCHITECTURE.md`](ARCHITECTURE.md) — 일부 과거 방향 포함, 현재 기준은 SPEC.md.)

## 무엇인가 (한 줄)
`backtesting.py`(리서치 엔진) + `quant_cli.py`(에이전트가 호출하는 도구) + hermes 스킬(harness) → **hermes 에이전트가 질문받으면 실제 백테스트를 돌려 숫자로 답한다.**

## 개발 ≠ 실행 (핵심 분리)
```
[개발] Claude Code / Codex 로 작성  →  [형상관리] GitHub(이 레포)  →  [실행] hermes 가 로드·실행 (Discord/터미널)
```
hermes 안에서 코딩하지 않는다. 코드는 여기서 짜고 커밋, hermes는 `deploy.sh`가 프로필로 **복사해** 실행만 한다 (symlink 아님 — `__QUANT_DIR__`를 클론 경로로 치환).

## 구조
```
quant_hermes/
├── SPEC.md                 # 권위 설계 문서 (단일 기준)
├── ARCHITECTURE.md         # 상세/과거 설계 (참고)
├── bt/                     # 퀀트 엔진 (모든 봇 공유)
│   ├── quant_cli.py        # 에이전트 호출용 CLI (backtest/signal/compare)
│   ├── run_backtest.py     # 종목 묶음 SMA 백테스트 (참고/탐색용)
│   └── .venv/              # backtesting.py·yfinance (gitignore)
├── personas/               # 봇 1개 = 폴더 1개 (= hermes 프로필 1개)
│   └── magalyang/          # 마갈량 (템플릿 — 새 봇은 이 폴더 복사)
│       ├── SOUL.md         # 페르소나 코어 (가끔 수정 → 재시작 필요)
│       ├── bot.conf        # profile · model · provider
│       └── skills/quant-analyst/   # SKILL.md (+references) — 다듬는 로직 (→ /reload-skills 로 라이브 갱신)
├── deploy.sh               # bash deploy.sh <persona> → 프로필로 배포 + 재시작
└── setup.sh                # 새 머신 첫 부트스트랩 (venv·SSL인증서·의존성)
```

## 빠른 사용 (도구 직접)
```bash
bt/.venv/bin/python bt/quant_cli.py backtest --symbol NVDA     # 전략 vs 보유 성과
bt/.venv/bin/python bt/quant_cli.py signal   --symbol BTC-USD  # 현재 SMA 신호
bt/.venv/bin/python bt/run_backtest.py                         # 종목 묶음 일괄
```

## 봇 배포 + 라이브 반복
```bash
bash deploy.sh magalyang     # personas/magalyang → ~/.hermes/profiles/magalyang 배포 + 게이트웨이 재시작
```
- **라이브 튜닝 루프**: 봇 돌려놓고 → `personas/<봇>/skills/**/SKILL.md` 수정 → 디스코드에서 **`/reload-skills`** → 다음 메시지부터 적용(재시작 불필요). **자주 바꾸는 로직은 SKILL.md에** 둔다.
- **SOUL.md(페르소나 코어)·모델 변경**은 `bash deploy.sh <봇>` (재시작 포함).
- **새 봇 추가**: `personas/magalyang/`를 `personas/<새이름>/`로 복사 → `SOUL.md`·`bot.conf`(model/provider) 수정 → 그 프로필 `.env`에 새 봇 `DISCORD_BOT_TOKEN` → `bash deploy.sh <새이름>`. (봇마다 모델 다르게 두면 토론 다양성 ↑)

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
   - ⚠️ **친구 전원이 응답받게 하려면 `DISCORD_ALLOWED_USERS`를 절대 채우지 말고 비워 둔다.** 이게 설정되면 Discord 어댑터 선필터(`platforms/discord.py`의 `_is_allowed_user`)가 그 ID들만 통과시키고 나머지 메시지는 *수신 단계에서* 버린다(로그에도 안 남음). 이 선필터는 `DISCORD_ALLOW_ALL_USERS`·`GATEWAY_ALLOW_ALL_USERS`를 **보지 않으므로** allow-all 플래그로 못 뚫는다. 개방은 *빈 allowlist + `GATEWAY_ALLOW_ALL_USERS=true`* 조합으로만 된다. `hermes gateway setup` 마법사가 allowed users를 물으면 **빈 채로** 둔다.

**이식성**: 스킬은 `__QUANT_DIR__` placeholder, `setup.sh`가 클론 위치로 치환. quant_cli 차트 출력도 스크립트 상대경로(`__file__`).
