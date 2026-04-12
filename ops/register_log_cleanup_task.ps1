$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$localTaskXmlPath = Join-Path $scriptDir "log_cleanup_task.local.xml"
$defaultTaskXmlPath = Join-Path $scriptDir "log_cleanup_task.xml"
$cleanupScript = Join-Path $scriptDir "cleanup_logs.ps1"
$generatedTaskXmlPath = Join-Path $scriptDir "log_cleanup_task.generated.xml"

function Ensure-Admin {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Run this script in an elevated PowerShell session."
    }
}

Ensure-Admin

$taskXmlPath = if (Test-Path -LiteralPath $localTaskXmlPath) {
    $localTaskXmlPath
} elseif (Test-Path -LiteralPath $defaultTaskXmlPath) {
    $defaultTaskXmlPath
} else {
    throw "Missing log cleanup task template XML."
}

$escapedCleanupScript = $cleanupScript.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;")
$taskXmlTemplate = Get-Content -LiteralPath $taskXmlPath -Raw
$taskXmlResolved = $taskXmlTemplate.Replace("__CLEANUP_SCRIPT_PATH__", $escapedCleanupScript)
$taskXmlResolved | Set-Content -LiteralPath $generatedTaskXmlPath -Encoding Unicode

[xml]$taskXml = Get-Content -LiteralPath $generatedTaskXmlPath -Raw
$namespaceUri = $taskXml.DocumentElement.NamespaceURI
$ns = New-Object System.Xml.XmlNamespaceManager($taskXml.NameTable)
$ns.AddNamespace("t", $namespaceUri)
$taskUri = $taskXml.SelectSingleNode("/t:Task/t:RegistrationInfo/t:URI", $ns).InnerText

cmd /c "schtasks /Query /TN $taskUri >nul 2>&1"
if ($LASTEXITCODE -eq 0) {
    schtasks /Delete /TN $taskUri /F | Out-Null
}
schtasks /Create /TN $taskUri /XML $generatedTaskXmlPath /RU SYSTEM /F | Out-Null

Write-Host "Registered log cleanup task: $taskUri"
