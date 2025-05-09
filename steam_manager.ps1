<#
.SYNOPSIS
Steam Process Manager - Automation script for Steam suspension

.NOTES
Automatically detects Steam installation path from registry
#>

### CONFIGURATION ################################################################
$ProcessName = "steamwebhelper"
$RequiredProcessesStage1 = 3
$RequiredProcessesStage2 = 4
$TimeoutStage1 = 360
$TimeoutStage2 = 360
$CheckIntervalMs = 500

### REGISTRY CONFIG #############################################################
$RegistryPaths = @(
    "HKCU:\Software\Valve\Steam",
    "HKLM:\SOFTWARE\Wow6432Node\Valve\Steam",
    "HKLM:\SOFTWARE\Valve\Steam"
)

### FUNCTIONS ####################################################################
function Get-SteamPath {
    try {
        foreach ($regPath in $RegistryPaths) {
            if (Test-Path $regPath) {
                $steamDir = (Get-ItemProperty -Path $regPath -Name "SteamPath" -ErrorAction Stop).SteamPath
                $steamExe = Join-Path $steamDir "steam.exe"
                
                if (Test-Path $steamExe) {
                    return $steamExe
                }
            }
        }
        
        # Fallback to common paths if registry failed
        $commonPaths = @(
            "${env:ProgramFiles(x86)}\Steam\steam.exe",
            "${env:ProgramFiles}\Steam\steam.exe",
            "${env:SystemDrive}\Steam\steam.exe",
            "${env:LOCALAPPDATA}\Programs\Steam\steam.exe"
        )
        
        return $commonPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    }
    catch {
        Write-Host "[WARN] Registry access error: $_"
        return $null
    }
}

### RUNTIME ######################################################################
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "[ERROR] Requires PowerShell 5.0 or newer"
    exit 1
}

try {
    # Automatic Steam detection
    $steamPath = Get-SteamPath
    if (-not $steamPath) {
        throw "Steam not found in registry or default locations"
    }

    Write-Host "[INFO] Found Steam at: $steamPath"
    Write-Host "[1/5] Starting Steam..."
    
    # Запуск Steam
    $steamProcess = Start-Process -FilePath $steamPath -PassThru
    if (-not $steamProcess) {
        throw "Failed to start Steam process"
    }

    # Ожидание процессов первой стадии
    Write-Host "[2/5] Waiting for $RequiredProcessesStage1 $ProcessName processes..."
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ((Get-Process -Name $ProcessName -ErrorAction SilentlyContinue).Count -lt $RequiredProcessesStage1) {
        if ($stopwatch.Elapsed.TotalSeconds -ge $TimeoutStage1) {
            throw "Timeout waiting for $RequiredProcessesStage1 processes (${TimeoutStage1}s)"
        }
        Start-Sleep -Milliseconds $CheckIntervalMs
    }

    # Приостановка Steam
    Write-Host "[3/5] Suspending Steam..."
    $code = @'
    using System;
    using System.Runtime.InteropServices;
    public class PUtil {
        [DllImport("ntdll.dll")] 
        public static extern int NtSuspendProcess(IntPtr hProcess);
        [DllImport("ntdll.dll")] 
        public static extern int NtResumeProcess(IntPtr hProcess);
    }
'@
    Add-Type -TypeDefinition $code -ErrorAction Stop
    [PUtil]::NtSuspendProcess($steamProcess.Handle) | Out-Null

    # Ожидание процессов второй стадии
    Write-Host "[4/5] Waiting for $RequiredProcessesStage2 $ProcessName..."
    $stopwatch.Restart()
    while ((Get-Process -Name $ProcessName -ErrorAction SilentlyContinue).Count -lt $RequiredProcessesStage2) {
        if ($stopwatch.Elapsed.TotalSeconds -ge $TimeoutStage2) {
            [PUtil]::NtResumeProcess($steamProcess.Handle) | Out-Null
            throw "Timeout waiting for $RequiredProcessesStage2 processes (${TimeoutStage2}s)"
        }
        Start-Sleep -Milliseconds $CheckIntervalMs
    }

    # Возобновление работы Steam
    Write-Host "[5/5] Resuming Steam..."
    [PUtil]::NtResumeProcess($steamProcess.Handle) | Out-Null
    Write-Host "[SUCCESS] Operation completed!"
    exit 0
}
catch {
    Write-Host "[FATAL] $($_.Exception.Message)"
    exit 1
}