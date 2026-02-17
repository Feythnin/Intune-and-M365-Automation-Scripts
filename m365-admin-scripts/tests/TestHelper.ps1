function Invoke-ScriptUnderTest {
    <#
    .SYNOPSIS
        Invokes a script with #Requires lines stripped so tests can run without modules installed.

    .PARAMETER ScriptPath
        Path to the script to invoke.

    .PARAMETER Parameters
        Hashtable of parameters to splat to the script.

    .DESCRIPTION
        Reads the script source, removes #Requires -Modules lines (so tests run
        without Graph/Exchange modules installed), writes to a temp file, invokes it
        with splatted parameters, and cleans up the temp file.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,

        [hashtable]$Parameters = @{}
    )

    $scriptContent = Get-Content -Path $ScriptPath -Raw
    $cleaned = $scriptContent -replace '(?m)^#Requires\s+-Modules.*$', '# [Removed by test harness] Requires -Modules'
    # Replace exit calls with return so the script doesn't terminate the test session
    $cleaned = $cleaned -replace '(?m)^\s*exit\s+\d+', '    return'
    # Suppress Format-Table output so it doesn't pollute the return pipeline
    $cleaned = $cleaned -replace '\|\s*Format-Table\b[^\n]*', '| Out-Null'

    $tempFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "Test_$([System.IO.Path]::GetFileName($ScriptPath))")

    try {
        Set-Content -Path $tempFile -Value $cleaned -Encoding UTF8
        & $tempFile @Parameters
    } finally {
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force
        }
    }
}
