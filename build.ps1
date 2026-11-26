<#
.SYNOPSIS
    Validates the APM package and the PowerShell in this repository.
.DESCRIPTION
    Runs PSScriptAnalyzer over every PowerShell file, then the Pester tests that check the structure of each instruction, agent, and skill. Exits nonzero when either fails.
.EXAMPLE
    ./build.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest

$analysis = Invoke-ScriptAnalyzer -Path $PSScriptRoot -Recurse -Settings (Join-Path -Path $PSScriptRoot -ChildPath 'PSScriptAnalyzerSettings.psd1')
if ($analysis) {
    $analysis | Format-Table -AutoSize | Out-String | Write-Warning
    Write-Error -Message 'PSScriptAnalyzer reported problems.' -ErrorAction Continue
    exit 1
}

$configuration = New-PesterConfiguration
$configuration.Run.Path = Join-Path -Path $PSScriptRoot -ChildPath 'test'
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'Detailed'
$result = Invoke-Pester -Configuration $configuration
if ($result.FailedCount -gt 0) {
    exit 1
}
