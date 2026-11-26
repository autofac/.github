Set-StrictMode -Version Latest

BeforeDiscovery {
    $apmRoot = Join-Path -Path $PSScriptRoot -ChildPath '../.apm'
    $script:instructions = Get-ChildItem -Path (Join-Path -Path $apmRoot -ChildPath 'instructions') -Filter '*.instructions.md' |
        ForEach-Object { @{ Name = $_.Name; Path = $_.FullName; Id = $_.Name -replace '\.instructions\.md$', '' } }
    $script:agents = Get-ChildItem -Path (Join-Path -Path $apmRoot -ChildPath 'agents') -Filter '*.agent.md' |
        ForEach-Object { @{ Name = $_.Name; Path = $_.FullName; Id = $_.Name -replace '\.agent\.md$', '' } }
    $script:skills = Get-ChildItem -Path (Join-Path -Path $apmRoot -ChildPath 'skills') -Directory |
        ForEach-Object { @{ Name = $_.Name; Path = (Join-Path -Path $_.FullName -ChildPath 'SKILL.md'); Id = $_.Name } }
}

BeforeAll {
    # Returns the YAML frontmatter keys of a primitive, or an empty table when the file has none.
    function Get-Frontmatter {
        param([string]$Path)

        $lines = Get-Content -LiteralPath $Path
        $result = @{}
        if ($lines.Count -eq 0 -or $lines[0] -ne '---') {
            return $result
        }

        for ($i = 1; $i -lt $lines.Count -and $lines[$i] -ne '---'; $i++) {
            if ($lines[$i] -match '^([A-Za-z-]+):\s*(.*)$') {
                $result[$Matches[1]] = $Matches[2].Trim().Trim('"')
            }
        }

        return $result
    }
}

Describe 'Instruction <Name>' -ForEach $script:instructions {
    BeforeAll {
        $script:frontmatter = Get-Frontmatter -Path $Path
    }

    It 'Names itself after its file' {
        $script:frontmatter['name'] | Should -Be $Id
    }

    It 'Has a description' {
        $script:frontmatter['description'] | Should -Not -BeNullOrEmpty
    }

    It 'Has an applyTo pattern' {
        $script:frontmatter['applyTo'] | Should -Not -BeNullOrEmpty
    }
}

Describe 'Agent <Name>' -ForEach $script:agents {
    BeforeAll {
        $script:frontmatter = Get-Frontmatter -Path $Path
    }

    It 'Names itself after its file' {
        $script:frontmatter['name'] | Should -Be $Id
    }

    It 'Has a description' {
        $script:frontmatter['description'] | Should -Not -BeNullOrEmpty
    }

    It 'Does not restrict tools' {
        # Claude Code refuses to start an agent whose tool names it does not recognize.
        $script:frontmatter.ContainsKey('tools') | Should -BeFalse
    }
}

Describe 'Skill <Name>' -ForEach $script:skills {
    BeforeAll {
        $script:frontmatter = Get-Frontmatter -Path $Path
        $script:content = Get-Content -LiteralPath $Path
    }

    It 'Names itself after its folder' {
        $script:frontmatter['name'] | Should -Be $Id
    }

    It 'Has a description' {
        $script:frontmatter['description'] | Should -Not -BeNullOrEmpty
    }

    It 'Has the <_> section' -ForEach @('## Intent', '## Workflow', '## Inputs and Outputs', '## Safety') {
        $script:content | Should -Contain $_
    }
}
