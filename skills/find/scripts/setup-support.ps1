# Functions only: dot-sourcing this file performs no checks or installations.
function Invoke-FindPythonProbe {
    param([string]$Python)
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $Python -B (Join-Path $PSScriptRoot 'check-python.py') 2>&1)
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    if ($code -ne 0) { throw "Python dependency probe failed: $($output -join ' ')" }
    return ($output -join "`n" | ConvertFrom-Json)
}

function Find-EverythingInstallation {
    $command = Get-Command Everything.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    foreach ($process in @(Get-Process -Name Everything,Everything64 -ErrorAction SilentlyContinue)) {
        if ($process.Path) { return $process.Path }
    }
    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA)) {
        if (-not $base) { continue }
        foreach ($relative in @('Everything\Everything.exe', 'Everything 1.5a\Everything.exe', 'Everything 1.5a\Everything64.exe')) {
            $candidate = Join-Path $base $relative
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
        }
    }
    return $null
}

function Get-SetupEndpoint {
    param([string]$Explicit)
    return Resolve-HttpEndpoint -ExplicitEndpoint $Explicit
}

function Get-FindEnvironment {
    param([string]$Scope = 'All', [string]$PythonPath, [string]$Endpoint)
    $checks = [System.Collections.Generic.List[object]]::new()
    function Add-Check {
        param($Name, $Status, $Detail, $Action = '')
        $checks.Add([pscustomobject]@{ Name=$Name; Status=$Status; Detail=$Detail; Action=$Action })
    }
    $windowsReady = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
    $shellReady = $windowsReady -and $PSVersionTable.PSVersion -ge [version]'5.1'
    if ($shellReady) {
        Add-Check 'PowerShell' 'ready' ("{0}; already available, skip installation." -f $PSVersionTable.PSVersion)
    } else {
        Add-Check 'PowerShell' 'action_required' 'Windows and PowerShell 5.1+ are required for local helpers.' 'See https://learn.microsoft.com/powershell/scripting/install/install-powershell-on-windows'
    }
    $metadataReady = $null
    if ($Scope -ne 'Content') {
        $metadataReady = $false
        $installed = Find-EverythingInstallation
        if ($installed) {
            Add-Check 'Everything installation' 'ready' "$installed; skip installation."
        } else {
            Add-Check 'Everything installation' 'not_detected' 'No executable found in PATH, running processes, or common locations; portable installs may be elsewhere.'
        }
        try {
            $base = Get-SetupEndpoint $Endpoint
            $query = [Uri]::EscapeDataString('file: "find-environment-probe-' + [Guid]::NewGuid().ToString('N') + '"')
            $reply = Invoke-RestMethod -Uri ($base + '?json=1&count=1&search=' + $query) -TimeoutSec 5 -MaximumRedirection 0
            Assert-EverythingResponse -Response $reply
            Add-Check 'Everything HTTP' 'ready' "$base responds with Everything JSON; skip installation."
            if (-not $installed) {
                $checks[$checks.Count - 2].Status = 'ready'
                $checks[$checks.Count - 2].Detail = 'An Everything-compatible HTTP service is available; executable location is not needed.'
            }
            $metadataReady = $shellReady
        } catch {
            $action = 'Start Everything, enable its HTTP server on 127.0.0.1:8080, and check local network permission. See https://www.voidtools.com/support/everything/http/'
            if (-not $installed) { $action += ' If Everything is not installed, get it from https://www.voidtools.com/downloads/; do not reinstall a portable copy just because detection missed it.' }
            Add-Check 'Everything HTTP' 'action_required' $_.Exception.Message $action
        }
        Add-Check 'HTTP safety and coverage' 'manual_check' 'The JSON probe cannot verify file-download settings or complete drive coverage.' 'Confirm loopback binding, Allow file download OFF, and the intended indexed drives in Everything.'
    }
    $runtimeReady = $null
    $extractionReady = $null
    $resolvedPython = $null
    if ($Scope -ne 'Metadata') {
        $runtimeReady = $false
        $extractionReady = $false
        try {
            $resolvedPython = Resolve-Python $PythonPath
            $probe = Invoke-FindPythonProbe $resolvedPython
            if ($probe.supported) {
                Add-Check 'Python' 'ready' ("{0}: {1}; skip installation." -f $probe.version, $resolvedPython)
            } else {
                Add-Check 'Python' 'action_required' ("Python {0} is below 3.10." -f $probe.version) 'Install Python 3.10+ from https://www.python.org/downloads/windows/ and rerun with -PythonPath pointing to python.exe.'
            }
            if ($probe.fts5) { Add-Check 'SQLite FTS5' 'ready' 'In-memory FTS5 creation succeeded; no database was written.' }
            else { Add-Check 'SQLite FTS5' 'action_required' $probe.fts5_error 'Use a Python distribution with SQLite FTS5 enabled; SQLite is not a separate pip package.' }
            foreach ($package in $probe.packages) {
                if ($package.ready) { Add-Check $package.name 'ready' ("{0}; skip installation." -f $package.version) }
                else { Add-Check $package.name 'action_required' $package.detail 'For document extraction, run setup.ps1 -Scope Content -InstallPythonPackages after authorizing the local virtual environment and package downloads.' }
            }
            $runtimeReady = $shellReady -and $probe.supported -and $probe.fts5
            $extractionReady = $runtimeReady -and @($probe.packages | Where-Object { -not $_.ready }).Count -eq 0
        } catch {
            Add-Check 'Python' 'action_required' $_.Exception.Message 'If Python is already installed, pass its python.exe path with -PythonPath. Otherwise install Python 3.10+ from https://www.python.org/downloads/windows/ and rerun.'
        }
        Add-Check 'Content index' 'manual_check' 'An index is needed for content search; this check does not open or create your content database.' 'After environment setup, inspect content-index.py status. Build or update an index only for a user-requested scope.'
        Add-Check 'Legacy formats' 'optional' 'HWP and legacy DOC/PPT/XLS need Java and Apache Tika; these are not needed for other supported formats.' 'If legacy formats are needed, install Java appropriate for the Tika release and set TIKA_APP_PATH. See https://tika.apache.org/'
    }
    $ready = $shellReady
    if ($Scope -ne 'Content') { $ready = $ready -and $metadataReady }
    if ($Scope -ne 'Metadata') { $ready = $ready -and $extractionReady }
    return [pscustomobject]@{
        Scope=$Scope; Ready=[bool]$ready; MetadataReady=$metadataReady; ContentRuntimeReady=$runtimeReady
        ExtractionReady=$extractionReady; PythonPath=$resolvedPython; Checks=@($checks.ToArray())
    }
}

function Invoke-SetupPythonCommand {
    param([string]$Python, [string[]]$Arguments)
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $Python @Arguments 2>&1)
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    if ($code -ne 0) { throw "Python setup command failed ($code): $($output -join ' ')" }
    $output | ForEach-Object { Write-Verbose ([string]$_) }
}

function Install-FindPythonPackages {
    param([string]$PythonPath)
    $python = Resolve-Python $PythonPath
    $probe = Invoke-FindPythonProbe $python
    if (-not $probe.supported -or -not $probe.fts5) {
        throw 'Python 3.10+ with SQLite FTS5 is required before installing extraction packages. Run check-only mode for guidance.'
    }
    if (@($probe.packages | Where-Object { -not $_.ready }).Count -eq 0) {
        return [pscustomobject]@{ Status='skipped'; PythonPath=$python }
    }
    $root = Split-Path -Parent $PSScriptRoot
    $venv = Join-Path $root '.venv'
    $venvPython = Join-Path $venv 'Scripts\python.exe'
    if (-not (Test-Path -LiteralPath $venvPython -PathType Leaf)) {
        if (Test-Path -LiteralPath $venv) { throw 'An incomplete .venv already exists. Inspect it before retrying; setup will not overwrite it.' }
        Invoke-SetupPythonCommand $python @('-m', 'venv', $venv)
    }
    $venvProbe = Invoke-FindPythonProbe $venvPython
    if (-not $venvProbe.supported -or -not $venvProbe.fts5) { throw 'The existing .venv has an incompatible Python or SQLite. It was not overwritten.' }
    if (-not $venvProbe.is_venv -or [IO.Path]::GetFullPath($venvProbe.prefix).TrimEnd('\') -ne [IO.Path]::GetFullPath($venv).TrimEnd('\')) {
        throw 'The .venv interpreter does not belong to this skill-local virtual environment. No packages were installed.'
    }
    if (@($venvProbe.packages | Where-Object { -not $_.ready }).Count -eq 0) {
        return [pscustomobject]@{ Status='skipped'; PythonPath=$venvPython }
    }
    Invoke-SetupPythonCommand $venvPython @('-m', 'pip', 'install', '--disable-pip-version-check', '-r', (Join-Path $root 'requirements.txt'))
    $verified = Invoke-FindPythonProbe $venvPython
    if (@($verified.packages | Where-Object { -not $_.ready }).Count -gt 0) { throw 'Package installation finished but dependency verification failed; rerun check-only mode.' }
    return [pscustomobject]@{ Status='installed'; PythonPath=$venvPython }
}
