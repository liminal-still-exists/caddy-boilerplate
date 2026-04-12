$ErrorActionPreference = "Stop"

function Import-ProjectEnv {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $localEnvPath = Join-Path $scriptDir "env.local.ps1"

    if (Test-Path -LiteralPath $localEnvPath) {
        . $localEnvPath
    }

    if (-not $env:CADDY_PUBLIC_HOST) {
        throw "Set CADDY_PUBLIC_HOST in env.local.ps1 or as a Windows environment variable."
    }

    if (-not $env:OPEN_WEBUI_PUBLIC_HOST) {
        throw "Set OPEN_WEBUI_PUBLIC_HOST in env.local.ps1 or as a Windows environment variable."
    }

    if (-not $env:MYRAG_UPSTREAM) {
        $env:MYRAG_UPSTREAM = "127.0.0.1:18444"
    }

    if (-not $env:OPEN_WEBUI_UPSTREAM) {
        $env:OPEN_WEBUI_UPSTREAM = "127.0.0.1:18445"
    }
}
