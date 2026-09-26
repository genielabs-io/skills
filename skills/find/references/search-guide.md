# Everything search guide

Read this reference when a simple keyword/extension search is ambiguous, when a date/path expression is needed, or when diagnosing the local HTTP server.

## Scope and endpoint

Default drives come from `config/search-config.json`; an empty list means the Windows system drive. `-Drives C,F` overrides this; `-Drives All` searches all Everything-indexed locations. No drive is automatically indexed or added on connection.

Endpoint resolution is `-Endpoint`, `EVERYTHING_HTTP_URL`, `config/http-url.txt`, then `http://127.0.0.1:8080/`. Local metadata search uses HTTP only. On failure, the helper returns an error instead of attempting another transport.

All helpers require a loopback HTTP(S) URL without embedded credentials, query, or fragment, and reject redirects. Invalid response schemas are errors, not empty search results.

Results report total matches and returned matches separately. This distribution does not support `es.exe` or depend on Windows window-message IPC.

## PowerShell examples

Use the helper for normalized JSON output:

```powershell
& 'C:\path\to\find\scripts\find-files.ps1' `
  -Query '인공지능 강의' `
  -Extensions pptx,pdf,hwp,hwpx `
  -Drives C,D `
  -Modified 'thisyear' `
  -Sort Newest `
  -Limit 30
```

Override the local endpoint when needed:

```powershell
& '.\scripts\find-files.ps1' -Query '드론' -Endpoint 'http://127.0.0.1:8080/'
```

## Useful Everything expressions

- `ext:pptx;pdf;hwp;hwpx` — whole-extension list.
- `dm:today`, `dm:thisweek`, `dm:2weeks` — recent modifications.
- `dm:2026-01-01..today` — ISO date range; ISO avoids locale ambiguity.
- `c:` or `d:` — restrict to a drive.
- `path:교안` — require text somewhere in the full path.
- `file:` / `folder:` — files only / folders only.
- `term1 term2` — AND; both terms must match.
- `term1|term2` — OR.
- `<term1|term2> ext:pdf` — group an OR expression before applying another filter.
- `!임시` — exclude a term.

The helper sets HTTP `path=1`, so ordinary text may match either a filename or its full path. Quote a phrase or path inside `-Query` when it must be literal.

## Direct HTTP JSON request

```powershell
$query = [Uri]::EscapeDataString('<c:|d:> file: 드론 ext:pptx;pdf;hwp;hwpx')
$url = "http://127.0.0.1:8080/?search=$query&json=1&path=1&path_column=1&size_column=1&date_modified_column=1&count=30&sort=date_modified&ascending=0"
Invoke-RestMethod -Uri $url
```

Everything HTTP dates are Windows FILETIME values. The helper converts them to ISO-8601 UTC. It also joins the HTTP response's separate `path` and `name` fields into `FullPath`.

## Diagnostics

- Confirm `http://127.0.0.1:8080/` opens before debugging query syntax.
- Keep `Bind to interfaces` set to `127.0.0.1` and `Allow file download` disabled.
- If Codex reports blocked network access, grant local network access for the search call and retry once.
- Search is limited to locations indexed by Everything. Check Everything's index options if a known file in the requested scope never appears.
- Avoid `content:` unless the user explicitly asks for content search. It is slower than filename/path searches.

Official documentation:

- <https://www.voidtools.com/support/everything/http/>
- <https://www.voidtools.com/support/everything/searching/>
- <https://www.voidtools.com/support/everything/search_functions/>
