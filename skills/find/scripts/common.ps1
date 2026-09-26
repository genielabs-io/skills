# Shared runtime and scope resolution; loading this file has no side effects.
function Resolve-HttpEndpoint {
    param([string]$ExplicitEndpoint)
    $value = $ExplicitEndpoint
    if (-not $value) { $value = $env:EVERYTHING_HTTP_URL }
    if (-not $value) {
        $config = Join-Path (Split-Path -Parent $PSScriptRoot) 'config\http-url.txt'
        if (Test-Path -LiteralPath $config) {
            $value = Get-Content -LiteralPath $config | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith('#') } | Select-Object -First 1
        }
    }
    if (-not $value) { $value = 'http://127.0.0.1:8080/' }
    $uri = [Uri]$value.Trim().Trim('"')
    if (-not $uri.IsAbsoluteUri -or $uri.Scheme -notin @('http', 'https') -or -not $uri.IsLoopback -or $uri.UserInfo -or $uri.Query -or $uri.Fragment) {
        throw 'Use a loopback HTTP(S) endpoint without credentials, query, or fragment.'
    }
    return $uri.AbsoluteUri.TrimEnd('/') + '/'
}

function Assert-EverythingResponse {
    param($Response, [switch]$RequirePaths)
    $count = 0L
    if ($null -eq $Response -or $null -eq $Response.PSObject.Properties['totalResults'] -or
        $Response.results -isnot [array] -or -not [long]::TryParse([string]$Response.totalResults, [ref]$count) -or
        $count -lt 0 -or $Response.results.Count -gt $count) {
        throw 'Endpoint did not return the expected Everything JSON schema.'
    }
    if ($RequirePaths) {
        foreach ($item in $Response.results) {
            if ($item.name -isnot [string] -or -not $item.name -or $item.name -in @('.', '..') -or $item.name -match '[/\\]' -or
                $item.path -isnot [string] -or -not [IO.Path]::IsPathRooted($item.path)) {
                throw 'Everything returned an invalid file path.'
            }
        }
    }
}

function Resolve-Python {
    param([string]$Explicit)
    foreach ($requested in @($Explicit, $env:CODEX_PYTHON_PATH)) {
        if ($requested) {
            if (-not (Test-Path -LiteralPath $requested -PathType Leaf)) {
                throw "Configured Python does not exist: $requested"
            }
            return (Resolve-Path -LiteralPath $requested).Path
        }
    }
    $venvPython = Join-Path (Split-Path -Parent $PSScriptRoot) '.venv\Scripts\python.exe'
    if (Test-Path -LiteralPath $venvPython -PathType Leaf) { return $venvPython }
    $command = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($command -and $command.Source -notlike '*\WindowsApps\*') { return $command.Source }
    # Standard Windows installers can register Python without adding it to PATH.
    $registered = @()
    foreach ($registryRoot in @('HKCU:\Software\Python\PythonCore', 'HKLM:\Software\Python\PythonCore', 'HKLM:\Software\WOW6432Node\Python\PythonCore')) {
        foreach ($key in @(Get-ChildItem -Path $registryRoot -ErrorAction SilentlyContinue)) {
            $version = [version]'0.0'
            if (-not [version]::TryParse(($key.PSChildName -replace '-\d+$', ''), [ref]$version)) { continue }
            $installKey = Get-Item -LiteralPath ($key.PSPath + '\InstallPath') -ErrorAction SilentlyContinue
            if (-not $installKey) { continue }
            $candidate = $installKey.GetValue('ExecutablePath')
            if (-not $candidate -and $installKey.GetValue('')) { $candidate = Join-Path $installKey.GetValue('') 'python.exe' }
            if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                $registered += [pscustomobject]@{ Version=$version; Path=$candidate }
            }
        }
    }
    if ($registered.Count) { return ($registered | Sort-Object Version -Descending | Select-Object -First 1).Path }
    throw 'Python 3.10+ was not found. Create find/.venv, set CODEX_PYTHON_PATH, or pass -PythonPath.'
}

function Get-SearchDrives {
    $configPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'config\search-config.json'
    $configured = @()
    if (Test-Path -LiteralPath $configPath) {
        $configured = @((Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json).drives)
    }
    if ($configured.Count -eq 0) {
        $systemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd(':', '\') } else { 'C' }
        $configured = @($systemDrive)
    }
    foreach ($drive in $configured) {
        if ($drive -notmatch '^[A-Za-z]$') { throw 'Configured drives must be single letters, e.g. ["C","D"].' }
        $drive.ToUpperInvariant()
    }
}
