$ErrorActionPreference = 'Stop'

$taskName   = 'Clean Sensitive Recent Shortcuts'
$folderPath = '\Custom'
$scriptPath = Join-Path $PSScriptRoot 'Clean-SensitiveRecent.ps1'
$configPath = Join-Path $PSScriptRoot 'ExcludedPaths.txt'
$logPath    = Join-Path $PSScriptRoot 'RemoveSensitiveShortcuts.log'

function Write-InstallLog {
    param([string]$Message)

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -LiteralPath $logPath `
        -Value "$timestamp [INSTALL] $Message" `
        -Encoding UTF8
}

try {
    if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        throw 'Run this as a saved .ps1 file.'
    }

    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        throw 'The cleanup script is missing.'
    }

    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        throw 'The exclusions configuration file is missing.'
    }

    # Create the log during installation.
    if (-not (Test-Path -LiteralPath $logPath -PathType Leaf)) {
        New-Item -ItemType File -Path $logPath -Force | Out-Null
    }

    Write-InstallLog 'Task installation started.'

    $userId = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $powerShellPath = Join-Path $env:WINDIR `
        'System32\WindowsPowerShell\v1.0\powershell.exe'

    $xmlUser       = [System.Security.SecurityElement]::Escape($userId)
    $xmlPowerShell = [System.Security.SecurityElement]::Escape($powerShellPath)
    $xmlScript     = [System.Security.SecurityElement]::Escape($scriptPath)
    $xmlWorkingDir = [System.Security.SecurityElement]::Escape($PSScriptRoot)

    $xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Runs the recent-shortcut cleanup for the signed-in user.</Description>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
      <UserId>$xmlUser</UserId>
      <Repetition>
        <Interval>PT5M</Interval>
      </Repetition>
    </LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$xmlUser</UserId>
      <LogonType>S4U</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <StartWhenAvailable>true</StartWhenAvailable>
    <Enabled>true</Enabled>
    <ExecutionTimeLimit>PT2M</ExecutionTimeLimit>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>$xmlPowerShell</Command>
      <Arguments>-NoProfile -WindowStyle Hidden -File &quot;$xmlScript&quot;</Arguments>
      <WorkingDirectory>$xmlWorkingDir</WorkingDirectory>
    </Exec>
  </Actions>
</Task>
"@

    $scheduler = New-Object -ComObject Schedule.Service
    $scheduler.Connect()
    $root = $scheduler.GetFolder('\')

    try {
        $folder = $scheduler.GetFolder($folderPath)
    }
    catch {
        try {
            $folder = $root.CreateFolder('Custom')
        }
        catch {
            # It may have been created between lookup and creation.
            $folder = $scheduler.GetFolder($folderPath)
        }
    }

    $null = $folder.RegisterTask(
        $taskName, $xml, 6, $userId, $null, 2, $null
    )

    Write-InstallLog 'Scheduled task registered.'

    Write-Host ''
    Write-Host 'Running the cleanup once and preparing the report...'
    Write-Host ''

    # Run as a child PowerShell process so its exit command does not end
    # this installer PowerShell session. The report is shown in this console.
    & $powerShellPath -NoProfile -ExecutionPolicy Bypass `
        -File $scriptPath -ShowReport

    if ($LASTEXITCODE -ne 0) {
        throw 'The initial cleanup did not complete successfully.'
    }

    # Start the recurring task after the visible initial report run.
    Start-ScheduledTask -TaskPath '\Custom\' `
        -TaskName $taskName -ErrorAction Stop

    Write-InstallLog 'Initial cleanup completed; scheduled task started.'
    Write-Host ''
    Write-Host 'The task was created and started.'
    Write-Host "Log file: $logPath"
    Write-Host 'Type exit or close this window when you are done.'
}
catch {
    $message = $_.Exception.Message

    try {
        if (-not (Test-Path -LiteralPath $logPath -PathType Leaf)) {
            New-Item -ItemType File -Path $logPath -Force | Out-Null
        }
        Write-InstallLog "Installation or initial cleanup failed: $message"
    }
    catch {
        # Preserve the original error if logging itself fails.
    }

    Write-Host ''
    Write-Host 'TASK INSTALLATION FAILED:' -ForegroundColor Red
    Write-Host $message -ForegroundColor Red

    if (Test-Path -LiteralPath $logPath -PathType Leaf) {
        Write-Host "Log file: $logPath"
    }

    exit 1
}
