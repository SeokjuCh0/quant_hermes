# SPEC — quant_hermes

> **단일 권위 문서.** CLI 인터페이스·스킬·아키텍처·결정이 바뀌면 이 파일을 **같은 커밋에서** 갱신한다. 코드와 SPEC이 어긋나면 그건 버그다.
> 최종 갱신: 2026-06-02 (멀티봇/프로필 구조 — personas/ + deploy.sh, symlink 폐기)

---

## 1. 목적 & 범위

| 항목 | 내용 |
|---|---|
| 무엇 | 개인용 퀀트 **리서치 + Q&A/알림 어시스턴트** harness |
| 사용자 | 초보, 소액, 비배포(친구 그룹 한정). 개발=M4 Pro(보안망), 실행=M1 Air(상시) |
| 자산 | 미국주식(TSLA·NVDA·PLTR…) + 크립토(BTC-USD) — 한국주식 제외 |
| 전략 성격 | 저빈도·룰 기반 추세 진입 (틱/HFT 아님) |
| 현 단계 | **백테스트·검증 위주.** 실거래 미시행. 알림까지가 목표 |
| 봇 | 디스코드 4봇 — 마갈량(claude·메인분석)·홀란(codex·비판)·앤서니테일러(perplexity·데드락 판정)·퍼거슨(gemini·결정/정비). 봇1=프로필1=별도봇. 흐름: 마갈량 답변→홀란 비판→안 맞으면 앤서니 독립판정→방법론 변경은 퍼거슨이 merge+git push |
| 비범위 | 자동매매 실행, 공개 배포, 커스텀 웹 대시보드 |

**1차 목표는 수익이 아니라** 비용·편향(look-ahead/survivorship) 반영한 검증 파이프라인과, 질문하면 실제 백테스트로 답하는 어시스턴트 구축.

## 2. 아키텍처 — 개발 ≠ 실행

```
[개발] Claude Code / claw-code / Codex   (코딩 도구는 취향 — 코드·스킬·스펙 작성)
   │
[형상관리] GitHub: SeokjuCh0/quant_hermes
   │  bash deploy.sh <persona>  →  personas/<persona> 를 hermes 프로필로 "복사"
   │  (스킬 __QUANT_DIR__ 치환 + bot.conf config 적용; symlink 아님)
[실행] hermes (전역 설치) — 봇 1개 = 프로필 1개(~/.hermes/profiles/<name>) = 게이트웨이 1개
   │  에이전트가 질문 받으면 quant_cli.py 실제 실행 → 숫자로 답
[인터페이스] 터미널 + Discord (멘션/free-response 대화, /reload-skills 라이브 갱신, cron 알림)
```

**구성 요소**
| 요소 | 역할 | 위치 |
|---|---|---|
| `backtesting.py` + `yfinance` | 리서치 엔진(백테스트·데이터) | `bt/.venv` |
| `bt/run_backtest.py` | 종목 묶음 SMA 백테스트 (탐색용) | repo |
| `bt/quant_cli.py` | **에이전트가 호출하는 도구** (backtest/signal/compare) | repo |
| `personas/<name>/SOUL.md` | 봇 페르소나(정체성·말투) | repo |
| `personas/<name>/skills/quant-analyst/SKILL.md` | **harness** — 언제·어떻게 도구 쓰고 답할지 | repo |
| `personas/<name>/bot.conf` | 그 봇의 profile·model·provider·config | repo |
| `deploy.sh <persona>` | personas/<name> → 프로필로 복사·설정·재시작 | repo |
| hermes | 런타임 (봇1=프로필1=게이트웨이1) | `~/.hermes/profiles/<name>` |

## 3. quant_cli.py 인터페이스 계약 (변경 시 SKILL.md도 동시 수정)

실행: `bt/.venv/bin/python bt/quant_cli.py <subcommand> [opts]`

| subcommand | 옵션 | 출력 |
|---|---|---|
| `backtest` | `--symbol SYM [--rule sma --n1 20 --n2 50 --start 2019-01-01 --plot]` | 전략수익률·Buy&Hold·Sharpe·MDD·거래수·승률 (한국어 텍스트). `--plot` 시 HTML 경로 |
| `signal` | `--symbol SYM [--n1 20 --n2 50]` | 현재 SMA20/50 값·골든/데드 상태·마지막 크로스 날짜·오늘 신호 여부 |
| `compare` | `--symbol SYM` | 전략 vs 보유 한 줄 비교 |

심볼 규칙: 미국주식=티커(`NVDA`), 크립토=`XXX-USD`(`BTC-USD`). 수수료 `commission=0.001` 반영. 에러는 친절히 + non-zero exit.

## 4. hermes 통합

- **스킬·페르소나 경로**: repo `personas/<name>/`(SOUL.md + bot.conf + skills/)가 **단일 소스**. `bash deploy.sh <name>` 가 그 프로필 `~/.hermes/profiles/<name>` 로 **복사**(스킬 `__QUANT_DIR__`→repo 치환; symlink 아님 — placeholder 깨짐 방지) + bot.conf config 적용 + 게이트웨이 재시작. **봇 1개 = 프로필 1개.** 스킬은 라이브 편집 후 Discord `/reload-skills`로 재시작 없이 반영(SOUL·모델 변경은 재배포 필요).
- **Q&A(현 단계)**: 터미널 `hermes` 또는 Discord 멘션/free-response → 에이전트가 quant_cli 실행해 답. 모델은 프로필별(`bot.conf`; 마갈량 기본 `anthropic`/`claude-sonnet-4-5`). 봇마다 다른 모델 가능(토론 다양성). 백엔드는 **API 키**(구독 OAuth 아님 — ToS·레이트리밋 회피).
- **알림(다음 단계)**: `hermes cron create "<schedule>" "<prompt>" --script ~/.hermes/scripts/<wrapper>.py --deliver discord`. 래퍼가 `bt/.venv` 파이썬을 subprocess로 호출 → stdout이 컨텍스트 → Discord. `[SILENT]` 패턴으로 평소 조용.
- **Discord 설정(사용자 몫)**: 봇마다 별도 토큰(개발자포털)→서버 초대→프로필 `.env`(`~/.hermes/profiles/<name>/.env`)에 `DISCORD_BOT_TOKEN` + `GATEWAY_ALLOW_ALL_USERS=true`. ⚠ `DISCORD_ALLOWED_USERS`는 **비워둘 것**(채우면 그 ID만 응답, 나머지는 어댑터 선필터에서 잘림 — allow-all 플래그로 못 뚫음). 멀티봇 토론은 각 `.env`에 `DISCORD_ALLOW_BOTS=mentions`. 토큰은 채팅 금지, 직접 입력.

## 5. 결정 로그

**확정**
- 리서치 엔진: `backtesting.py`(+yfinance) — 주식·크립토 동일 코드. (freqtrade는 크립토 전용이라 탈락, `ftbot/`는 레포 제외)
- 환경: uv venv (`bt/.venv`), Python 3.11
- 런타임: hermes (전역), Discord 인터페이스
- 개발: Claude Code/Codex + 이 GitHub 레포
- 차트: backtesting.py 내장 HTML(Bokeh) — 별도 대시보드 안 만듦
- **멀티봇 = hermes 프로필 N개** (봇1=프로필1=게이트웨이1). SOUL·모델·토큰 프로필별 분리. 새 봇 = `personas/` 폴더 복사. (한 게이트웨이에 봇 다중화 불가 — SOUL 단일 로드 + 세션키 `agent:main:` 하드코딩)
- **배포 = `deploy.sh <persona>` sed-복사 + config 적용** (symlink 폐기 — placeholder 깨짐)
- **봇 백엔드 = API 키** (구독 OAuth 아님 — ToS/레이트리밋 회피)
- **봇끼리 토론 = `DISCORD_ALLOW_BOTS=mentions` 게이팅** (하드 턴캡 없음 → 자연종료/사회자로 제어). 구조적 협업은 Kanban(= /team의 hermes판)

**버림**
- freqtrade/FreqUI (크립토 전용), Next.js/MUI 커스텀 대시보드 (오버킬), TradingView API (공개 데이터 API 없음·ToS), 비공식 tvdatafeed (잘 깨짐·ToS), claw-code/gajae (코딩 에이전트 — 개발엔 OK, 봇 *런타임*은 hermes)

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
