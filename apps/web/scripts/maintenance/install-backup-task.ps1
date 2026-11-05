$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$nodeExe = (Get-Command node -CommandType Application | Select-Object -First 1).Source
$script = Join-Path $PSScriptRoot 'backup-vps-scheduled.cjs'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$sourceKey = Join-Path $env:LOCALAPPDATA 'ASTHA-RAVEN/deployment/id_ed25519'
$keyDirectory = Join-Path $env:USERPROFILE '.astha-raven-deployment'
$targetKey = Join-Path $keyDirectory 'id_ed25519'
if (!(Test-Path -LiteralPath $sourceKey -PathType Leaf)) { throw 'DEPLOYMENT_KEY_REQUIRED' }
New-Item -ItemType Directory -Path $keyDirectory -Force | Out-Null
$acl = [IO.Directory]::GetAccessControl($keyDirectory, [Security.AccessControl.AccessControlSections]::Access)
$acl.SetAccessRuleProtection($true, $false)
foreach ($existing in @($acl.Access)) { $acl.RemoveAccessRuleSpecific($existing) }
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
$rule = New-Object Security.AccessControl.FileSystemAccessRule($sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
$acl.AddAccessRule($rule)
[IO.Directory]::SetAccessControl($keyDirectory, $acl)
if (Test-Path -LiteralPath $targetKey) {
    if ((Get-FileHash -LiteralPath $sourceKey).Hash -ne (Get-FileHash -LiteralPath $targetKey).Hash) { throw 'DEPLOYMENT_KEY_CONFLICT' }
} else {
    # Copy locally without reading/emitting key bytes; outside MSIX AppData virtualization.
    Copy-Item -LiteralPath $sourceKey -Destination $targetKey
}
$action = New-ScheduledTaskAction -Execute $nodeExe -Argument ('"' + $script + '"') -WorkingDirectory $projectRoot
$triggers = @((New-ScheduledTaskTrigger -Daily -At '04:00'), (New-ScheduledTaskTrigger -AtLogOn -User $identity))
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 15) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
# Interactive identity preserves access to SSH and DPAPI without storing a password.
$principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
$task = New-ScheduledTask -Action $action -Trigger $triggers -Settings $settings -Principal $principal -Description 'ASTHA: backup cifrado e verificado da VPS; diariamente e no logon, com intervalo minimo de 20h. Mantem pelo menos 30 copias agendadas e todos os backups manuais.'
Register-ScheduledTask -TaskName 'ASTHA-RAVEN-Production-Backup' -InputObject $task -Force | Select-Object TaskName, State
