> **Note:** This repository contains GenieLabs skills for Claude Code and Codex. Supported environments vary by skill. For information about the Agent Skills standard, see [agentskills.io](https://agentskills.io).
> 
# genielabs-io Skills

Bridging Education and Innovation.

We believe education is the foundation of innovation. GenieLabs supports students, startups, and communities through AI transformation, software excellence, and practical coding education.

This repository distributes the skills we use to make AX-powered coding workflows more accessible, repeatable, and useful in real learning and building environments.

## Included Skills

| Skill | Purpose | Distribution / environment |
| --- | --- | --- |
| `wrap` | Summarize a session and extract reusable lessons | Claude Code bundle; uses Claude session paths |
| `unicode-guard` | Scan changed files for hidden Unicode characters | Claude Code bundle |
| `find` | Find local files, search indexed document text, and search connected Google Drive | Individual Codex skill; Windows for local search |

## Install Find in Codex

파일명이 정확히 기억나지 않아도 주제·파일 형식·수정 시기 같은 단서를 Codex에 말해 보세요. `find`는 내 Windows 컴퓨터와 연결된 Google Drive에서 자료를 찾아 위치와 링크를 보여주는 스킬입니다. 미리 내용 색인을 만들어 두면 문서 안의 단어로도 찾고, 관련 구절을 짧게 확인할 수 있습니다.

### 이렇게 요청하세요

아래는 환경 준비 후 사용할 수 있는 예시입니다. Drive 검색에는 계정 연결이, 본문 검색에는 내용 색인이 필요합니다.

```text
$find 내 컴퓨터와 Google Drive에서 드론 수업 자료를 찾아줘.
$find 로컬에서 올해 수정한 수업 계획서 중 한글 파일만 찾아줘.
$find 로컬 문서에서 '개인정보 보호'가 들어 있는 자료와 해당 구절을 보여줘.
```

### 필요한 것만 준비하세요

Codex에서 아래 스킬을 설치한 뒤, 사용할 기능에 맞춰 준비합니다.

| 하고 싶은 일 | 필요한 준비 |
| --- | --- |
| 내 컴퓨터에서 파일명·경로로 찾기 | Windows, PowerShell 5.1 이상, Everything 설치·검색 대상 색인·HTTP 설정 |
| Google Drive에서 찾기 | Google Drive 플러그인/앱 연결 및 계정 인증 |
| 로컬 문서의 본문에서 찾기 | Windows·PowerShell, Python 3.10 이상과 SQLite FTS5, 문서 추출 패키지·내용 색인. 색인 생성·갱신에는 Everything HTTP 필요 |

Drive 연결과 본문 색인은 해당 기능을 사용할 때만 준비하면 됩니다. HWP·구형 Office의 **본문 추출**에는 Java와 Apache Tika가 추가로 필요합니다.

### 설치 → 환경 점검 → 첫 검색

**1. 설치:** Codex에 아래 요청을 입력하세요. 이 저장소에서는 `find`를 개별 스킬로 배포합니다.

```text
$skill-installer https://github.com/genielabs-io/skills에서 skills/find 폴더의 스킬을 설치해 줘.
```

**2. 환경 점검:** 설치 후 다음 대화 턴에서 아래 요청을 입력하고, 필요한 준비를 마치세요. 스킬 설치만으로 Everything·Python 설치나 내용 색인 생성이 이루어지지는 않습니다.

```text
$find 로컬 파일명 검색 환경을 점검해 줘. 이미 준비된 항목은 건너뛰고 필요한 설치와 설정을 안내해 줘.
```

**3. 첫 검색:** 먼저 파일명으로 찾고, 결과를 보며 조건을 좁혀 보세요.

```text
$find 로컬에서 드론 수업 PPT와 PDF를 찾아줘.
```

기본 로컬 검색 범위는 **Windows 시스템 드라이브**입니다. D:나 외장 드라이브도 찾으려면 검색 요청에 지정하거나 기본 범위에 추가해야 하며, Everything이 해당 위치를 색인하고 있어야 합니다.

검색은 원본 파일을 수정하지 않습니다. 본문 검색은 마지막 색인 시점의 텍스트를 사용하며, 스캔 PDF의 OCR은 지원하지 않습니다.

**[강사용 상세 안내: Drive 연결 · 내용 색인 생성/갱신 · 결과 예시 · 검색이 안 될 때](docs/find.md)**

직접 설정하거나 개발하려면 [수동 설정과 고급 사용](docs/find.md#수동-설정과-고급-사용), [테스트 실행 안내](docs/find.md#개발-검증)를 참고하세요.

## Try In Claude Code

### Claude Code

You can register this repository as a Claude Code plugin marketplace by running the following command in Claude Code:

```text
/plugin marketplace add genielabs-io/skills
```

Then install the bundled plugin:

```text
/plugin install genielabs-skills@genielabs-io
```

The Claude Code bundle contains `wrap` and `unicode-guard`. Install `find` separately in Codex using the instructions above.

After installing the plugin, you can use the skills by mentioning them naturally. For example:

```text
Use the unicode-guard skill to scan the staged files for hidden Unicode characters.
Use the wrap skill to summarize this session and extract reusable lessons.
```

## License

이 저장소의 모든 스킬과 문서는 [MIT 라이선스](LICENSE)로 배포합니다. 개별 스킬 폴더에도 라이선스 고지를 포함합니다. 외부 도구와 의존 패키지에는 각각의 라이선스가 적용됩니다.
