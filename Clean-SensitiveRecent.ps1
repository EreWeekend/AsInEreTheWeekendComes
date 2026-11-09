param(
    [switch]$ShowReport
)

$ErrorActionPreference = 'Stop'

$logPath = Join-Path $PSScriptRoot 'RemoveSensitiveShortcuts.log'
$today = Get-Date -Format 'yyyy-MM-dd'

function Write-DailyStatus {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('SUCCESS', 'ERROR')]
        [string]$Status,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    # Avoid logging the same status repeatedly during five-minute runs.
    $marker = "$today [$Status]"

    if (-not (Test-Path -LiteralPath $logPath -PathType Leaf) -or
        -not (Select-String -LiteralPath $logPath -SimpleMatch $marker -Quiet -ErrorAction SilentlyContinue)) {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Add-Content -LiteralPath $logPath -Value "$timestamp [$Status] $Message" -Encoding UTF8
    }
}

$removedTargets = [System.Collections.Generic.List[string]]::new()
$errorCount = 0

try {
    $configPath = Join-Path $PSScriptRoot 'ExcludedPaths.txt'

    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        throw 'The exclusions configuration file is missing.'
    }

    $excludedPaths = @(
        foreach ($line in Get-Content -LiteralPath $configPath) {
            $path = $line.Trim()
            if (-not $path) { continue }

            try {
                if (Test-Path -LiteralPath $path -PathType Container) {
                    $fullPath = [IO.Path]::GetFullPath($path)
                    $root = [IO.Path]::GetPathRoot($fullPath)

                    if ($fullPath.Length -gt $root.Length) {
                        $fullPath = $fullPath.TrimEnd('\')
                    }

                    $prefix = if ($fullPath.EndsWith('\')) {
                        $fullPath
                    } else {
                        $fullPath + '\'
                    }

                    [PSCustomObject]@{
                        Path   = $fullPath
                        Prefix = $prefix
                    }
                }
            } catch {
                # Ignore invalid or inaccessible exclusion paths.
            }
        }
    )

    if ($excludedPaths.Count -eq 0) {
        throw 'No valid exclusion folders were found.'
    }

    $recentPath = [Environment]::GetFolderPath('Recent')

    if (-not (Test-Path -LiteralPath $recentPath -PathType Container)) {
        throw 'The current user Recent folder could not be accessed.'
    }

    $shell = New-Object -ComObject WScript.Shell

    foreach ($shortcut in Get-ChildItem -LiteralPath $recentPath -Filter '*.lnk' -File) {
        try {
            $target = $shell.CreateShortcut($shortcut.FullName).TargetPath
            if ([string]::IsNullOrWhiteSpace($target)) { continue }

            $target = [IO.Path]::GetFullPath($target)

            foreach ($excluded in $excludedPaths) {
                if (
                    $target.Equals($excluded.Path, [StringComparison]::OrdinalIgnoreCase) -or
                    $target.StartsWith($excluded.Prefix, [StringComparison]::OrdinalIgnoreCase)
                ) {
                    Remove-Item -LiteralPath $shortcut.FullName -Force -ErrorAction Stop
                    $removedTargets.Add($target)
                    break
                }
            }
        } catch {
            # Skip shortcuts that cannot be resolved or removed.
            $errorCount++
        }
    }

    if ($errorCount -gt 0) {
        Write-DailyStatus -Status 'ERROR' -Message 'Cleanup completed with one or more shortcuts skipped.'
    } else {
        Write-DailyStatus -Status 'SUCCESS' -Message 'Cleanup completed successfully.'
    }

    if ($ShowReport) {
        Write-Host ''
        Write-Host 'Cleanup completed.'

        if ($removedTargets.Count -eq 0) {
            Write-Host 'No matching recent shortcuts were removed.'
        } else {
            Write-Host 'Recent shortcuts removed for these target locations:'
            $removedTargets | Sort-Object -Unique | ForEach-Object {
                Write-Host "  $_"
            }
        }

        Write-Host ''
        Write-Host "Log file: $logPath"
    }

    exit 0
}
catch {
    Write-DailyStatus -Status 'ERROR' -Message 'Cleanup could not complete; see the installer output for details.'

    if ($ShowReport) {
        Write-Host ''
        Write-Host 'Cleanup did not complete.' -ForegroundColor Red
        Write-Host "Log file: $logPath"
        Write-Host ''
    }

    exit 1
}
