---
name: methodology-maintainer
description: 토론에서 합의된 분석 방법론 변경을 공유 quant-analyst SKILL.md 에 반영하고 git(브랜치/PR)으로 올린다. 퍼거슨 전용. "방법론 merge", "분석 방향 업데이트", "이걸 반영해" 류 결정에 사용.
version: 1.0.0
license: MIT
---

# Methodology Maintainer (퍼거슨 전용)

토론(마갈량↔홀란↔테일러)에서 "앞으로 이렇게 분석하자"는 합리적 결론이 나오면, 그걸 **공유 방법론**에 반영하고 git에 남긴다.

## 단일 소스
- 방법론 = `__QUANT_DIR__/skills/quant-analyst/SKILL.md` (4봇이 배포 시 공유). 여기를 고치면 재배포 때 전원 반영된다.
- 레포 루트 = `__QUANT_DIR__`.

## 절대 규율 (퍼거슨이라도 어김 없음)
1. **합리적·재현 가능한 근거 없으면 변경 금지.** 토론 결론 + 숫자가 받쳐야 한다. 근거 약하면 기각하고 이유만 남긴다.
2. **종목별로 다른 방법론**이면 SKILL.md에 종목 섹션으로 분리한다 (한 종목 룰을 전체에 강요 금지).
3. **메인 브랜치 직접 push 금지.** 변경은 **브랜치 + PR**로 올린다 (머지는 사람이). 자동화가 main을 망치지 않게.

## 절차
1. 무엇을·왜 바꾸는지 1~3줄로 정한다 (토론 결론 인용).
2. `__QUANT_DIR__/skills/quant-analyst/SKILL.md` 를 **수술적으로** 수정 (해당 종목/규칙만, 기존 구조 유지).
3. git (브랜치 + PR):
   ```bash
   cd __QUANT_DIR__
   git checkout -b ferguson/methodology-$(date +%Y%m%d-%H%M%S)
   git add skills/quant-analyst/SKILL.md
   git commit -m "methodology: <무엇> (토론 합의: <근거 요약>)"
   git push -u origin HEAD
   gh pr create --fill --title "methodology: <무엇>" --body "<왜 / 토론 근거 / 적용 종목>" 2>/dev/null || echo "PR은 수동으로 열어라"
   ```
4. **github issues 확인 → 다음 분석 방향 반영**:
   ```bash
   gh issue list --state open --limit 20
   ```
   이슈에서 드러난 문제는 위 절차로 또 반영한다 (다음 라운드).

## Done when
- SKILL.md 변경이 **브랜치에 커밋·push** 됨 (main 직접 X).
- 커밋 메시지에 "왜(토론 근거)"가 들어 있다.
- 종목 특수 룰은 종목 섹션에 분리됐다.
- 근거 부실하면 변경 안 하고 "기각 + 이유"만 남겼다.

## Notes
- 이건 퍼거슨이 디스코드 토론 결론을 코드(방법론)에 반영하는 통로다. 실행 = M1 Air의 ferguson 프로필 (repo 클론 + `git`/`gh` 인증 필요).
- 변경 머지 후 각 봇에 `bash deploy.sh <봇>` 재배포(또는 Discord `/reload-skills`) 해야 새 방법론이 돈다.
