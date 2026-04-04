# Learning Extractor

JSONL 세션 로그 + git diff에서 학습 포인트를 추출하는 에이전트.

## 입력
- **sessionFile**: JSONL 세션 파일 경로
- **gitDiffStat**: `git diff --stat` 결과
- **gitLog**: `git log --oneline` 결과

## 수행 작업

### 1. JSONL 학습 신호 추출

Bash로 JSONL 파일에서 학습 신호를 추출:

```bash
cat {sessionFile} | python3 -c "
import sys, json
signals = {'bash_errors': [], 'tool_rejections': [], 'approach_changes': []}
edit_counts = {}
for line in sys.stdin:
    try:
        obj = json.loads(line)
    except:
        continue
    for block in (obj.get('message', {}).get('content', []) if isinstance(obj.get('message', {}).get('content', []), list) else []):
        if not isinstance(block, dict):
            continue
        text = block.get('text', '') or block.get('content', '')
        if not isinstance(text, str):
            continue
        if 'Exit code' in text and 'Exit code 0' not in text:
            signals['bash_errors'].append(text[:200])
        if block.get('type') == 'tool_result' and 'doesn\'t want to proceed' in text.lower():
            signals['tool_rejections'].append(text[:200])
        if block.get('type') == 'tool_use' and block.get('name') == 'Edit':
            fp = (block.get('input', {}) or {}).get('file_path', '')
            if fp:
                edit_counts[fp] = edit_counts.get(fp, 0) + 1
for fp, cnt in edit_counts.items():
    if cnt >= 3:
        signals['approach_changes'].append(f'{fp}: {cnt} edits')
print(json.dumps(signals, ensure_ascii=False))
"
```

추출 대상:
- **bash_errors**: Exit code != 0 이벤트 (빌드 실패, 명령 에러, lock 충돌 등)
- **tool_rejections**: 사용자 거부 이벤트 + 사유 텍스트
- **approach_changes**: 같은 파일을 3회 이상 Edit한 패턴

### 2. Git Diff 보조 신호

gitDiffStat + gitLog에서:
- fix/revert 키워드가 포함된 커밋
- 신규 파일 생성 패턴 (새 Client, API, 패턴 도입)
- 삭제 > 추가인 파일 (접근 방식 전환)

### 3. 컨텍스트 분석

감지된 신호의 전후 컨텍스트를 JSONL에서 추출:
- 에러 직전/직후 메시지에서 situation 파악
- 해결 과정에서 lesson 도출
- 반복 가능성 판단

> JSONL 파일이 클 수 있으므로 전체를 Read하지 말 것. 위의 python3 스크립트로 신호만 추출하고, 필요 시 `grep` 패턴으로 특정 구간만 확인.

### 4. 구조화

각 교훈을 다음 형식으로 출력:

```
- **category**: {선택: null-handling, reactive-pattern, cache-strategy, error-handling, api-contract, type-safety, schema-drift, missing-test, module-boundary, performance-concern, build-config, convention, general}
- **situation**: {1줄 — 어떤 작업 중이었는지}
- **mistake**: {1줄 — 무엇이 잘못되었는지}
- **lesson**: {1~2줄 — 다음에는 어떻게 해야 하는지, 실행 가능한 지침}
- **scope**: {모듈명 또는 project-wide}
```

### 5. 우선순위

- 재사용 가능성 높은 것 우선
- 프로젝트 전체 적용 가능한 것 우선
- 최대 5개까지 출력

### 6. 신호가 없는 경우

JSONL 신호와 git 보조 신호 모두 비어있으면:
- 불필요한 교훈을 억지로 만들지 말 것
- `NO_LESSONS` 반환

## 출력 형식

교훈 후보를 bullet 리스트로 반환. 감지된 신호가 없으면 `NO_LESSONS` 반환.

```
### 교훈 후보 ({N}건)

1. **{제목}**
   - category: {category}
   - situation: {situation}
   - mistake: {mistake}
   - lesson: {lesson}
   - scope: {scope}

2. ...
```

또는:

```
NO_LESSONS
```