#!/usr/bin/env bash
# repo의 SOUL.md(페르소나) + quant-analyst 스킬을 hermes(~/.hermes)로 배포하고
# 게이트웨이를 재시작한다. 단일 소스 = 이 repo. 페르소나·스킬 고친 뒤 이거 한 방으로 반영.
#
# 사용: bash /Users/sj/dev/quant/deploy.sh
#
# 주의: 스킬은 symlink 가 아니라 __QUANT_DIR__ 를 이 머신 경로로 치환한 "복사본"으로
#       배포한다 (symlink 로 걸면 live 가 __QUANT_DIR__ placeholder 를 그대로 읽어 CLI 경로가 깨짐).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
SKILL_SRC="$REPO/hermes/skills/quant-analyst"
SKILL_DST="$HERMES_HOME/skills/quant/quant-analyst"

[ -f "$SKILL_SRC/SKILL.md" ] || { echo "[에러] repo 스킬 없음: $SKILL_SRC/SKILL.md" >&2; exit 1; }
[ -f "$REPO/hermes/SOUL.md" ] || { echo "[에러] repo SOUL.md 없음" >&2; exit 1; }

# 1) SOUL (페르소나) — placeholder 없음, 그대로 복사
cp "$REPO/hermes/SOUL.md" "$HERMES_HOME/SOUL.md"

# 2) 스킬 — __QUANT_DIR__ → 이 머신 repo 경로 치환 복사
mkdir -p "$SKILL_DST/references"
sed "s|__QUANT_DIR__|$REPO|g" "$SKILL_SRC/SKILL.md" > "$SKILL_DST/SKILL.md"
for f in "$SKILL_SRC/references/"*; do
  [ -e "$f" ] && sed "s|__QUANT_DIR__|$REPO|g" "$f" > "$SKILL_DST/references/$(basename "$f")"
done

echo "배포 완료: SOUL.md + quant-analyst → $HERMES_HOME"

# 3) 게이트웨이 재시작 (설치돼 있으면)
if command -v hermes >/dev/null; then
  echo "게이트웨이 재시작…"
  hermes gateway restart 2>&1 | tail -3 || echo "  (재시작 실패 — 수동: hermes gateway restart)"
else
  echo "  (hermes 미설치 — 게이트웨이 재시작 생략)"
fi
