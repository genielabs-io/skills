# Environment setup and verification

## Entry points

From the installed `find` folder:

```powershell
& '.\scripts\setup.ps1'                         # Check everything; make no changes
& '.\scripts\setup.ps1' -Scope Metadata -Json  # PowerShell + Everything HTTP
& '.\scripts\setup.ps1' -Scope Content -Json   # Python/SQLite/packages; no HTTP
```

For a command-prompt entry point, use `scripts\setup.cmd`. It locates `pwsh.exe` or `powershell.exe`; if neither exists, it prints the official PowerShell installation link. It does not bypass execution policy or install PowerShell. Because a PowerShell script cannot run without a compatible PowerShell, this launcher handles the missing-shell case.

## Check results

- `ready`: already available and compatible; skip installation.
- `action_required`: install/configure/repair the named component using `Action`.
- `not_detected`: executable discovery missed it; this alone is not proof of absence.
- `manual_check`: requires separate confirmation; never silently count this as verified.
- `optional`: not needed for standard metadata search or modern-format extraction.

`MetadataReady` checks Windows/PowerShell and an Everything-compatible JSON response from a loopback URL. The request uses a random filename and returns at most one result, whose contents are not included in the report. It does not verify download permissions or indexed drive coverage. HTTP failure can be caused by a stopped/disabled server, wrong port, or network restrictions, even when Everything is installed. Redirects and non-loopback URLs are rejected by this diagnostic.

`ContentRuntimeReady` checks PowerShell, Python 3.10+ and a real in-memory SQLite FTS5 operation. `ExtractionReady` additionally checks every requirement's installed version and import. Existing index queries need neither those extraction packages nor HTTP. `-Scope Content` makes no HTTP requests and does not read or create the content database. Check index status separately before content search. Updating an index also requires Everything HTTP.

`Ready` summarizes automated checks for the chosen scope: Metadata requires metadata readiness, Content requires extraction readiness, All requires both. It does not include manual or optional checks. Default exit code is zero when the check completed even if components are missing. Use `-Strict` to return exit code 1 when `Ready` is false. Script execution/setup failures are also nonzero.

## Prepare missing components

1. If PowerShell is already usable, skip installation. Otherwise use the [Microsoft installation instructions](https://learn.microsoft.com/powershell/scripting/install/install-powershell-on-windows).
2. If Everything HTTP responds, skip Everything installation. If the executable is present but HTTP fails, configure/start its HTTP server. If not installed, use [voidtools downloads](https://www.voidtools.com/downloads/). Confirm `127.0.0.1` binding, the intended port, file downloads disabled, and selected drive coverage using the [HTTP documentation](https://www.voidtools.com/support/everything/http/).
3. For content features, use an existing Python 3.10+ interpreter. Discovery checks `-PythonPath`, `CODEX_PYTHON_PATH`, skill-local `.venv`, PATH, then standard Windows Python registry entries. An invalid explicit path is reported, not silently ignored. Portable/unregistered installs may need `-PythonPath`. If absent, use [Python for Windows](https://www.python.org/downloads/windows/).
4. Re-run the check after external installation/configuration. It does not install OS programs, change PATH, restart applications, create scheduled tasks, or change Everything settings.

## Optional Python package setup

Only after dependency setup is requested/authorized:

```powershell
& '.\scripts\setup.ps1' -Scope Content -InstallPythonPackages -Json
# Use -PythonPath 'C:\...\python.exe' when interpreter discovery needs help.
```

If the selected Python already satisfies all requirements, the script returns `Installation.Status: skipped` and makes no changes. Otherwise it creates or reuses the installed skill's `.venv`, invokes pip there, and reruns version/import verification. A complete existing `.venv` is reused; an incomplete or incompatible one causes an error instead of being overwritten. No packages are installed into the system interpreter. Pip can download packages and dependencies; an offline/cache-only mode is not provided.

Before pip runs, the script checks that the interpreter reports a real virtual environment whose resolved prefix is this skill's `.venv`. A copied system interpreter or a virtual environment pointing elsewhere is rejected.

Use the returned `PythonPath` with `-PythonPath` in subsequent content scripts, especially when `CODEX_PYTHON_PATH` or an explicit path points elsewhere. A new `.venv` is otherwise found automatically. Repeating setup skips already-satisfied requirements. A failed install leaves the partial environment for inspection and retry; it does not delete it. The script does not install Java/Tika, and does not build an index.

For HWP and legacy Office, install Java compatible with the chosen Apache Tika App and set `TIKA_APP_PATH` separately. This optional dependency is identified as a manual prerequisite, not falsely certified as working. See [content-index.md](content-index.md).
