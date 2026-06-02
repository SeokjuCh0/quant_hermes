#!/usr/bin/env bash
# deploy.sh — 한 페르소나(personas/<name>)를 hermes 프로필로 배포하고 게이트웨이를 재시작.
#
# 사용:
#   bash deploy.sh <persona>                       # 예: bash deploy.sh magalyang
#   HERMES_HOME=/tmp/x bash deploy.sh <persona>    # 테스트: 파일만 그 경로에, hermes 호출 생략
#
# 하는 일:
#   1) personas/<name>/SOUL.md + skills/* 를 프로필 HERMES_HOME 으로 배치
#      (스킬의 __QUANT_DIR__ → 이 repo 절대경로로 치환; symlink 아님 — placeholder 깨짐 방지).
#   2) bot.conf 의 key=value 를 그 프로필에 적용 (profile=특수키, command_allowlist=콤마리스트 특수처리).
#   3) 게이트웨이 재시작.
#
# 새 봇 = personas/magalyang/ 복사 → SOUL.md·bot.conf 수정(+프로필 .env에 토큰) → bash deploy.sh <새이름>.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERSONA="${1:-}"
if [ -z "$PERSONA" ]; then
  echo "사용법: bash deploy.sh <persona>"
  echo "가능한 페르소나:"; ls "$REPO/personas" 2>/dev/null | sed 's/^/  - /'
  exit 1
fi
SRC="$REPO/personas/$PERSONA"
CONF="$SRC/bot.conf"
[ -f "$SRC/SOUL.md" ] || { echo "[에러] $SRC/SOUL.md 없음 (personas/$PERSONA 확인)"; exit 1; }

# --- profile 결정 (bot.conf 의 특수키) ---
PROFILE="$PERSONA"; SHARED_SKILLS=""
if [ -f "$CONF" ]; then
  _p="$(grep -E '^[[:space:]]*profile[[:space:]]*=' "$CONF" | head -1 | cut -d= -f2- | tr -d '[:space:]')"
  [ -n "$_p" ] && PROFILE="$_p"
  SHARED_SKILLS="$(grep -E '^[[:space:]]*skills[[:space:]]*=' "$CONF" | head -1 | cut -d= -f2- | tr -d '[:space:]')"
fi

# --- HERMES_HOME 결정 (HERMES_HOME 환경변수 = 테스트 모드) ---
TEST_MODE=0
if [ -n "${HERMES_HOME:-}" ]; then
  HH="$HERMES_HOME"; TEST_MODE=1
elif [ "$PROFILE" = "default" ]; then
  HH="$HOME/.hermes"
else
  HH="$HOME/.hermes/profiles/$PROFILE"
fi
echo "[*] persona=$PERSONA  profile=$PROFILE"
echo "[*] HERMES_HOME=$HH"
mkdir -p "$HH"

# --- 1) SOUL ---
cp "$SRC/SOUL.md" "$HH/SOUL.md"
echo "  ✓ SOUL.md"

# --- 2) skills (__QUANT_DIR__ → repo 절대경로 치환 복사) ---
if [ -d "$SRC/skills" ]; then
  for skdir in "$SRC/skills"/*/; do
    [ -d "$skdir" ] || continue
    name="$(basename "$skdir")"
    dst="$HH/skills/$name"
    mkdir -p "$dst"
    [ -f "$skdir/SKILL.md" ] && sed "s|__QUANT_DIR__|$REPO|g" "$skdir/SKILL.md" > "$dst/SKILL.md"
    if [ -d "$skdir/references" ]; then
      mkdir -p "$dst/references"
      for f in "$skdir/references/"*; do
        [ -e "$f" ] && sed "s|__QUANT_DIR__|$REPO|g" "$f" > "$dst/references/$(basename "$f")"
      done
    fi
    echo "  ✓ skill: $name"
  done
fi
# 공유 스킬 (repo skills/ — bot.conf 의 skills= 로 선언; 4봇이 같은 소스 공유)
if [ -n "$SHARED_SKILLS" ]; then
  echo "$SHARED_SKILLS" | tr ',' '\n' | while read -r sk; do
    sk="$(printf '%s' "$sk" | tr -d '[:space:]')"; [ -z "$sk" ] && continue
    src="$REPO/skills/$sk"; dst="$HH/skills/$sk"
    [ -d "$src" ] || { echo "  (공유 스킬 없음: $sk)"; continue; }
    mkdir -p "$dst"
    [ -f "$src/SKILL.md" ] && sed "s|__QUANT_DIR__|$REPO|g" "$src/SKILL.md" > "$dst/SKILL.md"
    if [ -d "$src/references" ]; then
      mkdir -p "$dst/references"
      for f in "$src/references/"*; do [ -e "$f" ] && sed "s|__QUANT_DIR__|$REPO|g" "$f" > "$dst/references/$(basename "$f")"; done
    fi
    echo "  ✓ shared skill: $sk"
  done
fi
echo "배포 완료(파일): $SRC → $HH"

# --- 테스트/미설치면 여기서 종료 ---
if [ "$TEST_MODE" = "1" ]; then
  echo "(HERMES_HOME 오버라이드 — config/재시작 생략, 파일 배치만 수행)"; exit 0
fi
if ! command -v hermes >/dev/null; then
  echo "  (hermes 미설치 — config/재시작 생략. 설치 후 다시 실행)"; exit 0
fi

# --- 3) config 적용 (bot.conf 의 나머지 key=value) ---
# default 프로필이면 -p 없이, 명명 프로필이면 -p <profile> (bash 3.2 빈배열+set -u 회피용 함수)
hp() { if [ "$PROFILE" = "default" ]; then hermes "$@"; else hermes -p "$PROFILE" "$@"; fi; }
CMDALLOW=""
if [ -f "$CONF" ]; then
  while IFS='=' read -r k v; do
    k="$(printf '%s' "$k" | tr -d '[:space:]')"      # 키: 공백 제거
    [ -z "$k" ] && continue                           # 값(v)은 공백 보존 (예: "curl *")
    case "$k" in
      profile) : ;;                                   # 이미 처리
      skills) : ;;                                     # deploy 지시어 (hermes config 아님)
      command_allowlist) CMDALLOW="$v" ;;             # 리스트 — 아래서 특수 처리
      *)
        if [ -n "$v" ]; then
          if hp config set "$k" "$v" >/dev/null 2>&1; then echo "  config: $k=$v"; else echo "  (config 실패: $k)"; fi
        fi
        ;;
    esac
  done < <(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$CONF")
fi

# command_allowlist (콤마 리스트) — config set 이 리스트를 문자열로 저장하는 이슈 회피해 yaml 직접
if [ -n "$CMDALLOW" ]; then
  PYV="$REPO/bt/.venv/bin/python"
  if [ -x "$PYV" ]; then
    if "$PYV" - "$HH/config.yaml" "$CMDALLOW" <<'PY' 2>/dev/null
import sys, os, yaml
p, raw = sys.argv[1], sys.argv[2]
d = (yaml.safe_load(open(p)) if os.path.exists(p) else {}) or {}
d["command_allowlist"] = [x for x in raw.split(",") if x]
yaml.safe_dump(d, open(p, "w"), allow_unicode=True, sort_keys=False)
PY
    then echo "  config: command_allowlist=[$CMDALLOW]"; else echo "  (command_allowlist 실패 — config.yaml에 수동: command_allowlist: ['curl *','curl'])"; fi
  else
    echo "  (bt venv 없음 — command_allowlist 수동 설정 필요)"
  fi
fi

# --- 게이트웨이 재시작 ---
echo "게이트웨이 재시작…"
hp gateway restart 2>&1 | tail -3 || echo "  (재시작 실패 — 토큰/프로필 확인 후 수동: hermes -p $PROFILE gateway restart)"
echo "[done] $PERSONA 배포 완료 🫡"
