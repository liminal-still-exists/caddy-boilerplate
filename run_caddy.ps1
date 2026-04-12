$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

$envLoader = Join-Path $scriptDir "env_loader.ps1"
if (Test-Path -LiteralPath $envLoader) {
    . $envLoader
    if (Get-Command Import-ProjectEnv -ErrorAction SilentlyContinue) {
        Import-ProjectEnv
    }
}

# LocalSystem 서비스로 실행돼도 기존 사용자 Caddy 저장소를 그대로 사용하게 맞춥니다.
$caddyHome = if ($env:MCP_CADDY_HOME) { $env:MCP_CADDY_HOME } else { $env:USERPROFILE }
$caddyXdgHome = if ($env:MCP_CADDY_XDG_HOME) { $env:MCP_CADDY_XDG_HOME } else { $env:APPDATA }

$env:HOME = $caddyHome
$env:USERPROFILE = $caddyHome
$env:XDG_DATA_HOME = $caddyXdgHome
$env:XDG_CONFIG_HOME = $caddyXdgHome

& "$scriptDir\bin\caddy.exe" run --config "$scriptDir\Caddyfile" --adapter caddyfile
