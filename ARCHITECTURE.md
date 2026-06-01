# ARCHITECTURE.md — 개인용 퀀트 리서치 시스템

> 전제: 개인용·비배포(혼자만 봄), 단일 MacBook(Apple Silicon), 초보, 소액, 목적 = ① 전략 리서치/백테스트.
> 2026-05 기준 검증된 사실로 작성. 죽었거나 위험한 라이브러리는 배제함(§9 참고).
> 이 문서는 "계속 추려나가는" 살아있는 결정 로그다. §8을 갱신하며 쓴다.

---

## 1. 9계층 아키텍처 (한눈에)

```
[ingest]   데이터 수집      ← API (ccxt / KIS / Alpaca …)        = sj-collect
   │ raw Parquet (불변, ingest_date 파티션) + manifest
   ▼
[store]    저장             ← DuckDB + Parquet  (= 네가 말한 "RDB")
   │ DataFrame
   ▼
[validate] 검증             ← pandera (행수·null·중복·온톨로지)   = sj-verify
   │
   ▼
[feature]  지표/피처        ← vectorbt 내장 지표 (vbt.MA …)
   │ entries/exits 입력값
   ▼
[strategy] 전략/모델        ← 순수함수 → bool 시그널 (A1~F)
   │
   ▼
[backtest] 백테스트         ← vectorbt 1.0  Portfolio.from_signals(fees, slippage)
   │ Portfolio 객체
   ▼
[evaluate] 평가/리포팅      ← quantstats-lumi (Sharpe·MDD·tearsheet)
   │
   ▼
[paper]    페이퍼/실행      ← Alpaca paper / Binance testnet / KIS 모의   [2주차+]
   │
   ▼
[API]      백엔드 API       ← FastAPI (REST + WebSocket)  ← Python↔JS 경계
   │ JSON
   ▼
[UI]       표시/상호작용    ← 리서치: JupyterLab / 대시보드: Next.js+MUI(+Storybook)

  ┌─ integrity (정합성, = sj-integrity) ─────────────────┐
  │  store → feature → backtest 를 세로로 관통하는 검사 레인.   │
  │  "파생 데이터가 원천을 정확히 반영하나"를 cross-check.        │
  │  예: 백테스트 손익에서 원천 체결가 역산해 대조.              │
  └──────────────────────────────────────────────────────┘
```

흐름은 **단방향 in-process 함수호출**. 엔터프라이즈 메시지큐·마이크로서비스 없음(솔로 과잉).

---

## 2. 계층별 컴포넌트 표 — 이름 / 역할 / 종류 / 연결

| 계층 | 도구 | 종류 | 역할 | 무엇과 연결되나 |
|---|---|---|---|---|
| ingest | **ccxt** | API모듈 | 크립토 100+거래소 무료 OHLCV (주력) | → raw Parquet |
| ingest | **pyupbit** | API모듈 | 업비트 KRW 보조 (저활동, 보조용만) | → raw Parquet |
| ingest | **FinanceDataReader + pykrx** | API모듈 | 한국주식 OHLCV·상폐포함 | → raw Parquet |
| ingest | **KIS REST**(httpx) | API | 한국투자증권 모의/실거래 | → raw Parquet / paper |
| ingest | **alpaca-py / polygon-api-client** | API모듈 | 미국주식 데이터·페이퍼 | → raw Parquet / paper |
| store | **DuckDB + Parquet** | 저장엔진 | 임베디드 OLAP(=RDB), 날짜파티션 | API→ 적재, → DataFrame |
| validate | **pandera** | 검증모듈 | DataFrameSchema로 행수·null·중복·dtype | DuckDB DataFrame 검사 |
| feature | **vectorbt 내장지표**(vbt.MA…) | 지표모듈 | 이동평균·RSI 등 시그널 재료 | DataFrame → entries/exits |
| feature | (확장) **TA-Lib** or **pandas-ta-classic** | 지표모듈 | 더 많은 지표 필요 시 | §9 주의 |
| strategy | **순수 파이썬 함수** | 모델 | A1~F 전략을 bool entries/exits로 | feature → backtest |
| backtest | **vectorbt 1.0** | 백테스트엔진 | from_signals(fees/slippage), 파라미터 스윕 | 시그널 → Portfolio |
| evaluate | **quantstats-lumi** | 분석모듈 | Sharpe·MDD·tearsheet HTML | Portfolio → 리포트/UI |
| integrity | **자작 cross-check + DuckDB SQL** | 검증레인 | 파생↔원천 정합성 | store/feature/backtest 관통 |
| config | **pydantic-settings + .env** | 설정 | API키·파라미터, macOS keyring 옵션 | 전 계층 |
| API | **FastAPI** + uvicorn | API서버 | DuckDB/백테스트 결과를 JSON·WebSocket로 노출 (Python↔JS 경계) | evaluate→프론트 |
| UI(리서치) | **JupyterLab** | UI | 1차 탐색(셀단위·인라인 plotly) | Python in-process |
| UI(대시보드) | **Next.js + MUI** | UI | 웹 대시보드. MUI X DataGrid=거래테이블. Storybook=컴포넌트 개발 | FastAPI JSON fetch |
| chart(py) | **plotly**/**mplfinance** | 시각화 | Jupyter 안에서만 (경계 못 넘음) | backtest→Jupyter |
| chart(js) | **lightweight-charts**(가격)/**MUI X Charts**(에쿼티) | 시각화 | JSON→React 렌더 | FastAPI→Next.js |

---

## 3. 데이터 흐름 (end-to-end 한 줄)

```
ccxt.fetch_ohlcv()
  → raw/BTCUSDT/ingest_date=2026-05-30/*.parquet (불변) + manifest.json
  → DuckDB 적재
  → con.execute(sql).df()  (pandas DataFrame)
  → pandera 스키마 검증 (행수/null/중복)
  → vbt.MA(close, [20,50])  (지표)
  → entries = ma20.ma_crossed_above(ma50)  (전략 → bool 시그널)
  → vbt.Portfolio.from_signals(close, entries, exits, fees=0.001, slippage=0.0005)
  → quantstats_lumi.reports.html(portfolio.returns())  (Sharpe·MDD·tearsheet)
  → JupyterLab 인라인 표시  /  Streamlit st.plotly_chart(pf.plot())
       ↑ integrity: 백테스트 손익에서 체결가 역산해 원천 Parquet과 대조
```

---

## 4. 모델 ↔ 모듈 ↔ API 연결 (모델 카탈로그 A~F가 어디서 도나)

| 모델군 | feature 계층 | backtest 계층 | 비고 |
|---|---|---|---|
| **A1 추세추종** (MA크로스) | vbt.MA | vectorbt from_signals | 1주차 시작점 |
| **A2 평균회귀** (BB/RSI) | vbt.RSI / TA-Lib BBANDS | vectorbt | 손절 규율 필요 |
| **A3 페어/통계차익** | statsmodels(공적분) | vectorbt(2자산) | statsmodels 추가 |
| **B1~B3 팩터/포트폴리오** | pandas 랭킹 | vectorbt + PyPortfolioOpt | 5+자산 시 PyPortfolioOpt |
| **C GARCH/시계열** | arch / statsforecast | — | 변동성 모델 추가 |
| **D 머신러닝** | scikit-learn/xgboost | vectorbt(시그널만) | ⚠️ 초보 보류 |

→ **1주차엔 A1만, vectorbt 내장지표만으로 충분.** 나머지 모델군은 필요해질 때 해당 모듈 추가.

---

## 5. UI를 어떻게 연결하나  (Streamlit → Next.js로 변경)

**리서치와 대시보드를 분리한다:**
- **리서치 = JupyterLab** [High]: vectorbt 내장 plotly 위젯이 Jupyter에서만 네이티브. 전략 탐색·개발은 노트북. (Python in-process, 프론트와 무관하게 공존.)
- **대시보드 = Next.js + MUI (+ Storybook)**: 별도 JS 앱.

**핵심: Python↔JS 경계 = FastAPI 백엔드가 필요하다** [High]
- Streamlit은 경계가 없었지만 Next.js는 별도 앱이라, DuckDB/백테스트 결과를 JSON으로 노출할 API 서버를 직접 만들어야 한다. → **FastAPI + uvicorn**. Pydantic 기반(pydantic-settings와 동일 생태계), 자동 OpenAPI 문서, WebSocket 내장.
- 엔드포인트 예: `GET /ohlcv`, `POST /backtest`(파라미터→vectorbt→에쿼티·거래·메트릭 JSON), `WS /ws/prices`(라이브 시세).

**데이터 흐름:**
```
DuckDB/vectorbt → FastAPI(JSON/WS) → Next.js fetch(React Query/SWR)
  → MUI(레이아웃·DataGrid·테마) + 차트(lightweight-charts / MUI X Charts)
  → Storybook(컴포넌트 격리 개발) [옵션]
```

**차트 (vectorbt plotly는 경계 못 넘음 — JS로 다시 그린다)** [Medium]
- 가격/캔들/거래 = **lightweight-charts** (TradingView **JS** v5.2.0, Apache-2.0, 무료 금융차트 표준 — §9의 죽은 python 래퍼와 다른 살아있는 프로젝트) [High].
- 에쿼티커브·메트릭·라인·바 = **MUI X Charts** (라인·바는 무료, MUI 통합). ⚠️ **MUI X 캔들스틱은 유료(Premium)+preview라 캔들은 lightweight-charts로** [High]. 대안 Recharts / Apache ECharts.
- ~~react-financial-charts~~ **쓰지 마라** (2023-05 이후 3년 휴면, 죽음).
- vectorbt 차트를 굳이 살리려면 Python `fig.to_json()` → `react-plotly.js`.

**도구 배치:** Next.js=프레임워크·라우팅, MUI=컴포넌트(+X DataGrid 거래테이블·테마), Storybook=컴포넌트 격리 개발·문서.

**솔직한 주의** [Medium]: 이건 Streamlit "1파일·API 0개"를 "2코드베이스·2언어·동기화할 API 1개"로 바꾼다. 혼자 볼 대시보드치곤 표면적이 크게 는다. 특히 Storybook은 재사용 컴포넌트를 여럿 굴릴 때만 값을 함. 프론트 실력·React 익숙함·폴리시 욕심이 동기면 합리적.

---

## 6. 프로젝트 디렉토리 구조 (솔로 uv 프로젝트)

```
quant/
├── pyproject.toml          # uv 관리
├── uv.lock                 # 재현성: 버전 핀
├── .env                    # API키 (gitignore)
├── configs/                # 전략 파라미터 YAML
├── data/
│   ├── raw/                # Parquet, ingest_date 파티션, 불변
│   └── quant.db            # DuckDB
├── src/quant/
│   ├── ingest/             # ccxt·krx·kis 수집기      (sj-collect)
│   ├── store/              # parquet writer·duckdb 로더·manifest
│   ├── validate/           # pandera 스키마             (sj-verify)
│   ├── integrity/          # cross-file 정합성 검사     (sj-integrity)
│   ├── features/           # 지표 계산
│   ├── strategies/         # 전략 = 순수함수 → 시그널
│   ├── backtest/           # vectorbt runner
│   └── evaluate/           # quantstats 리포트
├── notebooks/              # JupyterLab 리서치
├── app.py                  # Streamlit 대시보드        [선택]
└── reports/                # 생성된 HTML 리포트
```

---

## 7. 1주차 최소 골격

```bash
uv init quant && cd quant
uv add ccxt duckdb pandas pyarrow vectorbt quantstats-lumi pandera \
       jupyterlab streamlit plotly mplfinance pydantic-settings
# pandas-ta 안 깐다(§9). TA-Lib 1주차 불필요. polars는 1GB 넘으면 그때.
```

**목표(검증 가능):** ccxt로 BTC/USDT 일봉 1년치 → Parquet+manifest → DuckDB → pandera 검증 → `vbt.MA(20,50)` 골든크로스 → `Portfolio.from_signals(fees=0.001)` → quantstats-lumi HTML 리포트. **성공 = runner가 에러 없이 돌고 리포트에 Sharpe·MDD가 찍힘.** (수익 여부는 목표 아님.)

---

## 8. 결정 로그 — 확정 / 후보 / 보류 / 버림

**확정 [High]**
- 환경: `uv` (conda 불필요 — Apple Silicon arm64 wheel 정상)
- 저장: DuckDB + Parquet (RDB는 이거 하나)
- 백테스트: **입문은 backtesting.py**(쉬움·활발·리서치전용) / 속도·파라미터 스윕은 **vectorbt 1.0** 무료판. ※커뮤니티는 초보에 backtesting.py 먼저 권장 — vectorbt 벡터화 사고가 입문 장벽. (팩터 리서치는 zipline-reloaded)
- 리포팅: quantstats-lumi (활발한 포크)
- 검증: pandera
- UI 리서치: JupyterLab. 대시보드: **Next.js + MUI**(+Storybook 옵션), 경계 = **FastAPI**. JS차트: lightweight-charts(JS) + MUI X Charts
- 데이터검증 도구 great-expectations: **버림**(의존성 107개, 솔로 과잉)

**후보 (택1/조건부)**
- 시장 1개: 미국(데이터 깨끗) vs 크립토(마찰 최저) vs 한국(KIS) — **미정**
- 지표 라이브러리(확장 시): TA-Lib(macOS14+) vs pandas-ta-classic
- 데이터: pandas 기본, polars는 >1GB일 때
- 노트북: JupyterLab vs marimo(반응형, vectorbt 위젯 호환 미검증)

**보류 (필요해질 때 추가)**
- PyPortfolioOpt (자산 5+ 비중배분) / arch GARCH (변동성타겟) / statsforecast (AutoARIMA) / statsmodels (공적분·ADF) / scikit-learn·xgboost (ML, 초보 보류)
- paper·integrity·KIS·미국주식 (2주차+)

**버림 [High]**
- `backtrader` (원작자 ~2018 손 뗌)
- `pandas-ta` 원조 (레포 삭제·소유권 이전·공급망 의혹·베타만) → 쓰려면 `pandas-ta-classic` 포크
- `lightweight-charts-python` (2024-09 이후 휴면) → plotly go.Candlestick
- `Streamlit`/`Dash`/`Panel`/`gradio` (Python 대시보드 — Next.js로 대체) · `conda`/`poetry`(불필요) · `pyfolio`(사망)

---

## 9. 정정·주의 (검증 에이전트가 잡은 함정)

1. **pandas-ta 원조는 쓰지 마라** [High]: `github.com/twopirllc/pandas-ta`가 현재 404(삭제), PyPI 메인테이너 이전(@twopirllc→@amortizer)·버전 히스토리 wipe·공급망 공격 의혹, 안정판 없이 베타(0.4.71b0)만. → 1주차는 **vectorbt 내장 지표**로 충분. 더 필요하면 `pandas-ta-classic` 포크 또는 TA-Lib.
2. **TA-Lib는 macOS 버전 확인** [High]: arm64 prebuilt wheel이 `macosx_14_0_arm64` 태그라 **macOS 14(Sonoma) 이상에서만** `uv add ta-lib`로 brew 없이 깔린다. 그 이하 버전이면 `brew install ta-lib` 먼저 필요. (`sw_vers`로 확인)
3. **conda 안 써도 됨** [High]: "vectorbt/Numba는 Apple Silicon에서 pip 안 됨"은 2021~22년 옛말. llvmlite 0.47.0(2026-03)이 arm64 wheel 제공 → `uv add vectorbt` 한 줄.
4. **lightweight-charts-python 죽음** [High]: 마지막 커밋·릴리스 2024-09(약 20개월 휴면). TradingView 룩 원하면 plotly `go.Candlestick`.
5. **vectorbt 무료판은 유지보수 모드**: 신규 기능은 유료 PRO로, 무료판은 버그픽스·새 파이썬 지원 위주. 학습엔 충분.
6. **quantstats**: 원본도 살아있지만(0.0.81, 2026-01) `quantstats-lumi`(1.1.4, 2026-05)가 더 활발 → 포크 권장.
