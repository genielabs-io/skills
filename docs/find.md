# Find — 로컬·Google Drive 파일 검색 스킬 (수업 자료를 말로 찾아보기)

Windows에서 파일명·경로로 파일을 찾고, 미리 만든 내용 색인에서 관련 문서를 검색하는 Codex 스킬입니다. Google Drive 커넥터가 연결되어 있으면 클라우드 파일도 함께 찾습니다.

[저장소 안내로 돌아가기](../README.md)

파일명이 기억나지 않아도 주제·파일 형식·수정 시기 같은 단서부터 말해 보세요. `find`는 Codex가 어디서 검색하고, 조건을 어떻게 좁히고, 결과를 어떻게 보여줄지 정한 지침과 보조 스크립트입니다. 이 저장소에서는 **개별 Codex 스킬**로 설치하며, Google Drive 연결은 별도로 준비합니다.

## 두 가지 검색 방식

| 기억나는 단서 | 요청 예시 | 검색하는 정보 | 준비 사항 |
| --- | --- | --- | --- |
| 제목·폴더·파일 형식·수정 시기 | “드론 수업 PPT 찾아줘” | Everything이 색인한 로컬 파일명·경로 등 파일 정보 | Windows·PowerShell 5.1 이상, Everything 설치·색인·HTTP 설정 |
| 문서 안의 단어·구절 | “드론 안전수칙이 들어 있는 문서와 해당 구절을 보여줘” | 로컬 DB에 미리 추출한 문서 텍스트 | Windows·PowerShell, Python 3.10 이상·SQLite FTS5·추출 패키지·내용 색인 |

Google Drive는 연결된 계정이 접근할 수 있는 파일을 별도로 검색합니다. Drive만 찾는다면 로컬 Everything이나 내용 DB는 필요하지 않습니다. 로컬 본문 검색은 단어 기반이며, 의미가 비슷한 문서를 자동으로 모두 찾아주는 검색은 아닙니다.

스킬 설치 후 **파일명 검색부터 시작**하고, 필요할 때 Drive 연결과 본문 검색을 추가하면 됩니다.

## 1. 스킬 설치

Codex에 아래와 같이 저장소와 스킬 경로를 지정해 설치를 요청하세요.

```text
$skill-installer https://github.com/genielabs-io/skills에서 skills/find 폴더의 스킬을 설치해 줘.
```

스킬 설치를 위해 사용자가 PowerShell 명령을 직접 실행할 필요는 없습니다. 설치가 끝나면 다음 대화 턴에서 `$find`로 사용할 수 있습니다. 기존 `find`가 있으면 자동으로 덮어쓰지 않으므로 백업·교체 여부를 먼저 정하세요.

## 2. 로컬 환경 점검과 첫 검색

다음 요청을 Codex에 입력하세요. 환경 점검은 상태를 확인하고 필요한 조치를 안내하며, 프로그램 설치나 내용 색인 생성을 자동으로 수행하지 않습니다.

```text
$find 로컬 파일명 검색 환경을 점검해 줘. 이미 준비된 항목은 건너뛰고 필요한 설치와 설정을 안내해 줘.
```

Everything이 없다면 [공식 다운로드 페이지](https://www.voidtools.com/downloads/)에서 설치합니다. 검색할 드라이브가 Everything의 색인 대상인지 확인하고, HTTP 서버를 `127.0.0.1:8080`에 설정하며 파일 다운로드는 끕니다. [Everything HTTP 설정](#everything-http-설정)에 자세한 항목이 있습니다.

준비가 끝나면 이름이나 형식을 단서로 첫 검색을 해 보세요.

```text
$find 로컬에서 드론 수업 PPT와 PDF를 찾아줘.
```

기본 범위는 Windows 시스템 드라이브입니다. **C:·D:를 함께 찾거나 연결된 E:를 찾으려면 별도로 지정해야 합니다.** 기존 시연 환경의 드라이브 구성이 설치만으로 복제되지는 않습니다.

```text
$find C 드라이브와 D 드라이브에서 드론 수업 자료를 찾아줘.
```

반복해서 같은 범위를 쓰려면 Codex에 “find의 기본 로컬 검색 범위를 C와 D로 설정해 줘”라고 요청하세요. 범위를 추가해도 Everything이 그 위치를 색인하지 않았다면 검색되지 않습니다.

결과가 많으면 같은 대화에서 “그중 올해 수정한 한글 파일만 보여줘”처럼 조건을 덧붙일 수 있습니다. HWP 파일을 **이름으로 찾는 데는** 본문 추출용 Java·Tika가 필요하지 않습니다.

## 3. Google Drive 연결 — 사용할 때만

1. Codex의 **Plugins(플러그인)** 또는 계정에 표시되는 **Apps(앱)** 화면에서 Google Drive 연결을 제공하는 항목을 확인합니다.
2. 설치가 필요하면 설치하고, 연결 또는 인증 안내에 따라 자료가 있는 Google 계정으로 로그인합니다. 조직에서 관리하는 연결은 관리자 설정이 필요할 수 있습니다.
3. 현재 Codex 대화에서 연결된 Drive 검색을 사용할 수 있는지, 알고 있는 파일명으로 확인합니다.

```text
$find Google Drive 연결을 확인하고, Drive에서 '드론'이 이름에 들어간 자료를 찾아줘.
```

메뉴 명칭과 제공 여부는 계정·워크스페이스에 따라 다릅니다. [OpenAI의 플러그인·앱 연결 안내](https://help.openai.com/en/articles/20001256-plugins-in-chatgpt-and-codex)를 참고하세요. `find` 설치만으로 Google 계정이 연결되지는 않습니다.

연결 후에는 로컬과 Drive를 함께 요청할 수 있습니다.

```text
$find 내 컴퓨터와 Google Drive에서 드론 수업 자료를 찾아줘.
```

Drive 결과에는 내 드라이브뿐 아니라 접근 가능한 공유 파일도 포함될 수 있습니다. 연결되지 않았다면 가능한 로컬 검색 결과와 함께 **Drive는 검색하지 못했다는 안내**가 나옵니다.

## 4. 본문 색인 만들기와 갱신 — 사용할 때만

내용 색인은 문서에서 추출한 텍스트를 검색용 로컬 DB에 저장하는 작업입니다. **Everything의 파일명 색인과는 별개**이며, 파일명 검색만 할 때는 만들 필요가 없습니다.

먼저 준비 상태를 확인합니다.

```text
$find 로컬 문서 본문 검색 환경을 점검해 줘. Python과 문서 추출 패키지, 기존 내용 색인의 상태와 범위를 알려줘.
```

Python 3.10 이상과 SQLite FTS5가 필요합니다. 추출 패키지가 부족하면 설치 안내를 받고, 설치를 진행할 때 Codex에 스킬 전용 가상환경에 준비해 달라고 요청하세요. HWP·구형 DOC/PPT/XLS의 본문 추출에는 Java와 Apache Tika가 추가로 필요합니다.

준비가 끝나면 **자신의 문서가 있는 드라이브를 지정**해 색인 생성을 요청합니다. 아래 C·D는 예시이며, 파일 수에 따라 시간이 걸릴 수 있습니다.

```text
$find C 드라이브와 D 드라이브의 PDF와 PPTX 문서로 내용 색인을 만들어 줘. 완료하면 처리한 파일 수와 추출 오류를 알려줘.
```

색인을 만든 뒤 본문 검색을 요청합니다.

```text
$find 로컬 문서에서 '드론 안전수칙'이 들어 있는 자료와 해당 구절을 짧게 보여줘.
```

새 문서를 추가하거나 문서를 수정한 뒤에는 같은 범위로 갱신을 요청하세요. 갱신이 자동으로 예약되지는 않습니다.

```text
$find C 드라이브와 D 드라이브의 PDF와 PPTX 내용 색인을 갱신해 줘. 완료하면 처리 결과와 오류를 알려줘.
```

색인 생성·갱신에는 Everything HTTP가 필요하지만, 생성된 DB를 검색할 때는 Everything에 접속하지 않습니다. 본문 발췌는 마지막 색인 시점 기준입니다. 스캔 PDF에 OCR을 수행하는 기능은 없고, 한글 어미 변화나 부분 문자열은 검색에서 빠질 수 있습니다.

## 검색 결과 읽기

아래는 **형식 설명을 위한 가상 예시**입니다. 실제 파일·날짜·검색 결과가 아닙니다.

```text
[Local] 드론_수업_교안.pptx
  위치: C:\강의\드론\드론_수업_교안.pptx
  형식: PPTX · 수정일: 2026-09-01

[Google Drive] 드론 교육 과정
  형식: Google Slides · 링크: 검색 도구가 반환한 실제 파일 링크

[Local] 드론_안전수칙.pdf — 본문 검색 결과
  위치: D:\자료\드론_안전수칙.pdf
  발췌: “드론 안전수칙: 비행 전 장비와 주변 환경을 확인한다.”
```

실제 응답에서는 확인된 로컬 경로나 Drive URL이 있으면 파일명이 클릭 가능한 링크로 제공됩니다. 수정일·크기 등은 도구가 제공할 때 표시합니다. 전체 검색 일치 수와 화면에 보여준 수는 다를 수 있으며, 로컬과 Drive 결과는 출처별로 구분합니다.

## 검색이 안 될 때

| 증상 | 확인할 것 / Codex에 요청할 내용 |
| --- | --- |
| D:나 외장 드라이브 자료가 안 나옴 | 요청·기본 설정에 해당 드라이브가 포함됐는지, 연결됐는지, Everything 색인이 있는지 확인 |
| Everything HTTP 오류 | Everything 실행 여부, HTTP 서버·주소·로컬 네트워크 접근 확인. 공개 배포본에는 `es.exe` 대체 검색이 없음 |
| Drive 결과가 없음 | 연결 계정·인증·파일 접근 권한 확인. 알고 있는 파일명으로 Drive만 검색해 보기 |
| 내용 색인이 없다고 나옴 | 해당 드라이브·파일 형식으로 내용 색인 생성 요청 |
| 새 문서나 수정한 구절이 안 나옴 | 같은 범위의 내용 색인 갱신 후 추출 오류 확인 |
| HWP 본문이 검색되지 않음 | 파일명 검색과 본문 검색을 구분하고 Java·Tika 설정 및 추출 오류 확인 |
| 스캔 PDF 내용이 안 나옴 | 이미지에 대한 OCR은 미지원. 텍스트가 있는 문서인지 확인 |
| 검색 결과가 너무 적거나 없음 | 날짜·폴더·형식 조건을 줄이고, 핵심 단어나 가까운 동의어로 다시 요청 |

```text
$find 방금 검색에서 확인한 드라이브와 파일 형식, Drive 연결 여부, 내용 색인의 범위를 알려줘. 빠진 범위가 있는지 확인해 줘.
```

## 원본 파일과 색인 보관

검색은 원본 파일을 수정·이동·삭제하지 않습니다. 색인 생성·갱신은 요청한 범위의 문서를 읽고 로컬 DB에 추출 텍스트를 저장합니다. 개인 문서와 DB는 배포물에 포함되지 않으며, Google Drive 파일을 내려받아 로컬 색인에 넣는 기능도 없습니다.

DB는 기본적으로 `%LOCALAPPDATA%\find-skill\content-index.db`에 저장됩니다. 문서 내용이 들어 있으므로 저장소나 동기화 폴더 밖에 보관하세요.

## 수동 설정과 고급 사용

아래 명령은 직접 환경을 점검하거나 설정하려는 사용자를 위한 참고입니다. 위의 자연어 요청으로 시작했다면 필요한 항목만 확인하세요.

<details>
<summary>선택 사항: 내려받은 폴더를 수동으로 설치하기</summary>

설치 도구 대신 직접 복사하려면 저장소의 `skills/find` 폴더를 `$CODEX_HOME/skills/find`에 둡니다. `CODEX_HOME`이 없으면 기본 위치는 `~/.codex/skills/find`입니다. 탐색기로 복사해도 됩니다.

다음은 같은 작업을 수행하는 PowerShell 예시입니다. 저장소 루트에서 실행하며, 기존 스킬이 있으면 중단합니다.

```powershell
$skillHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
$skillsDir = Join-Path $skillHome 'skills'
$destination = Join-Path $skillsDir 'find'
if (Test-Path -LiteralPath $destination) { throw '기존 find 스킬이 있습니다. 백업 후 설치하세요.' }
New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null
Copy-Item -LiteralPath '.\skills\find' -Destination $destination -Recurse
```

</details>

### 명령 실행 위치와 환경

스킬 설치는 지침과 보조 파일을 Codex가 읽을 위치에 배치하는 작업입니다. Everything이나 Python 같은 외부 프로그램까지 설치하지는 않습니다. 로컬 검색 기능을 사용하려면 아래 실행 환경을 별도로 준비해야 합니다. Codex에 필요한 설정을 도와 달라고 요청할 수도 있습니다.

이 스킬의 Windows 로컬 검색 보조 스크립트는 PowerShell 기반이며, 내용 색인·검색의 핵심 코드는 Python으로 작성되어 있습니다. 아래 PowerShell 명령은 **설치된 `find` 폴더**에서 직접 설정하거나 점검할 때 사용하는 예시입니다. Windows PowerShell 5.1 이상을 대상으로 작성했으며, 실행 정책 때문에 차단되면 조직 또는 개인 환경의 정책에 따라 처리하세요.

### 환경 점검 명령

설치 후 Codex에 다음처럼 요청하세요.

```text
$find 실행 환경을 점검해 줘. 이미 준비된 항목은 건너뛰고, 설치나 설정이 필요한 항목을 알려줘.
```

스킬은 첫 로컬 검색 전에 `scripts/setup.ps1`로 해당 기능의 준비 상태를 점검합니다. 기본 실행은 점검과 안내만 하며 프로그램 설치나 설정 변경은 하지 않습니다. 직접 실행할 수도 있습니다.

```powershell
& '.\scripts\setup.ps1'                         # 전체 환경 점검
& '.\scripts\setup.ps1' -Scope Metadata         # 파일명 검색에 필요한 항목만
& '.\scripts\setup.ps1' -Scope Content -Json    # Python·SQLite·추출 패키지; HTTP 접속 없음
```

PowerShell 실행 파일을 찾기 어렵다면 명령 프롬프트에서 `scripts\setup.cmd`를 실행하세요. 사용 가능한 PowerShell을 찾아 점검을 시작하며, 없으면 설치 안내를 출력합니다.

이미 사용할 수 있는 항목은 `ready`로 표시하고 설치를 건너뜁니다. 버전이 맞지 않거나 필요한 항목이 없으면 `action_required`와 조치 방법을 표시합니다. Everything이 설치돼 있어도 HTTP 서버가 꺼져 있으면 설정을 안내하며, 이를 미설치로 단정하지 않습니다. HTTP 다운로드 허용 여부·검색 범위·실제 내용 색인은 별도 확인 항목으로 표시합니다.

Python은 내용 검색에만 필요합니다. 추출 패키지를 준비하려면 다음 옵션을 명시합니다. 이미 준비된 환경은 그대로 사용하고, 부족한 경우 스킬 전용 `.venv`에 설치한 뒤 다시 검증합니다. 시스템 Python의 패키지는 변경하지 않습니다.

```powershell
& '.\scripts\setup.ps1' -Scope Content -InstallPythonPackages
```

이 옵션은 패키지를 다운로드할 수 있습니다. PowerShell·Python·Everything 프로그램 자체는 공식 설치 링크와 설정 방법을 안내하며 자동 설치하지 않습니다. 준비가 끝나면 점검을 다시 실행하세요. 결과 항목과 기능별 준비 기준은 [환경 구성 안내](../skills/find/references/setup.md)에 있습니다.

### Everything HTTP 설정

Everything에서 검색할 드라이브·폴더가 색인 대상인지 확인하고 HTTP 서버를 다음처럼 설정합니다. HTTP 메뉴나 플러그인 구성은 설치한 Everything 버전에 따라 다를 수 있습니다.

```text
Enable HTTP server: 켬
Bind to interfaces: 127.0.0.1
Listen on port: 8080
Allow file download: 끔
```

설정 항목은 [Everything 공식 HTTP 문서](https://www.voidtools.com/support/everything/http/)를 참고하세요. 이 스킬은 HTTP JSON 응답을 사용합니다. 기본 주소는 `http://127.0.0.1:8080/`이며, `-Endpoint`, `EVERYTHING_HTTP_URL`, `config/http-url.txt` 순으로 덮어쓸 수 있습니다. 점검·검색·색인 갱신 모두 루프백 HTTP(S) 주소만 허용하며 리디렉션을 따르지 않습니다. 인증 헤더를 별도로 지정하는 기능은 제공하지 않습니다.

```powershell
& '.\scripts\find-files.ps1' -Query '보고서' -Limit 20
```

로컬 파일명 검색은 HTTP만 사용합니다. HTTP 요청이 실패하면 오류를 반환하며 다른 실행 파일로 전환하지 않습니다. `es.exe`는 이 공개용 버전에서 지원하지 않습니다. 자세한 설정은 [검색 안내](../skills/find/references/search-guide.md)를 참고하세요.

### 기본 드라이브 설정

기본 범위는 Windows 시스템 드라이브입니다. 설치된 스킬의 `config/search-config.json`에 원하는 드라이브를 지정하면 파일명 검색과 기본 내용 색인이 함께 사용합니다.

```json
{
  "drives": ["C", "D", "E"]
}
```

빈 배열은 시스템 드라이브를 뜻합니다. 연결된 이동식 드라이브를 자동으로 추가하지 않습니다. A–Z 드라이브를 지정할 수 있으며, Everything이 해당 위치를 색인하고 있어야 합니다.

```powershell
& '.\scripts\find-files.ps1' -Query '드론 수업' -Drives D,F -Extensions pptx,pdf,hwp,hwpx -Limit 30
```

`-Drives All`은 파일명 검색에서만 지원하며 Everything이 색인한 모든 위치를 대상으로 합니다. 내용 검색은 이미 DB에 저장된 문서만 검색합니다.

### Python과 내용 색인 명령

환경 점검에서 내용 검색에 필요한 항목이 준비되어 있으면 추가 설치를 건너뛰세요. Python이 발견되지 않았더라도 기존 설치 경로를 먼저 확인합니다. Python 자체가 없다면 점검 결과의 공식 설치 링크를 따르고, 추출 패키지만 부족하면 전용 구성 옵션을 실행합니다.

```powershell
& '.\scripts\setup.ps1' -Scope Content
# 추출 패키지 설치를 진행할 때만 실행합니다. 준비된 환경은 건너뜁니다.
& '.\scripts\setup.ps1' -Scope Content -InstallPythonPackages
```

보조 스크립트는 `-PythonPath` → `CODEX_PYTHON_PATH` → 스킬 내부 `.venv` → PATH의 `python.exe` → Windows의 표준 Python 등록 정보 순서로 Python을 찾습니다. 지정한 실행 파일이 없으면 다른 환경으로 조용히 전환하지 않고 오류를 냅니다. 환경 구성 결과가 반환한 `PythonPath`를 이후 명령의 `-PythonPath`에 전달하면 같은 환경을 사용할 수 있습니다.

HWP·구형 DOC/PPT/XLS를 추출하려면 [Apache Tika](https://tika.apache.org/)의 App JAR과 Java를 별도로 설치하고 경로를 지정하세요. 저장소에는 Tika나 Java를 포함하지 않습니다.

```powershell
$env:TIKA_APP_PATH = 'C:\Tools\Tika\tika-app.jar'
```

위 경로는 예시이며 실제 설치 위치로 바꿔야 합니다. 이 설정은 현재 PowerShell 세션에만 적용됩니다.

내용 색인은 기본적으로 `%LOCALAPPDATA%\find-skill\content-index.db`에 저장됩니다. `-Database` 또는 `EVERYTHING_CONTENT_DB`로 다른 위치를 지정할 수 있습니다. DB에는 개인 문서 내용이 들어가므로 저장소나 동기화 폴더 밖에 보관하세요.

```powershell
# 파일 수에 따라 오래 걸릴 수 있습니다. 지정 범위의 문서를 읽어 DB를 만듭니다.
& '.\scripts\update-content-index.ps1' -Drives C,D

# 이후 내용 검색은 Everything에 접속하지 않습니다.
& '.\scripts\search-content.ps1' -Query '드론 안전수칙' -Limit 20

# 색인 상태: 점검 결과의 PythonPath를 사용합니다.
$check = & '.\scripts\setup.ps1' -Scope Content -Json | ConvertFrom-Json
& $check.PythonPath '.\scripts\content-index.py' status
```

스캔 PDF OCR은 지원하지 않습니다. 검색은 단어 기반이므로 한글 어미 변화나 부분 문자열을 놓칠 수 있습니다. 형식별 지원 범위, 실패한 추출 재시도, `-Prune` 조건은 [내용 색인 안내](../skills/find/references/content-index.md)를 확인하세요.


## 저장소 구성

```text
skills/find/
  SKILL.md
  LICENSE
  agents/openai.yaml
  config/
  references/
  scripts/
  requirements.txt
tests/find/
```

저장소 폴더 이름은 자유롭게 정할 수 있습니다. 설치할 스킬 폴더의 이름은 `find`이며 호출 이름은 `$find`입니다. `find` 폴더만 설치해도 필요한 스크립트·참고 문서·MIT 라이선스가 함께 포함됩니다.

## 개발 검증

저장소 루트에서 실행합니다. 테스트는 임시 문서·DB와 모의 Everything 서버를 사용합니다. 개인 문서나 실제 내용 DB를 읽거나 갱신하지 않습니다.

```powershell
$check = & '.\skills\find\scripts\setup.ps1' -Scope Content -Json | ConvertFrom-Json
if (-not $check.ContentRuntimeReady) { throw '먼저 점검 결과에 따라 Python 환경을 준비하세요.' }
& $check.PythonPath -B -m unittest discover -s tests/find -v
```

선택 패키지가 필요한 테스트는 해당 패키지를 설치한 환경에서 실행하세요. 실제 Everything·Google Drive 연결 검증은 별도입니다.

환경 구성 테스트는 누락된 프로그램 안내, 읽기 전용 점검, 준비된 환경 건너뛰기, 가상환경 한정 설치와 재검증을 다룹니다. 패키지 설치 분기는 모의 실행으로 검증하며 실제 다운로드를 하지 않습니다. Windows PowerShell의 실행 정책으로 차단된 호환성 테스트는 정책을 바꾸거나 우회하지 않고 건너뜀으로 보고합니다.

## 공개 전 확인

개인 DB, 캐시, 로그, JAR, 가상환경은 `.gitignore`에서 제외합니다. 실제 개인 경로는 환경변수로 설정하고 공개용 설정 파일에는 남기지 마세요.

## 라이선스

`find`를 포함한 이 저장소의 모든 스킬과 문서는 [MIT 라이선스](../LICENSE)로 배포합니다. 개별 설치에도 고지가 포함되도록 [find 폴더의 LICENSE](../skills/find/LICENSE)를 유지합니다. 저작권 및 허가 고지를 유지하면 상업적 이용을 포함해 사용, 수정, 복제, 배포할 수 있습니다. 소프트웨어는 보증 없이 제공됩니다. 외부 도구와 의존 패키지에는 각각의 라이선스가 적용됩니다.
