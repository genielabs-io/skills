---
name: unicode-guard
description: Use when checking source files for hidden Unicode characters, Trojan Source style bidi controls, zero-width characters, or GlassWorm-style variation selectors in changed files or a specific path.
---

# Unicode Guard Skill (Invisible Character Detection)

소스 코드에 숨겨진 보이지 않는 유니코드 문자를 탐지합니다.
GlassWorm(CVE-2025-55182) 및 Trojan Source(CVE-2021-42574) 공격 벡터를 방어합니다.

**탐지 전용** — 자동 수정하지 않습니다. 합법적 문자(국제화 문자열 등) 삭제 위험을 방지하기 위함입니다.

## Parameters

| 파라미터 | 기본값 | 설명 |
|---------|--------|------|
| scope | `--diff` | `--diff`(기본 브랜치 대비), `--staged`, 파일 경로 |

## Steps

### Step 1: 인자 파싱

사용자 입력에서 scope를 파싱한다.

- scope 결정:
    - `--staged` → staged 파일 대상
    - `--diff` 또는 미지정 → 기본 브랜치 대비 변경 대상
    - 그 외 인자 → 파일 경로로 간주

### Step 2: 대상 파일 목록 추출

scope에 따라 변경된 파일 목록을 추출한다.

**대상 확장자:** `.java`, `.js`, `.ts`, `.jsx`, `.tsx`, `.json`, `.yml`, `.yaml`, `.md`, `.gradle`, `.kts`, `.xml`, `.sh`, `.properties`, `.py`, `.go`, `.rs`, `.rb`, `.php`, `.swift`, `.kt`

```bash
# --diff (기본): 기본 브랜치 대비 변경 파일
git diff $(git symbolic-ref refs/remotes/origin/HEAD | sed 's@refs/remotes/origin/@@')...HEAD --name-only --diff-filter=ACMR

# --staged: staged 파일
git diff --cached --name-only --diff-filter=ACMR

# 파일 경로 지정: 해당 파일 직접 사용
```

추출된 파일 중 대상 확장자에 해당하는 파일만 필터링한다.
변경 파일이 없으면 "검사 대상 파일이 없습니다." 메시지를 출력하고 종료한다.

### Step 3: 보이지 않는 유니코드 문자 스캔

각 파일에 대해 Bash에서 보이지 않는 유니코드 문자를 검색한다.

**검사 대상 유니코드 범위:**

| 카테고리 | 범위 | 위협 유형 |
|---------|------|----------|
| 소프트 하이픈 | `U+00AD` | 은닉 |
| 제로폭 공백/마커 | `U+200B`-`U+200F` | Trojan Source |
| BiDi 오버라이드 | `U+202A`-`U+202E` | Trojan Source |
| 보이지 않는 연산자 | `U+2060`-`U+2064` | 은닉 |
| BiDi 격리 | `U+2066`-`U+2069` | Trojan Source |
| BOM/ZWNBSP | `U+FEFF` | 은닉 |
| 변형 선택자 1-16 | `U+FE00`-`U+FE0F` | GlassWorm |

**스캔 명령어 (perl 사용 — macOS/Linux 모두 호환):**

```bash
perl -CSD -ne 'print "$ARGV:$.: $_" if /[\x{00AD}\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{2064}\x{2066}-\x{2069}\x{FEFF}\x{FE00}-\x{FE0F}]/' "$file"
```

> `-CSD` 플래그는 stdin/stdout/파일을 UTF-8로 처리. macOS 기본 grep은 PCRE(`-P`)를 지원하지 않으므로 perl을 사용한다.

각 매칭에 대해 다음 정보를 수집:
- 파일 경로
- 라인 번호
- 매칭된 유니코드 코드포인트 (예: `U+200B`)
- 해당 라인의 내용 (보이지 않는 문자를 `[U+XXXX]` 표기로 치환하여 표시)
- 위협 카테고리

**코드포인트 식별 방법:**

매칭된 라인에서 정확한 코드포인트를 식별하기 위해 다음 명령을 사용:

```bash
echo "$matched_line" | perl -CSD -ne 'while (/[\x{00AD}\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{2064}\x{2066}-\x{2069}\x{FEFF}\x{FE00}-\x{FE0F}]/g) { printf "U+%04X\n", ord($&) }'
```

### Step 4: 결과 요약

아래 형식으로 결과를 출력한다:

**탐지된 경우:**

```
## Unicode Guard 결과

| 항목 | 값 |
|------|-----|
| 검사 파일 | N개 |
| 탐지 건수 | N건 |
| 영향 파일 | N개 |

### 탐지 상세
| 파일 | 라인 | 코드포인트 | 카테고리 | 위협 |
|------|------|-----------|---------|------|
| Foo.java | 42 | U+200E | BiDi 마커 | Trojan Source |
| bar.js | 15 | U+FE01 | 변형 선택자 | GlassWorm |

### 권장 조치
- 위 파일의 해당 라인을 수동으로 확인하세요
- 의도적으로 삽입한 문자가 아니라면 제거를 권장합니다
- `git diff`에서 해당 라인의 변경 이력을 확인하세요
```

**탐지되지 않은 경우:**

```
## Unicode Guard 결과

검사 파일 N개에서 보이지 않는 유니코드 문자가 탐지되지 않았습니다.
```

## 코드포인트 참조표

스캔 결과에서 코드포인트를 해석할 때 사용:

| 코드포인트 | 이름 | 위협 |
|-----------|------|------|
| U+00AD | Soft Hyphen | 은닉 |
| U+200B | Zero Width Space | Trojan Source |
| U+200C | Zero Width Non-Joiner | Trojan Source |
| U+200D | Zero Width Joiner | Trojan Source |
| U+200E | Left-to-Right Mark | Trojan Source |
| U+200F | Right-to-Left Mark | Trojan Source |
| U+202A | Left-to-Right Embedding | Trojan Source |
| U+202B | Right-to-Left Embedding | Trojan Source |
| U+202C | Pop Directional Formatting | Trojan Source |
| U+202D | Left-to-Right Override | Trojan Source |
| U+202E | Right-to-Left Override | Trojan Source |
| U+2060 | Word Joiner | 은닉 |
| U+2061 | Function Application | 은닉 |
| U+2062 | Invisible Times | 은닉 |
| U+2063 | Invisible Separator | 은닉 |
| U+2064 | Invisible Plus | 은닉 |
| U+2066 | Left-to-Right Isolate | Trojan Source |
| U+2067 | Right-to-Left Isolate | Trojan Source |
| U+2068 | First Strong Isolate | Trojan Source |
| U+2069 | Pop Directional Isolate | Trojan Source |
| U+FEFF | BOM / Zero Width No-Break Space | 은닉 |
| U+FE00-FE0F | Variation Selectors 1-16 | GlassWorm |

## Examples

### Example 1: 기본 사용 (기본 브랜치 대비 변경 파일 검사)
User: `/unicode-guard`
→ `git diff main...HEAD --name-only`로 변경 파일 식별 → perl로 보이지 않는 문자 스캔 → 결과 요약

### Example 2: staged 파일 검사
User: `/unicode-guard --staged`
→ `git diff --cached --name-only`로 staged 파일 식별 → 스캔 → 결과 요약

### Example 3: 특정 파일 검사
User: `/unicode-guard src/main/java/com/example/Service.java`
→ 해당 파일만 직접 스캔 → 결과 요약

## Troubleshooting

### "검사 대상 파일이 없습니다"
**원인:** 지정된 scope에서 대상 확장자의 변경 파일이 없음
**해결:** `git status`로 현재 상태 확인. `--staged` 사용 시 `git add`로 staging했는지 확인

### perl이 설치되어 있지 않음
**원인:** perl이 시스템에 없는 경우 (매우 드묾)
**해결:** macOS와 대부분의 Linux에 기본 설치됨. `perl --version`으로 확인. 없으면 `brew install perl` 또는 시스템 패키지 매니저로 설치

### 오탐 (False Positive)
**원인:** 국제화 문자열 리터럴, 테스트 데이터, 문서에서 합법적으로 사용된 BiDi 문자
**해결:** 해당 라인의 컨텍스트를 확인하여 의도적 사용인지 판단. 소스 코드의 문자열 리터럴 밖에서 BiDi/변형 선택자가 발견되면 높은 확률로 악성

## Gotchas

- 바이너리 파일(.class, .jar, 이미지 등)은 스캔 대상에서 자동 제외됨. 대상 확장자 필터로 이미 처리되므로 별도 처리 불필요
- BOM(U+FEFF)은 파일 첫 바이트에 나타나면 합법적인 UTF-8 BOM. 2번째 이후에 나타나면 의심 대상
- perl `-CSD` 플래그 없이 실행하면 멀티바이트 문자를 제대로 인식하지 못함. 반드시 포함할 것

## Validation

- `perl --version`
- `git diff --name-only`
