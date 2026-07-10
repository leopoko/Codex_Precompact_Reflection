$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
$TestDrive = Join-Path $env:TEMP ('codex-reflection-test-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $TestDrive | Out-Null
$fixture = Join-Path $TestDrive 'rollout.jsonl'

try {
    '{"type":"message","role":"user","content":"test"}' |
        Set-Content -LiteralPath $fixture -Encoding UTF8

    $payload = @{
        hook_event_name = 'PreCompact'
        trigger = 'auto'
        transcript_path = $fixture
        cwd = $root
        session_id = '00000000-0000-0000-0000-000000000000'
    } | ConvertTo-Json -Compress

    $script = Join-Path $root '.codex\hooks\precompact-reflection.ps1'
    $output = $payload | & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script -DryRun
    if ($LASTEXITCODE -ne 0) {
        throw "Dry run failed with exit code $LASTEXITCODE"
    }

    $result = $output | ConvertFrom-Json
    if ($result.transcript_path -ne $fixture) { throw 'Transcript path mismatch.' }
    if ($result.cwd -ne $root) { throw 'Working directory mismatch.' }
    if ($result.prompt_length -le 0) { throw 'Prompt was empty.' }

    Get-Content -LiteralPath (Join-Path $root '.codex\hooks.json') -Raw -Encoding UTF8 |
        ConvertFrom-Json | ForEach-Object {
            $hook = $_.hooks.PreCompact[0]
            if ($hook.matcher -ne '^(manual|auto)$') { throw 'Unexpected matcher.' }
            if ($hook.hooks[0].commandWindows -notmatch 'git rev-parse --show-toplevel') {
                throw 'Hook command does not resolve the Git root.'
            }
        }

    Write-Output 'PASS: hook configuration and dry run are valid.'
}
finally {
    if ($TestDrive -and (Test-Path -LiteralPath $TestDrive)) {
        Remove-Item -LiteralPath $TestDrive -Recurse -Force
    }
}
