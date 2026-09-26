[CmdletBinding()]
param(
    [ValidateSet('All', 'Metadata', 'Content')]
    [string]$Scope = 'All',
    [string]$PythonPath,
    [string]$Endpoint,
    [switch]$InstallPythonPackages,
    [switch]$Json,
    [switch]$Strict
)

$ErrorActionPreference = 'Stop'
$skillRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'common.ps1')
. (Join-Path $PSScriptRoot 'setup-support.ps1')

if ($InstallPythonPackages -and $Scope -eq 'Metadata') {
    throw '-InstallPythonPackages requires -Scope Content or All.'
}
$installation = $null
if ($InstallPythonPackages) {
    $installation = Install-FindPythonPackages -PythonPath $PythonPath
    # A pre-existing explicit path/environment variable can override .venv during normal use.
    # Probe the environment actually prepared; the report gives its path for subsequent calls.
    $PythonPath = $installation.PythonPath
}
$report = Get-FindEnvironment -Scope $Scope -PythonPath $PythonPath -Endpoint $Endpoint
$report | Add-Member -NotePropertyName Installation -NotePropertyValue $installation
if ($Json) {
    $report | ConvertTo-Json -Depth 8
} else {
    $report.Checks | Format-Table Name, Status, Detail -Wrap -AutoSize
    $actions = @($report.Checks | Where-Object { $_.Action } | ForEach-Object { $_.Action } | Select-Object -Unique)
    if ($actions.Count) {
        Write-Output 'Next steps:'
        $actions | ForEach-Object { Write-Output ("- " + $_) }
    }
    Write-Output ("Metadata ready: {0}; existing-index runtime ready: {1}; extraction ready: {2}" -f
        $report.MetadataReady, $report.ContentRuntimeReady, $report.ExtractionReady)
    if ($installation) { Write-Output ("Python packages: {0}; Python: {1}" -f $installation.Status, $installation.PythonPath) }
}
if ($Strict -and -not $report.Ready) { exit 1 }
