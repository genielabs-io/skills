[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Query,
    [string[]]$Extensions,
    [ValidatePattern('^(?i:[A-Z]|All)$')]
    [string[]]$Drives,
    [string]$Modified,
    [ValidateSet('Newest', 'Name', 'Size')]
    [string]$Sort = 'Newest',
    [ValidateRange(1, 500)]
    [int]$Limit = 30,
    [string]$Endpoint,
    [switch]$IncludeFolders,
    [switch]$RawJson
)

$ErrorActionPreference = 'Stop'
$skillRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'common.ps1')

function Convert-EverythingDate {
    param($Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $null }
    $number = 0L
    if ([Int64]::TryParse([string]$Value, [ref]$number)) {
        if ($number -gt 1000000000000) {
            return [DateTime]::FromFileTimeUtc($number).ToString('o')
        }
        return [DateTimeOffset]::FromUnixTimeSeconds($number).UtcDateTime.ToString('o')
    }
    $parsed = [DateTimeOffset]::MinValue
    if ([DateTimeOffset]::TryParse([string]$Value, [ref]$parsed)) {
        return $parsed.UtcDateTime.ToString('o')
    }
    return [string]$Value
}

function New-NormalizedResult {
    param(
        [string]$Name,
        [string]$Path,
        [string]$Extension,
        $Size,
        $DateModified,
        [string]$Type = 'file'
    )
    $fullPath = if ($Path -and $Name) { Join-Path $Path $Name } elseif ($Path) { $Path } else { $Name }
    $sizeNumber = $null
    if ($null -ne $Size -and -not [string]::IsNullOrWhiteSpace([string]$Size)) {
        $parsedSize = 0L
        if ([Int64]::TryParse([string]$Size, [ref]$parsedSize)) { $sizeNumber = $parsedSize }
    }
    if (-not $Extension -and $Name) { $Extension = [IO.Path]::GetExtension($Name).TrimStart('.') }
    [pscustomobject]@{
        Name = $Name
        FullPath = $fullPath
        Extension = $Extension
        SizeBytes = $sizeNumber
        DateModifiedUtc = Convert-EverythingDate $DateModified
        Type = $Type
    }
}

function Invoke-HttpSearch {
    param([string]$SearchText)
    $base = Resolve-HttpEndpoint -ExplicitEndpoint $Endpoint
    $sortName = switch ($Sort) { 'Newest' { 'date_modified' } 'Name' { 'name' } 'Size' { 'size' } }
    $ascending = if ($Sort -eq 'Name') { '1' } else { '0' }
    $encodedSearch = [Uri]::EscapeDataString($SearchText)
    $url = $base + '?search=' + $encodedSearch + '&json=1&path=1&path_column=1&size_column=1&date_modified_column=1&count=' + $Limit + '&sort=' + $sortName + '&ascending=' + $ascending
    $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 10 -MaximumRedirection 0
    Assert-EverythingResponse -Response $response -RequirePaths
    if ($RawJson) {
        $response | ConvertTo-Json -Depth 8
        return
    }
    $items = @($response.results | ForEach-Object {
        New-NormalizedResult -Name $_.name -Path $_.path -Size $_.size -DateModified $_.date_modified -Type $_.type
    })
    [pscustomobject]@{
        Transport = 'http'
        Endpoint = $base
        Query = $SearchText
        TotalResults = [Int64]$response.totalResults
        ReturnedResults = $items.Count
        Results = $items
    } | ConvertTo-Json -Depth 6
}

if (-not $Query -and -not $Extensions -and -not $Modified) {
    throw 'Provide -Query, -Extensions, or -Modified. Refusing an unbounded drive-wide result set.'
}

# Explicit drives override configured scope. All is metadata-search only.
if (-not $PSBoundParameters.ContainsKey('Drives')) { $Drives = @(Get-SearchDrives) }
if (-not $Drives -or ($Drives -contains 'All' -and $Drives.Count -gt 1)) {
    throw 'Specify drive letters, or All by itself.'
}
$terms = [System.Collections.Generic.List[string]]::new()
if ($Drives -notcontains 'All') {
    $selectedDrives = @($Drives | Sort-Object -Unique)
    if ($selectedDrives.Count -eq 1) {
        $terms.Add($selectedDrives[0].ToLowerInvariant() + ':')
    } elseif ($selectedDrives.Count -gt 1) {
        $driveExpression = ($selectedDrives | ForEach-Object { $_.ToLowerInvariant() + ':' }) -join '|'
        $terms.Add('<' + $driveExpression + '>')
    }
}
if (-not $IncludeFolders) { $terms.Add('file:') }
if ($Query) { $terms.Add($Query.Trim()) }
if ($Extensions) {
    $cleanExtensions = @($Extensions | ForEach-Object { $_.Trim().TrimStart('*').TrimStart('.') } | Where-Object { $_ })
    if ($cleanExtensions.Count -gt 0) { $terms.Add('ext:' + ($cleanExtensions -join ';')) }
}
if ($Modified) { $terms.Add('dm:' + $Modified.Trim()) }
$searchText = $terms -join ' '

try {
    Invoke-HttpSearch -SearchText $searchText
} catch {
    throw "Everything HTTP search failed. Check the loopback endpoint, HTTP server settings, and local network permission. $($_.Exception.Message)"
}
