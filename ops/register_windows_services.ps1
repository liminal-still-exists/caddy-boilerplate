$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$caddyScript = Join-Path $projectRoot "run_caddy.ps1"
$envLoader = Join-Path $projectRoot "env_loader.ps1"
$logsDir = Join-Path $projectRoot "logs"
$serviceName = "CaddyGateway"
$displayName = "Caddy Gateway"

function Ensure-Admin {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "관리자 권한 PowerShell에서 실행해야 합니다."
    }
}

function Find-NssmPath {
    $localNssm = Join-Path $projectRoot "bin\nssm.exe"
    if (Test-Path -LiteralPath $localNssm) {
        return $localNssm
    }

    throw "bin\nssm.exe를 찾을 수 없습니다. 프로젝트 로컬 NSSM 바이너리를 확인해 주세요."
}

function Remove-ServiceIfExists {
    param([string]$Name)

    $existing = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($existing) {
        & $nssm stop $Name confirm | Out-Null
        & $nssm remove $Name confirm | Out-Null
    }
}

function Install-NssmService {
    param(
        [string]$Name,
        [string]$DisplayName,
        [string]$ScriptPath
    )

    & $nssm install $Name "powershell.exe" "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"" | Out-Null
    & $nssm set $Name DisplayName $DisplayName | Out-Null
    & $nssm set $Name AppDirectory $projectRoot | Out-Null
    & $nssm set $Name Start SERVICE_AUTO_START | Out-Null
    & $nssm set $Name AppStdout (Join-Path $logsDir "$Name.out.log") | Out-Null
    & $nssm set $Name AppStderr (Join-Path $logsDir "$Name.err.log") | Out-Null
    & $nssm set $Name AppRotateFiles 1 | Out-Null
    & $nssm set $Name AppRotateOnline 1 | Out-Null
    & $nssm set $Name AppRotateBytes 1048576 | Out-Null

    sc.exe config $Name start= delayed-auto | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "$Name 서비스의 시작 유형을 자동(지연된 시작)으로 설정하지 못했습니다."
    }
}

Ensure-Admin

New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
$nssm = Find-NssmPath

if (-not (Test-Path -LiteralPath $envLoader)) {
    throw "env_loader.ps1를 찾을 수 없습니다: $envLoader"
}

. $envLoader
if (-not (Get-Command Import-ProjectEnv -ErrorAction SilentlyContinue)) {
    throw "Import-ProjectEnv 함수를 찾을 수 없습니다: $envLoader"
}
Import-ProjectEnv

if (-not $env:CADDY_PUBLIC_HOST) {
    throw "Set the machine environment variable CADDY_PUBLIC_HOST before registering the service."
}

if (-not $env:OPEN_WEBUI_PUBLIC_HOST) {
    throw "Set the machine environment variable OPEN_WEBUI_PUBLIC_HOST before registering the service."
}

if (-not $env:MYRAG_UPSTREAM) {
    $env:MYRAG_UPSTREAM = "127.0.0.1:18444"
}

if (-not $env:OPEN_WEBUI_UPSTREAM) {
    $env:OPEN_WEBUI_UPSTREAM = "127.0.0.1:18445"
}

if (-not (Test-Path -LiteralPath $caddyScript)) {
    throw "run_caddy.ps1를 찾을 수 없습니다: $caddyScript"
}

Remove-ServiceIfExists -Name $serviceName

Install-NssmService -Name $serviceName -DisplayName $displayName -ScriptPath $caddyScript
& $nssm set $serviceName AppEnvironmentExtra "CADDY_PUBLIC_HOST=$env:CADDY_PUBLIC_HOST" "OPEN_WEBUI_PUBLIC_HOST=$env:OPEN_WEBUI_PUBLIC_HOST" "MYRAG_UPSTREAM=$env:MYRAG_UPSTREAM" "OPEN_WEBUI_UPSTREAM=$env:OPEN_WEBUI_UPSTREAM" | Out-Null

& $nssm start $serviceName | Out-Null

Get-Service $serviceName | Select-Object Name,Status,StartType
