<#
.SYNOPSIS
    Regenerates the shared AI agent instructions in Autofac repositories.
.DESCRIPTION
    For each repository, creates a worktree on a feature branch from the remote default branch, writes apm.yml with the instructions that repository uses from autofac/.github, makes sure apm_modules/ is ignored and the generated files are excluded from markdownlint and marked as generated, then runs APM to regenerate the instructions. Changes are committed on the feature branch. With -Push, the branch is pushed and a pull request is opened against the default branch.

    The local clones are never modified: all work happens in worktrees, so uncommitted changes in a clone are left alone. Running the script again is safe. A repository whose generated files are already current is reported as Unchanged and its worktree is removed.

    Requires git, apm, and pre-commit on the path, plus gh when -Push is used.
.PARAMETER Repository
    The repository folder names to update. Defaults to every Autofac repository that carries the instructions.
.PARAMETER WorkspacePath
    The folder holding a clone of each repository. Defaults to the parent of the clone this script is in.
.PARAMETER WorktreePath
    The folder in which to create one worktree per repository. Defaults to a folder under the temporary directory.
.PARAMETER BranchName
    The feature branch to commit to.
.PARAMETER Ref
    The branch, tag, or commit of autofac/.github to take the instructions from. Omit it to use the default branch. Set it to a feature branch to try out rule changes before they merge, and do not merge the result, because the ref is recorded in apm.yml.
.PARAMETER Push
    Pushes each branch that has new commits and opens a pull request for it if one is not already open.
.OUTPUTS
    One object per repository with Repository, Status, PullRequest, and Detail properties. Status is Unchanged, Committed, Pushed, Skipped, or Failed.
.EXAMPLE
    ./tools/Update-AiInstruction.ps1 -Repository Autofac -WhatIf

    Shows what would change in the core repository without touching anything.
.EXAMPLE
    ./tools/Update-AiInstruction.ps1 -WorkspacePath ~/dev/autofac -Push

    Regenerates every repository, then pushes the branches and opens a pull request for each one that changed.
#>
[CmdletBinding(SupportsShouldProcess)]
[OutputType([PSCustomObject])]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string[]]$Repository = @(
        '.github',
        'Autofac',
        'Autofac.Analyzers',
        'Autofac.AspNetCore',
        'Autofac.AspNetCore.Multitenant',
        'Autofac.Configuration',
        'Autofac.Diagnostics.DotGraph',
        'Autofac.Extensions.DependencyInjection',
        'Autofac.Extensions.Hosting',
        'Autofac.Extras.AggregateService',
        'Autofac.Extras.AttributeMetadata',
        'Autofac.Extras.CommonServiceLocator',
        'Autofac.Extras.DynamicProxy',
        'Autofac.Extras.FakeItEasy',
        'Autofac.Extras.Moq',
        'Autofac.Mef',
        'Autofac.Multitenant',
        'Autofac.Multitenant.Wcf',
        'Autofac.Mvc',
        'Autofac.Mvc.Owin',
        'Autofac.Owin',
        'Autofac.Pooling',
        'Autofac.ServiceFabric',
        'Autofac.SignalR',
        'Autofac.Wcf',
        'Autofac.Web',
        'Autofac.WebApi',
        'Autofac.WebApi.Owin',
        'Documentation',
        'Examples'
    ),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspacePath = (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$WorktreePath = (Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'autofac-ai-instructions'),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$BranchName = 'feature/ai-instructions',

    [Parameter()]
    [string]$Ref,

    [Parameter()]
    [switch]$Push
)

Set-StrictMode -Version Latest

# Native commands do not expand ~ or relative PowerShell paths.
$WorkspacePath = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($WorkspacePath)
$WorktreePath = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($WorktreePath)

$sharedPrimitives = @(
    '.apm/instructions/commit.instructions.md',
    '.apm/instructions/csharp.instructions.md',
    '.apm/instructions/documentation.instructions.md',
    '.apm/instructions/github-actions.instructions.md',
    '.apm/instructions/issues.instructions.md',
    '.apm/instructions/library-design.instructions.md',
    '.apm/instructions/markdown.instructions.md',
    '.apm/instructions/powershell.instructions.md',
    '.apm/instructions/project-context.instructions.md',
    '.apm/instructions/pull-request.instructions.md',
    '.apm/agents/autofac-pull-request-reviewer.agent.md',
    '.apm/skills/review-autofac-pull-request'
)

# Repositories that leave out shared primitives which do not apply to them. The
# .github repository takes none, because it compiles its own .apm/ folder directly.
$excludedPrimitives = @{
    '.github'       = $sharedPrimitives
    'Documentation' = @(
        '.apm/instructions/csharp.instructions.md',
        '.apm/instructions/library-design.instructions.md',
        '.apm/instructions/powershell.instructions.md'
    )
    'Examples'      = @('.apm/instructions/library-design.instructions.md')
}

$markdownlintIgnore = @(
    'AGENTS.md',
    'CLAUDE.md',
    'GEMINI.md',
    'apm_modules/**',
    '.agents/**',
    '.claude/**',
    '.codex/**',
    '.github/agents/**',
    '.github/instructions/**',
    '.github/skills/**'
)

$gitAttributesMarker = '# Generated by APM from apm.yml. Collapsed in pull request diffs.'
$gitAttributes = @(
    $gitAttributesMarker,
    'AGENTS.md linguist-generated=true',
    'CLAUDE.md linguist-generated=true',
    'apm.lock.yaml linguist-generated=true',
    '.agents/** linguist-generated=true',
    '.claude/agents/** linguist-generated=true',
    '.claude/rules/** linguist-generated=true',
    '.claude/skills/** linguist-generated=true',
    '.codex/** linguist-generated=true',
    '.github/agents/** linguist-generated=true',
    '.github/instructions/** linguist-generated=true'
)

$addMessage = 'Give coding agents the Autofac contribution rules'
$refreshMessage = 'Refresh the shared AI agent instructions'
$pullRequestBody = @'
Generated with [APM](https://github.com/microsoft/apm) from the shared rules in [autofac/.github](https://github.com/autofac/.github/tree/main/.apm). Only `apm.yml`, `.gitignore`, `.gitattributes`, and `.markdownlintignore` are written by hand; everything else is generated. To change a rule, edit it in `autofac/.github` and rerun `tools/Update-AiInstruction.ps1` there.
'@

# Runs a native command in a directory and returns its output, throwing when it exits nonzero.
function Invoke-NativeCommand {
    param(
        [string]$WorkingDirectory,
        [string]$FilePath,
        [string[]]$ArgumentList
    )

    Push-Location -LiteralPath $WorkingDirectory
    try {
        $output = & $FilePath @ArgumentList 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "'$FilePath $($ArgumentList -join ' ')' exited with $LASTEXITCODE in ${WorkingDirectory}: $($output -join [Environment]::NewLine)"
        }

        return $output
    } finally {
        Pop-Location
    }
}

# Appends lines to a text file, keeping its existing line ending style and adding only lines not already present.
function Add-MissingLine {
    param(
        [string]$Path,
        [string[]]$Line,
        [string]$Marker
    )

    $existing = if (Test-Path -LiteralPath $Path) { Get-Content -LiteralPath $Path -Raw } else { '' }
    if ($null -eq $existing) {
        $existing = ''
    }

    $newline = if ($existing.Contains("`r`n")) { "`r`n" } else { "`n" }
    $present = $existing -split '\r?\n'
    if ($Marker -and $present -contains $Marker) {
        return
    }

    $missing = @($Line | Where-Object { $present -notcontains $_ })
    if ($missing.Count -eq 0) {
        return
    }

    $prefix = ''
    if ($existing.Length -gt 0) {
        $prefix = if ($existing.EndsWith("`n")) { $newline } else { $newline + $newline }
    }

    $text = $existing + $prefix + ($missing -join $newline) + $newline
    [System.IO.File]::WriteAllText($Path, $text, [System.Text.UTF8Encoding]::new($false))
}

# Writes apm.yml for a repository with the shared primitives it uses.
function Set-ApmManifest {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Path,
        [string]$Name,
        [string]$Ref
    )

    if (-not $PSCmdlet.ShouldProcess($Path, 'Write APM manifest')) {
        return
    }

    $excluded = if ($excludedPrimitives.ContainsKey($Name)) { $excludedPrimitives[$Name] } else { @() }
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("name: $($Name.TrimStart('.').ToLowerInvariant())")
    $lines.Add('version: 1.0.0')
    if ($Name -eq '.github') {
        $lines.Add('description: Shared AI agent instructions for the Autofac organization. Other repositories depend on files under .apm/; this one compiles its own .apm/ folder.')
    } else {
        $lines.Add("description: AI agent instructions for $Name, generated from autofac/.github by tools/Update-AiInstruction.ps1 there.")
    }

    $lines.Add('author: Autofac Project')
    $lines.Add('targets:')
    $lines.Add('  - claude')
    $lines.Add('  - codex')
    $lines.Add('  - copilot')
    $lines.Add('dependencies:')
    $included = @($sharedPrimitives | Where-Object { $excluded -notcontains $_ })
    if ($included.Count -eq 0) {
        $lines.Add('  apm: []')
    } else {
        $lines.Add('  apm:')
        foreach ($primitive in $included) {
            $lines.Add('    - git: github.com/autofac/.github')
            $lines.Add("      path: $primitive")
            if ($Ref) {
                $lines.Add("      ref: $Ref")
            }
        }
    }

    $lines.Add('  mcp: []')
    $lines.Add('includes: auto')
    $lines.Add('scripts: {}')
    [System.IO.File]::WriteAllText($Path, (($lines -join "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))
}

# Regenerates the instructions in one repository and returns its result.
function Update-Repository {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Name,
        [string]$WorkspacePath,
        [string]$WorktreePath,
        [string]$BranchName,
        [string]$Ref,
        [switch]$Push
    )

    $clonePath = Join-Path -Path $WorkspacePath -ChildPath $Name
    $result = [PSCustomObject]@{
        Repository  = $Name
        Status      = 'Skipped'
        PullRequest = $null
        Detail      = $null
    }

    if (-not (Test-Path -LiteralPath (Join-Path -Path $clonePath -ChildPath '.git'))) {
        $result.Detail = "No clone at $clonePath."
        return $result
    }

    if (-not $PSCmdlet.ShouldProcess($Name, "Regenerate AI instructions on $BranchName")) {
        $result.Detail = 'WhatIf.'
        return $result
    }

    $worktree = Join-Path -Path $WorktreePath -ChildPath $Name
    $createdWorktree = $false
    try {
        Invoke-NativeCommand -WorkingDirectory $clonePath -FilePath 'git' -ArgumentList @('fetch', '--quiet', 'origin') | Out-Null
        $defaultBranch = (Invoke-NativeCommand -WorkingDirectory $clonePath -FilePath 'git' -ArgumentList @('symbolic-ref', '--short', 'refs/remotes/origin/HEAD')) -replace '^origin/', ''

        if (-not (Test-Path -LiteralPath $worktree)) {
            & git -C $clonePath show-ref --verify --quiet "refs/heads/$BranchName"
            $branchExists = $LASTEXITCODE -eq 0
            $worktreeArguments = if ($branchExists) {
                @('worktree', 'add', '--quiet', $worktree, $BranchName)
            } else {
                @('worktree', 'add', '--quiet', '-b', $BranchName, $worktree, "origin/$defaultBranch")
            }

            Invoke-NativeCommand -WorkingDirectory $clonePath -FilePath 'git' -ArgumentList $worktreeArguments | Out-Null
            $createdWorktree = $true
        }

        $lockPath = Join-Path -Path $worktree -ChildPath 'apm.lock.yaml'
        $isRefresh = Test-Path -LiteralPath $lockPath

        Set-ApmManifest -Path (Join-Path -Path $worktree -ChildPath 'apm.yml') -Name $Name -Ref $Ref
        Add-MissingLine -Path (Join-Path -Path $worktree -ChildPath '.gitignore') -Line @('# APM dependencies', 'apm_modules/') -Marker 'apm_modules/'
        Add-MissingLine -Path (Join-Path -Path $worktree -ChildPath '.markdownlintignore') -Line $markdownlintIgnore
        Add-MissingLine -Path (Join-Path -Path $worktree -ChildPath '.gitattributes') -Line $gitAttributes -Marker $gitAttributesMarker

        if ($isRefresh) {
            # APM will not overwrite a generated copy of this repository's own .apm/ content without a
            # local receipt, which a fresh clone never has, and exits 0 when it skips one. The copies are
            # generated, so delete them and let APM write them again.
            $inLocalFiles = $false
            foreach ($line in Get-Content -LiteralPath $lockPath) {
                # The lock writes list items at column 0, so test for one before treating a line as a new key.
                if ($line -match '^- (.+)$') {
                    if (-not $inLocalFiles) {
                        continue
                    }

                    $generated = Join-Path -Path $worktree -ChildPath $Matches[1].Trim()
                    if (Test-Path -LiteralPath $generated -PathType Leaf) {
                        Remove-Item -LiteralPath $generated -Force
                    }
                } elseif ($line -match '^\S') {
                    $inLocalFiles = $line -eq 'local_deployed_files:'
                }
            }

            Invoke-NativeCommand -WorkingDirectory $worktree -FilePath 'apm' -ArgumentList @('update', '--yes') | Out-Null
        }

        # update moves the lock to the latest shared rules but does not redeploy local content; install does both.
        Invoke-NativeCommand -WorkingDirectory $worktree -FilePath 'apm' -ArgumentList @('install') | Out-Null

        # A single root AGENTS.md. The default places one in every source folder an instruction's pattern matches.
        Invoke-NativeCommand -WorkingDirectory $worktree -FilePath 'apm' -ArgumentList @('compile', '--clean', '--single-agents') | Out-Null

        Invoke-NativeCommand -WorkingDirectory $worktree -FilePath 'git' -ArgumentList @('add', '--all') | Out-Null
        $staged = @(Invoke-NativeCommand -WorkingDirectory $worktree -FilePath 'git' -ArgumentList @('diff', '--cached', '--name-only', '--diff-filter=d'))
        if ($staged.Count -gt 0 -and (Test-Path -LiteralPath (Join-Path -Path $worktree -ChildPath '.pre-commit-config.yaml'))) {
            # Hooks that fix files fail the first run, so stage their fixes and require a clean second run.
            Push-Location -LiteralPath $worktree
            try {
                & pre-commit run --files @staged 2>&1 | Out-Null
            } finally {
                Pop-Location
            }

            Invoke-NativeCommand -WorkingDirectory $worktree -FilePath 'git' -ArgumentList @('add', '--all') | Out-Null
            Invoke-NativeCommand -WorkingDirectory $worktree -FilePath 'pre-commit' -ArgumentList (@('run', '--files') + $staged) | Out-Null
        }

        $pending = Invoke-NativeCommand -WorkingDirectory $worktree -FilePath 'git' -ArgumentList @('status', '--porcelain')
        if ($pending) {
            $message = if ($isRefresh) { $refreshMessage } else { $addMessage }
            Invoke-NativeCommand -WorkingDirectory $worktree -FilePath 'git' -ArgumentList @('commit', '--quiet', '--message', $message) | Out-Null
        }

        $ahead = [int](Invoke-NativeCommand -WorkingDirectory $worktree -FilePath 'git' -ArgumentList @('rev-list', '--count', "origin/$defaultBranch..HEAD"))
        if ($ahead -eq 0) {
            $result.Status = 'Unchanged'
            if ($createdWorktree) {
                Invoke-NativeCommand -WorkingDirectory $clonePath -FilePath 'git' -ArgumentList @('worktree', 'remove', $worktree) | Out-Null
                Invoke-NativeCommand -WorkingDirectory $clonePath -FilePath 'git' -ArgumentList @('branch', '--delete', $BranchName) | Out-Null
            }

            return $result
        }

        $result.Status = 'Committed'
        $result.Detail = $worktree
        if ($Push.IsPresent -and $PSCmdlet.ShouldProcess($Name, "Push $BranchName and open a pull request against $defaultBranch")) {
            Invoke-NativeCommand -WorkingDirectory $worktree -FilePath 'git' -ArgumentList @('push', '--quiet', '--set-upstream', 'origin', $BranchName) | Out-Null
            $existing = Invoke-NativeCommand -WorkingDirectory $worktree -FilePath 'gh' -ArgumentList @('pr', 'list', '--repo', "autofac/$Name", '--head', $BranchName, '--json', 'url', '--jq', '.[0].url')
            if ($existing) {
                $result.PullRequest = "$existing"
            } else {
                $title = (Invoke-NativeCommand -WorkingDirectory $worktree -FilePath 'git' -ArgumentList @('log', '-1', '--format=%s'))
                $result.PullRequest = "$(Invoke-NativeCommand -WorkingDirectory $worktree -FilePath 'gh' -ArgumentList @('pr', 'create', '--repo', "autofac/$Name", '--base', $defaultBranch, '--head', $BranchName, '--title', "$title", '--body', $pullRequestBody))"
            }

            Invoke-NativeCommand -WorkingDirectory $clonePath -FilePath 'git' -ArgumentList @('worktree', 'remove', $worktree) | Out-Null
            $result.Status = 'Pushed'
            $result.Detail = $null
        }
    } catch {
        $result.Status = 'Failed'
        $result.Detail = $_.Exception.Message
    }

    return $result
}

foreach ($tool in @('git', 'apm', 'pre-commit') + $(if ($Push.IsPresent) { @('gh') } else { @() })) {
    if (-not (Get-Command -Name $tool -ErrorAction SilentlyContinue)) {
        throw "$tool is required and was not found on the path."
    }
}

New-Item -Path $WorktreePath -ItemType Directory -Force -WhatIf:$false | Out-Null
$results = foreach ($name in $Repository) {
    Update-Repository -Name $name -WorkspacePath $WorkspacePath -WorktreePath $WorktreePath -BranchName $BranchName -Ref $Ref -Push:$Push.IsPresent
}

$results
if ($results | Where-Object { $_.Status -eq 'Failed' }) {
    exit 1
}
