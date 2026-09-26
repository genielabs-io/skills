---
name: wrap
license: MIT
description: Use when wrapping up a work session, summarizing changes, extracting reusable lessons, or promoting repeated lessons into durable memory files.
---

# Session Wrap: 세션 종료 + 교훈 수확 오케스트레이터

> 개별 단위 작업 종료 시 세션 정리, 교훈 수집, MEMORY.md 승격을 수행합니다.

## 인자 파싱

입력에서 다음을 파싱합니다:
- **커밋 메시지 또는 작업 요약**: 세션 리포트에 포함할 컨텍스트
- **인자 없음** → git log/diff에서 자동 추론

---

## Examples

### Example 1: 작업 완료 후 세션 마무리
User: `/wrap`
→ Phase 1: 세션 상태 수집 → Phase 2: 교훈 추출
→ Phase 3: lessons.md 기록 + graduation 승격 → Phase 4: 요약 리포트

### Example 2: 작업 요약과 함께 마무리
User: `/wrap API 리팩토링 완료`
→ 동일 흐름 + 세션 리포트에 사용자 컨텍스트 포함

### Example 3: 변경사항 없는 세션
User: `/wrap`
→ Phase 1에서 변경사항 없음 감지 → "변경사항 없음" 안내 후 종료

---

## Phase 1: 세션 상태 수집 (인라인)

1. **JSONL 세션 파일 경로 확인:**
   ```
   ~/.claude/projects/{encoded-cwd}/ 디렉토리에서 가장 최근 수정된 .jsonl 파일
   ```
   > `ls -t ~/.claude/projects/{encoded-cwd}/*.jsonl | head -1` 로 확인

2. **기본 브랜치 감지 + Git 상태 수집 (병렬):**
   ```bash
   BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@refs/remotes/origin/@@')
   # fallback: main 또는 develop
   ```
   - `git diff --stat ${BASE_BRANCH}...HEAD`
   - `git log --oneline ${BASE_BRANCH}...HEAD`

3. **TaskList 확인:** 미완료 태스크가 있으면 목록 포함

4. **변경 판단:** git diff와 git log 모두 비어있으면 → "변경사항 없음. 교훈 수확 대상이 없습니다." 안내 후 종료.

---

## 참조 파일

- Phase 2 학습 추출 에이전트 지시: [phase-2-extract.md](phase-2-extract.md)

## Phase 2: 병렬 분석 (에이전트)

### Agent: learning-extractor (general-purpose)

```
Task(subagent_type="general-purpose"):
  "${CLAUDE_SKILL_DIR}/phase-2-extract.md를 Read하고 지시를 따르세요.
   sessionFile: {Phase 1에서 확인한 JSONL 경로}
   gitDiffStat: {git diff --stat 결과}
   gitLog: {git log --oneline 결과}"
```

→ JSONL에서 학습 신호 추출 + 교훈 후보 목록 반환

---

## Phase 3: 결과 통합 + 기록 (인라인)

### 3-1: learning-extractor 결과 처리

1. 교훈 후보가 `NO_LESSONS`이면 → 건너뜀
2. 각 교훈 후보를 lessons.md 스키마로 변환:
   ```markdown
   ## {date}: {제목}
   - **category**: {category}
   - **situation**: {situation}
   - **mistake**: {mistake}
   - **lesson**: {lesson}
   - **scope**: {scope}
   - **source**: session-wrap
   - **applied**: 0
   - **recurred**: false
   ```
3. **3단계 중복 검사** (lessons.md Read 후):
   a. 정확 매칭: 동일 category + scope + mistake 핵심 키워드
   b. 키워드 매칭: lesson 텍스트에서 핵심 키워드 3개 이상 겹침
   c. 유사 항목 발견 시: 기존 항목의 lesson을 보강(merge)하고 새 항목은 건너뜀
4. 신규 항목만 lessons.md에 append

### 3-1.5: Gotchas 자동 반영

교훈 후보의 `scope`가 특정 스킬과 매칭되면 해당 스킬의 SKILL.md `## Gotchas` 섹션에 추가:
1. 매칭 기준: `scope`에 스킬명이 포함
2. 대상 스킬의 SKILL.md를 Read → `## Gotchas` 섹션 존재 여부 확인
3. Gotchas 섹션이 없으면 `## Troubleshooting` 위에 `## Gotchas` 섹션 생성
4. 이미 유사한 항목이 Gotchas에 있으면 건너뜀 (키워드 매칭)
5. 형식: `- {mistake 요약}: {올바른 행동}`
6. scope가 특정 스킬과 매칭되지 않으면 건너뜀 (범용 교훈은 lessons.md에만 유지)

### 3-2: Graduation 자동 승격

1. lessons.md 전체 스캔 → `applied >= 3 AND recurred == false` 항목 수집
2. 각 대상에 대해:
   a. MEMORY.md Read → 기존 항목과 keyword 중복 확인
   b. 중복 없으면 → MEMORY.md에 append:
      ```
      ## {category}
      {lesson 텍스트 1~2줄 요약}
      ```
   c. 중복이면 → 기존 항목이 더 구체적이면 건너뜀, 새 항목이 더 구체적이면 기존 항목 Edit
   d. lessons.md에서 해당 항목 삭제, `.claude/tasks/lessons-archive.md`로 이동

### 3-3: 아카이브 정리

- lessons.md 항목 수 > 20 AND graduated 미달 항목 중 applied == 0 + 30일 경과 → 자동 아카이브
- lessons-archive.md 위치: `.claude/tasks/lessons-archive.md`

---

## Phase 4: 세션 리포트 (인라인)

사용자에게 요약 출력:

```
## 세션 요약
- 변경 파일: {N}개, 커밋: {N}건
- 신규 교훈: {N}건 기록
- MEMORY.md 승격: {N}건
- 미완료 태스크: {있으면 목록}
```

---

## Troubleshooting

### JSONL 세션 파일을 찾을 수 없음
**원인:** 세션 시작 직후이거나 encoded-cwd 경로가 다름
**해결:** `ls ~/.claude/projects/` 에서 현재 프로젝트에 해당하는 디렉토리 확인. JSONL 파일이 없으면 git diff만으로 진행.

### lessons.md가 없거나 비어있음
**원인:** 첫 교훈 수확
**해결:** lessons.md가 없으면 `.claude/tasks/lessons.md` 경로에 헤더와 함께 신규 생성.

### graduation 대상이 많아 MEMORY.md가 비대해짐
**원인:** 여러 항목이 동시에 graduation 조건 충족
**해결:** MEMORY.md 200줄 제한을 고려하여 가장 project-wide한 항목 우선.

## Gotchas

- JSONL 파일이 매우 클 수 있음. 전체를 Read하지 말고 python3 스크립트로 신호만 추출할 것
- `git symbolic-ref` 실패 시 fallback으로 main/develop 순서로 시도할 것
- 교훈이 없는 세션도 정상임. 억지로 교훈을 만들지 말 것 — `NO_LESSONS` 반환이 올바른 동작

## Validation

- `git status --short`
- `git symbolic-ref refs/remotes/origin/HEAD`
