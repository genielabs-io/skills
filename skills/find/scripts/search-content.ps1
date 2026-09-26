[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Query,
    [string[]]$Extensions,
    [string]$Path,
    [ValidateRange(1, 100)]
    [int]$Limit = 20,
    [string]$Database,
    [string]$PythonPath
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')

$arguments = @((Join-Path $PSScriptRoot 'content-index.py'), 'search', $Query, '--limit', [string]$Limit)
if ($Extensions) { $arguments += @('--extensions', ($Extensions -join ',')) }
if ($Path) { $arguments += @('--path', $Path) }
if ($Database) { $arguments += @('--db', $Database) }
& (Resolve-Python $PythonPath) @arguments
if ($LASTEXITCODE -ne 0) { throw "Content search failed with exit code $LASTEXITCODE." }
