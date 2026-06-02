#!/usr/bin/env bash
# quant_hermes 부트스트랩 — 새 머신 "머신-레벨" 준비 (venv · SSL인증서 · hermes 확인).
# 페르소나(봇) 배포·설정은 deploy.sh 담당:  bash deploy.sh <persona>
#
# 전제: hermes(Nous Hermes Agent) 설치돼 있어야 함 (없으면: pip install hermes-agent && hermes setup).
# 사용:  git clone https://github.com/SeokjuCh0/quant_hermes
#        cd quant_hermes && bash setup.sh
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYBIN="$REPO/bt/.venv/bin/python"
echo "[*] repo: $REPO"

# 1) quant 엔진: uv venv + 의존성 (pyyaml = deploy.sh 의 command_allowlist 처리에 필요)
echo "[1/3] bt venv (uv, py3.11) + backtesting.py·yfinance·pandas·plotly·pyyaml"
command -v uv >/dev/null || { echo "  ✗ uv 필요: curl -LsSf https://astral.sh/uv/install.sh | sh"; exit 1; }
uv venv --python 3.11 "$REPO/bt/.venv"
uv pip install --python "$PYBIN" backtesting yfinance pandas plotly pyyaml

# 2) macOS SSL 인증서 (python.org 파이썬이면 — hermes 디스코드 SSL 픽스)
if [ -f "/Applications/Python 3.11/Install Certificates.command" ]; then
  echo "[2/3] macOS Python 인증서 설치 (디스코드 SSL)"
  bash "/Applications/Python 3.11/Install Certificates.command" >/dev/null 2>&1 || true
else
  echo "[2/3] (Install Certificates 없음 — 건너뜀; Linux면 보통 불필요)"
fi

# 3) hermes 설치 확인
echo "[3/3] hermes 확인"
command -v hermes >/dev/null || { echo "  ⚠ hermes 미설치 — 'pip install hermes-agent && hermes setup' 먼저"; exit 1; }

echo
echo "✅ 머신 준비 끝. 퀀트 엔진 검증:"
echo "   $PYBIN $REPO/bt/quant_cli.py compare --symbol NVDA"
cat <<EOF

다음 — 봇(마갈량) 띄우기:
  1) 프로필 생성:  hermes profile create magalyang
  2) 모델 인증:    hermes -p magalyang model              # 프로바이더 로그인/키
  3) 시크릿:       ~/.hermes/profiles/magalyang/.env 에:
        DISCORD_BOT_TOKEN=<이 봇 토큰>
        GATEWAY_ALLOW_ALL_USERS=true          # 친구 전원 응답 (친구서버면 OK)
        # ⚠ DISCORD_ALLOWED_USERS 는 비워둘 것 — 채우면 그 ID만 응답되고
        #   나머지는 어댑터 선필터에서 잘린다(allow-all 플래그로도 못 뚫음).
        # (멀티봇이면) DISCORD_ALLOW_BOTS=mentions   # 봇끼리 @멘션 때만 받아침
  4) 배포+시작:    bash deploy.sh magalyang               # SOUL·스킬·config 적용 + 게이트웨이 재시작
        (안 떠있으면: hermes -p magalyang gateway start)

봇 더 추가: personas/magalyang/ → personas/<새이름>/ 복사, SOUL·bot.conf 수정, 위 1~4 반복.
EOF
echo "[done] 부트스트랩 완료 🫡"
