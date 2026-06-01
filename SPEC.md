# SPEC — quant_hermes

> **단일 권위 문서.** CLI 인터페이스·스킬·아키텍처·결정이 바뀌면 이 파일을 **같은 커밋에서** 갱신한다. 코드와 SPEC이 어긋나면 그건 버그다.
> 최종 갱신: 2026-06-01 (세션 기준; 날짜는 커밋이 기록)

---

## 1. 목적 & 범위

| 항목 | 내용 |
|---|---|
| 무엇 | 개인용 퀀트 **리서치 + Q&A/알림 어시스턴트** harness |
| 사용자 | 초보, 소액, 단일 MacBook(M4 Pro 24GB), 비배포(혼자 씀) |
| 자산 | 미국주식(TSLA·NVDA·PLTR…) + 크립토(BTC-USD) — 한국주식 제외 |
| 전략 성격 | 저빈도·룰 기반 추세 진입 (틱/HFT 아님) |
| 현 단계 | **백테스트·검증 위주.** 실거래 미시행. 알림까지가 목표 |
| 비범위 | 자동매매 실행, 멀티유저, 배포, 커스텀 웹 대시보드 |

**1차 목표는 수익이 아니라** 비용·편향(look-ahead/survivorship) 반영한 검증 파이프라인과, 질문하면 실제 백테스트로 답하는 어시스턴트 구축.

## 2. 아키텍처 — 개발 ≠ 실행

```
[개발] Claude Code / Codex
   │  (코드·스킬·스펙 작성)
[형상관리] GitHub: SeokjuCh0/quant_hermes
   │  symlink: hermes/skills/quant-analyst → ~/.hermes/skills/quant/quant-analyst
[실행] hermes (전역 설치, 게이트웨이 상시가동)
   │  에이전트가 질문 받으면 quant_cli.py 실제 실행 → 숫자로 답
[인터페이스] 터미널(hermes) + Discord (멘션 대화 / cron 알림)
```

**구성 요소**
| 요소 | 역할 | 위치 |
|---|---|---|
| `backtesting.py` + `yfinance` | 리서치 엔진(백테스트·데이터) | `bt/.venv` |
| `bt/run_backtest.py` | 종목 묶음 SMA 백테스트 (탐색용) | repo |
| `bt/quant_cli.py` | **에이전트가 호출하는 도구** (backtest/signal/compare) | repo |
| `hermes/skills/quant-analyst/SKILL.md` | **harness** — 언제·어떻게 도구 쓰고 답할지 | repo → symlink |
| hermes | 런타임 (스킬 로드·실행·Discord·cron) | 전역 `~/.hermes` |

## 3. quant_cli.py 인터페이스 계약 (변경 시 SKILL.md도 동시 수정)

실행: `bt/.venv/bin/python bt/quant_cli.py <subcommand> [opts]`

| subcommand | 옵션 | 출력 |
|---|---|---|
| `backtest` | `--symbol SYM [--rule sma --n1 20 --n2 50 --start 2019-01-01 --plot]` | 전략수익률·Buy&Hold·Sharpe·MDD·거래수·승률 (한국어 텍스트). `--plot` 시 HTML 경로 |
| `signal` | `--symbol SYM [--n1 20 --n2 50]` | 현재 SMA20/50 값·골든/데드 상태·마지막 크로스 날짜·오늘 신호 여부 |
| `compare` | `--symbol SYM` | 전략 vs 보유 한 줄 비교 |

심볼 규칙: 미국주식=티커(`NVDA`), 크립토=`XXX-USD`(`BTC-USD`). 수수료 `commission=0.001` 반영. 에러는 친절히 + non-zero exit.

## 4. hermes 통합

- **스킬 경로**: repo `hermes/skills/quant-analyst/SKILL.md` 가 **단일 소스**. `bash deploy.sh` 가 `~/.hermes/skills/quant/quant-analyst` → repo 로 symlink (repo에서 고치면 hermes 즉시 반영). 현재 ~/.hermes에 작동 사본이 있어 hermes는 이미 스킬을 로드함 → `deploy.sh` 한 번 실행하면 repo 단일 소스로 통합됨.
- **Q&A(현 단계)**: 터미널 `hermes` 또는 Discord 멘션 → 에이전트가 quant_cli 실행해 답. **추가 인증 불필요** (모델=openai-codex 설정됨, 게이트웨이 상시가동).
- **알림(다음 단계)**: `hermes cron create "<schedule>" "<prompt>" --script ~/.hermes/scripts/<wrapper>.py --deliver discord`. 래퍼가 `bt/.venv` 파이썬을 subprocess로 호출 → stdout이 컨텍스트 → Discord. `[SILENT]` 패턴으로 평소 조용.
- **Discord 설정(사용자 몫)**: 봇 생성→토큰→서버 초대→채널 ID→`hermes gateway setup` 또는 `~/.hermes/.env`에 `DISCORD_BOT_TOKEN`/`DISCORD_HOME_CHANNEL`. 토큰은 채팅 금지, 직접 입력.

## 5. 결정 로그

**확정**
- 리서치 엔진: `backtesting.py`(+yfinance) — 주식·크립토 동일 코드. (freqtrade는 크립토 전용이라 탈락, `ftbot/`는 레포 제외)
- 환경: uv venv (`bt/.venv`), Python 3.11
- 런타임: hermes (전역), Discord 인터페이스
- 개발: Claude Code/Codex + 이 GitHub 레포
- 차트: backtesting.py 내장 HTML(Bokeh) — 별도 대시보드 안 만듦

**버림**
- freqtrade/FreqUI (크립토 전용), Next.js/MUI 커스텀 대시보드 (오버킬), TradingView API (공개 데이터 API 없음·ToS), 비공식 tvdatafeed (잘 깨짐·ToS), gajae-code (코딩 에이전트지 quant 봇 아님)

**보류/다음**
- 더 나은 룰 (현 SMA 20/50은 4종목 다 buy&hold에 짐 — 검증된 사실)
- Discord 봇 토큰 → 알림(cron) 활성화
- 실제 매수 룰·자동주문 (검증 후)

## 6. 검증된 사실 (재현 가능)
SMA 20/50, 수수료 0.1%, 2019~2026:
| 종목 | 전략 | Buy&Hold |
|---|---|---|
| TSLA | +674% | +2,154% |
| NVDA | +842% | +5,039% |
| PLTR | +132% | +488% |
| BTC | +905% | +1,747% |

→ 단순 추세룰은 강세장에서 보유에 패배. 재현: `bt/.venv/bin/python bt/run_backtest.py`

## 7. 유지 규율 (이 레포의 약속)
1. CLI 인터페이스(§3) 바꾸면 → SKILL.md + §3 동시 수정 + 같은 커밋
2. 도구/런타임 결정 바뀌면 → §5 결정 로그 갱신
3. 새 검증 결과 → §6 갱신 (수치는 재현 명령 함께)
4. "코드 짠다 = Claude Code/Codex에서. 실행 = hermes. 기록 = 이 레포."
