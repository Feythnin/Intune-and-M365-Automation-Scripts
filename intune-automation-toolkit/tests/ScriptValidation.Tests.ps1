BeforeDiscovery {
    $scriptsPath = Join-Path $PSScriptRoot '..' 'scripts'
    $scripts = Get-ChildItem -Path $scriptsPath -Filter '*.ps1' | ForEach-Object {
        @{
            Name     = $_.Name
            FullName = $_.FullName
        }
    }
}

Describe 'Script Validation - <Name>' -ForEach $scripts {

    BeforeAll {
        $scriptContent = Get-Content -Path $FullName -Raw
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($FullName, [ref]$tokens, [ref]$parseErrors)
    }

    It 'parses without syntax errors' {
        $parseErrors | Should -HaveCount 0
    }

    It 'has a SYNOPSIS in comment-based help' {
        $scriptContent | Should -Match '\.SYNOPSIS'
    }

    It 'has a DESCRIPTION in comment-based help' {
        $scriptContent | Should -Match '\.DESCRIPTION'
    }

    It 'has an EXAMPLE in comment-based help' {
        $scriptContent | Should -Match '\.EXAMPLE'
    }

    It 'has NOTES in comment-based help' {
        $scriptContent | Should -Match '\.NOTES'
    }

    It 'has [CmdletBinding()]' {
        $scriptContent | Should -Match '\[CmdletBinding'
    }

    It 'has a param block' {
        $scriptContent | Should -Match '(?s)param\s*\('
    }

    It 'has #Requires -Modules' {
        $scriptContent | Should -Match '#Requires\s+-Modules'
    }

    It 'checks for an active Graph connection (Get-MgContext)' {
        $scriptContent | Should -Match 'Get-MgContext'
    }

    It 'has try/catch error handling' {
        $scriptContent | Should -Match '(?s)try\s*\{.*catch'
    }

    It 'has exit 1 for fatal errors' {
        $scriptContent | Should -Match 'exit\s+1'
    }
}
