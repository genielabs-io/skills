# Document content index

Read this when setting up, checking, or updating the local SQLite FTS5 index. Filename search works independently of this index.

## Dependencies and configuration

Use Python 3.10+ with SQLite FTS5. Start with `scripts/setup.ps1 -Scope Content` to check installed components; see [setup.md](setup.md) for optional package installation and verification. Script runtime resolution is: `-PythonPath`, `CODEX_PYTHON_PATH`, skill-local `.venv`, `python.exe` on PATH, then standard Windows Python registry entries. No private Codex runtime path is assumed.

The database path resolves from `-Database` / `--db`, `EVERYTHING_CONTENT_DB`, `config/index-path.txt`, then `%LOCALAPPDATA%\find-skill\content-index.db`. If LOCALAPPDATA is unavailable, the fallback is `~/.local/share/find-skill/content-index.db`. Keep it outside the repository and synced folders.

`config/search-config.json` contains a `drives` list, such as `["C", "D"]`. Empty means the Windows system drive. Both metadata search and default index updates use this configuration. `-Drives D,F` overrides it for that update. Do not assume a connected drive has been indexed.

`config/index-config.json` sets exclusions, maximum text length, PDF page and spreadsheet cell limits, and Tika's extraction timeout. The timeout currently applies to Tika only; Python extractors have no per-file timeout. Do not treat this as a sandbox for untrusted documents.

## Build and update

From the installed skill folder, after the user requests indexing:

```powershell
& '.\scripts\update-content-index.ps1' -Drives C,D
```

Default formats: PDF, PPT/PPTX, DOC/DOCX, XLS/XLSX, HWP/HWPX. Use `-Extensions` to include plain text or other supported types. The HTTP query reads candidate metadata, and extractors read matching source files. Only SQLite is written. Files larger than 100 MB are skipped by default (`-MaxFileSizeMB` overrides this).

Updates compare file size and modification time; unchanged successful extractions are skipped. Failed extractions are retried on the next run. Progress appears every 25 candidates and changes commit in batches of 20 indexed files. After interruption, repeat the same command to resume. Scope changes do not automatically remove old content.

A bounded update can use a custom Everything query and its own database:

```powershell
& '.\scripts\update-content-index.ps1' -EverythingQuery 'path:"C:\Example Documents" file: ext:pdf;docx' -Database "$env:LOCALAPPDATA\find-skill\example.db"
```

`-EverythingQuery` is an advanced query and replaces the generated drive/extension query. Do not combine it with `-Drives`; put extension filters in the query itself.

## Pruning

`-Prune` removes database rows absent from the completed Everything result set. Use it only when all configured drives are connected and Everything's index is complete. An empty but valid response cannot establish that a disconnected drive was intentionally removed.

The updater rejects pruning with inaccessible configured drive roots, a custom query, malformed JSON/results, incomplete/changing/duplicate pagination, or a database populated under a different scope. Accessible roots do not prove Everything's index is complete; confirm coverage separately. Scope includes the query, exclusions, and file-size limit. A database updated across multiple scopes cannot be pruned; use a new database for the desired scope. Older databases without scope metadata also cannot be pruned automatically.

```powershell
& '.\scripts\update-content-index.ps1' -Drives C,D -Prune
```

The drive and extension selection must match the original build. Run without `-Prune` when unsure. Pruning changes only index rows, never original files.

## Search and status

```powershell
& '.\scripts\search-content.ps1' -Query '드론 안전수칙' -Extensions pdf,pptx,hwp,hwpx
$check = & '.\scripts\setup.ps1' -Scope Content -Json | ConvertFrom-Json
& $check.PythonPath '.\scripts\content-index.py' status
```

Search opens SQLite read-only without querying Everything or source documents. Terms are combined with AND; quotes preserve a phrase. This is token-based search, not substring or semantic matching. Results include `total_results`, returned `count`, and short excerpts from the last indexed version. Status reports coverage by extension, errors, last completed update and query. A missing database produces an explicit search error.

`-Path` / `--path` with an absolute path matches that exact file or descendants of that folder, not similarly named siblings. A relative fragment searches literally within the stored path. `%` and `_` are treated as literal characters, not SQL wildcards.

## Format coverage

- Standard library: TXT, MD, CSV, LOG, JSON, XML, HTML, HWPX.
- Text decoding: UTF-8 (with or without BOM), BOM-marked UTF-16, then CP949. UTF-16 without a BOM is not auto-detected.
- Python packages: DOCX (`python-docx`), PPTX/PPTM (`python-pptx`), XLSX/XLSM (`openpyxl`), PDF (`pypdf`). DOCX and PPTX have an XML fallback if their packages are missing.
- Optional Apache Tika App plus Java: HWP and legacy DOC, PPT, XLS. Set `TIKA_APP_PATH` to the separately installed JAR. Java requirements depend on the chosen Tika release.
- Scanned PDFs need OCR, which is not included. Encrypted, malformed, or unsupported documents may produce errors or empty text. Formulas use saved spreadsheet values, not recalculation.

## Scheduling and privacy

The database contains extracted private text. Restrict filesystem access to the current user and never share it as a diagnostic artifact. This project does not create scheduled tasks. If explicitly requested, configure a Windows Task Scheduler job as the current user with the installed skill folder as its working directory. Ordinary searches need no update job or HTTP access when using existing indexed contents.
