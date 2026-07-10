[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Write-HookLog {
    param([string]$Message)

    $logPath = Join-Path $PSScriptRoot 'precompact-reflection.log'
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
}

try {
    if ($env:CODEX_PRECOMPACT_REFLECTION_ACTIVE -eq '1') {
        exit 0
    }

    $inputText = [Console]::In.ReadToEnd()
    if (-not $DryRun) {
        Write-HookLog "INVOKED pid=$PID cwd=$((Get-Location).Path) input_length=$($inputText.Length)"
    }
    if ([string]::IsNullOrWhiteSpace($inputText)) {
        throw 'Codex hook input was empty.'
    }

    $payload = $inputText | ConvertFrom-Json
    $payloadFields = @($payload.PSObject.Properties.Name) -join ','
    if (-not $DryRun) {
        Write-HookLog "PAYLOAD fields=$payloadFields"
    }
    $transcriptPath = [string]$payload.transcript_path
    if ([string]::IsNullOrWhiteSpace($transcriptPath) -or
        -not (Test-Path -LiteralPath $transcriptPath -PathType Leaf)) {
        throw "Transcript was not found: $transcriptPath"
    }

    $workingDirectory = [string]$payload.cwd
    if ([string]::IsNullOrWhiteSpace($workingDirectory) -or
        -not (Test-Path -LiteralPath $workingDirectory -PathType Container)) {
        $workingDirectory = (Get-Location).Path
    }

    $promptPath = Join-Path $PSScriptRoot 'prompt.md'
    if (-not (Test-Path -LiteralPath $promptPath -PathType Leaf)) {
        throw "Prompt was not found: $promptPath"
    }
    $prompt = Get-Content -LiteralPath $promptPath -Raw -Encoding UTF8

    $codexArgs = @(
        'exec'
        '--disable', 'hooks'
        '--sandbox', 'workspace-write'
        '--skip-git-repo-check'
        '--ephemeral'
        '--color', 'never'
        '--cd', $workingDirectory
        $prompt
    )

    if ($DryRun) {
        [pscustomobject]@{
            transcript_path = $transcriptPath
            cwd = $workingDirectory
            prompt_path = $promptPath
            prompt_length = $prompt.Length
            codex_arguments = $codexArgs[0..($codexArgs.Count - 2)]
        } | ConvertTo-Json -Depth 4
        exit 0
    }

    $env:CODEX_PRECOMPACT_REFLECTION_ACTIVE = '1'
    $resultLog = Join-Path $PSScriptRoot 'precompact-reflection-child.log'

    Get-Content -LiteralPath $transcriptPath -Raw -Encoding UTF8 |
        & codex @codexArgs *> $resultLog
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        throw "Child Codex exited with code $exitCode. See $resultLog"
    }

    Write-HookLog "Reflection completed for $transcriptPath"
    exit 0
}
catch {
    Write-HookLog "ERROR: $($_.Exception.Message)"
    [Console]::Error.WriteLine("PreCompact reflection hook: $($_.Exception.Message)")
    exit 1
}
