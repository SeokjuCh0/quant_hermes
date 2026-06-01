#!/usr/bin/env bash
# quant_hermes 부트스트랩 — 새 머신에서 "마갈량"(quant + hermes) 재현.
#
# 전제: hermes(Nous Hermes Agent)가 이미 설치돼 있어야 함.
#       없으면 먼저:  pip install hermes-agent && hermes setup
#
# 사용:  git clone https://github.com/SeokjuCh0/quant_hermes
#        cd quant_hermes && bash setup.sh
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
PYBIN="$REPO/bt/.venv/bin/python"
echo "[*] repo        : $REPO"
echo "[*] hermes home : $HERMES_HOME"

# 1) quant 엔진: uv venv + 의존성
echo "[1/6] bt venv (uv, py3.11) + backtesting.py·yfinance·pandas·plotly·pyyaml"
command -v uv >/dev/null || { echo "  ✗ uv 필요: curl -LsSf https://astral.sh/uv/install.sh | sh"; exit 1; }
uv venv --python 3.11 "$REPO/bt/.venv"
uv pip install --python "$PYBIN" backtesting yfinance pandas plotly pyyaml

# 2) macOS SSL 인증서 (python.org 파이썬이면 — hermes 디스코드 SSL 픽스)
if [ -f "/Applications/Python 3.11/Install Certificates.command" ]; then
  echo "[2/6] macOS Python 인증서 설치 (디스코드 SSL)"
  bash "/Applications/Python 3.11/Install Certificates.command" >/dev/null 2>&1 || true
else
  echo "[2/6] (Install Certificates 없음 — 건너뜀; Linux면 보통 불필요)"
fi

# 3) hermes 설치 확인
echo "[3/6] hermes 확인"
command -v hermes >/dev/null || { echo "  ⚠ hermes 미설치 — 'pip install hermes-agent && hermes setup' 먼저 하고 재실행"; exit 1; }

# 4) quant-analyst 스킬 + SOUL(마갈량) 배치 — __QUANT_DIR__ 를 이 머신 경로로 치환
echo "[4/6] 스킬·SOUL 배치 (__QUANT_DIR__ → $REPO)"
SKILL_DST="$HERMES_HOME/skills/quant/quant-analyst"
mkdir -p "$SKILL_DST/references"
sed "s|__QUANT_DIR__|$REPO|g" "$REPO/hermes/skills/quant-analyst/SKILL.md" > "$SKILL_DST/SKILL.md"
for f in "$REPO/hermes/skills/quant-analyst/references/"*; do
  [ -e "$f" ] && sed "s|__QUANT_DIR__|$REPO|g" "$f" > "$SKILL_DST/references/$(basename "$f")"
done
cp "$REPO/hermes/SOUL.md" "$HERMES_HOME/SOUL.md"

# 5) hermes 설정 적용 (모델·디스코드·표시·curl 허용)
echo "[5/6] hermes config 적용"
hermes config set model.default claude-sonnet-4-5
hermes config set model.provider anthropic
hermes config set display.busy_input_mode queue
hermes config set display.tool_progress none
hermes config set discord.auto_thread false
hermes config set discord.require_mention false
"$PYBIN" - "$HERMES_HOME/config.yaml" <<'PY' || echo "    (command_allowlist 자동설정 실패 — config.yaml에 직접: command_allowlist: ['curl *','curl'])"
import sys, yaml
p = sys.argv[1]
d = yaml.safe_load(open(p)) or {}
d["command_allowlist"] = ["curl *", "curl"]
yaml.safe_dump(d, open(p, "w"), allow_unicode=True, sort_keys=False)
print("    command_allowlist=['curl *','curl'] 적용")
PY

# 6) 수동 단계 (시크릿/계정 — 자동화 불가)
cat <<EOF

[6/6] ✅ 자동 설정 끝. 아래는 네가 직접 (시크릿/네 계정):
  1) 모델 인증:        hermes model              # anthropic 로그인
  2) $HERMES_HOME/.env 에 추가:
        DISCORD_BOT_TOKEN=<디스코드 봇 토큰>
        GATEWAY_ALLOW_ALL_USERS=true             # 친구 전원 응답 (친구서버면 OK)
        # ⚠ DISCORD_ALLOWED_USERS 는 설정하지 마라(비워 둔다). 채우면 그 ID만 응답되고
        #   나머지는 Discord 어댑터 선필터(_is_allowed_user)에서 잘린다.
        #   이 선필터는 allow-all 플래그를 안 보므로 빈 allowlist 로만 개방된다.
  3) 디스코드 연결:    hermes gateway setup       # 토큰/채널 등록 (allowed users 물으면 비워 둘 것)
  4) 게이트웨이 시작:  hermes gateway start

검증(퀀트 엔진):  $PYBIN $REPO/bt/quant_cli.py compare --symbol NVDA
EOF
echo "[done] 마갈량 재현 준비 완료 🫡"
