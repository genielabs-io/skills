[CmdletBinding()]
param(
    [string[]]$Extensions = @('pdf','ppt','pptx','doc','docx','hwp','hwpx','xls','xlsx'),
    [string]$EverythingQuery,
    [ValidatePattern('^[A-Za-z]$')]
    [string[]]$Drives,
    [ValidateRange(1, 2048)]
    [int]$MaxFileSizeMB = 100,
    [string]$Endpoint,
    [string]$Database,
    [string]$PythonPath,
    [switch]$Prune
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')

$arguments = @(
    (Join-Path $PSScriptRoot 'content-index.py'), 'update',
    '--extensions', ($Extensions -join ','),
    '--max-mb', [string]$MaxFileSizeMB
)
if ($Drives) { $arguments += @('--drives', ($Drives -join ',')) }
if ($EverythingQuery) { $arguments += @('--query', $EverythingQuery) }
if ($Endpoint) { $arguments += @('--endpoint', $Endpoint) }
if ($Database) { $arguments += @('--db', $Database) }
if ($Prune) { $arguments += '--prune' }
& (Resolve-Python $PythonPath) @arguments
if ($LASTEXITCODE -ne 0) { throw "Content index update failed with exit code $LASTEXITCODE." }
