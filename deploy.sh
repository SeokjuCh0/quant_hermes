#!/usr/bin/env bash
# quant-analyst 스킬을 repo → hermes 로 연결한다 (단일 소스 = 이 repo).
# repo의 SKILL.md를 고치면 hermes가 즉시 반영하도록 symlink를 건다.
#
# 사용: bash /Users/sj/dev/quant/deploy.sh
#
# 주의: ~/.hermes 안의 기존 quant-analyst 스킬 디렉토리를 지우고 symlink로 교체한다.
#       (내용은 이 repo에 있으므로 안전하게 재생성 가능)
set -euo pipefail

REPO_SKILL="/Users/sj/dev/quant/hermes/skills/quant-analyst"
HERMES_LINK="$HOME/.hermes/skills/quant/quant-analyst"

if [ ! -f "$REPO_SKILL/SKILL.md" ]; then
  echo "[에러] repo 스킬이 없습니다: $REPO_SKILL/SKILL.md" >&2
  exit 1
fi

mkdir -p "$HOME/.hermes/skills/quant"
rm -rf "$HERMES_LINK"
ln -s "$REPO_SKILL" "$HERMES_LINK"

echo "연결 완료: $HERMES_LINK -> $REPO_SKILL"
ls -la "$HOME/.hermes/skills/quant/"
echo "이제 repo에서 SKILL.md를 고치면 hermes가 바로 반영합니다."
