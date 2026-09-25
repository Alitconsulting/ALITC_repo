# ============================================================
# ALIT Consulting - BGInfo Installer
# Windows 10/11 + Windows Server
# ============================================================

$ErrorActionPreference = "Stop"

$InstallPath = "C:\ProgramData\ALIT\BGInfo"
$BGInfoExe   = "$InstallPath\Bginfo64.exe"
$ConfigFile  = "$InstallPath\ALITC.bgi"
$RunnerFile  = "$InstallPath\Run-BGInfo.cmd"

$BGInfoZip   = "$env:TEMP\ALIT-BGInfo.zip"

$BGInfoURL = "https://download.sysinternals.com/files/BGInfo.zip"
$ConfigURL = "https://raw.githubusercontent.com/Alitconsulting/ALITC_repo/main/ALITC.bgi"

Write-Host ""
Write-Host "============================================"
Write-Host " ALIT Consulting - BGInfo Installation"
Write-Host "============================================"
Write-Host ""

try {

    # --------------------------------------------------------
    # Detect operating system
    # --------------------------------------------------------

    $OS = Get-CimInstance Win32_OperatingSystem

    Write-Host "Operating System : $($OS.Caption)"
    Write-Host "Computer Name    : $env:COMPUTERNAME"

    if ($OS.ProductType -eq 1) {
        $IsServer = $false
        Write-Host "System Type      : Workstation"
    }
    else {
        $IsServer = $true
        Write-Host "System Type      : Windows Server"
    }

    Write-Host ""

    # --------------------------------------------------------
    # TLS
    # --------------------------------------------------------

    [Net.ServicePointManager]::SecurityProtocol = `
        [Net.SecurityProtocolType]::Tls12

    # --------------------------------------------------------
    # Create ALIT folder
    # --------------------------------------------------------

    Write-Host "[1/6] Creating ALIT BGInfo directory..."

    New-Item `
        -Path $InstallPath `
        -ItemType Directory `
        -Force | Out-Null

    # --------------------------------------------------------
    # Download BGInfo from Microsoft
    # --------------------------------------------------------

    Write-Host "[2/6] Downloading Microsoft Sysinternals BGInfo..."

    Remove-Item `
        $BGInfoZip `
        -Force `
        -ErrorAction SilentlyContinue

    Invoke-WebRequest `
        -Uri $BGInfoURL `
        -OutFile $BGInfoZip `
        -UseBasicParsing

    if (!(Test-Path $BGInfoZip)) {
        throw "BGInfo download failed."
    }

    # --------------------------------------------------------
    # Extract BGInfo
    # --------------------------------------------------------

    Write-Host "[3/6] Installing BGInfo..."

    Expand-Archive `
        -Path $BGInfoZip `
        -DestinationPath $InstallPath `
        -Force

    Remove-Item `
        $BGInfoZip `
        -Force `
        -ErrorAction SilentlyContinue

    if (!(Test-Path $BGInfoExe)) {
        throw "Bginfo64.exe was not found after extraction."
    }

    # --------------------------------------------------------
    # Download ALIT configuration
    # --------------------------------------------------------

    Write-Host "[4/6] Downloading ALIT configuration..."

    Invoke-WebRequest `
        -Uri $ConfigURL `
        -OutFile $ConfigFile `
        -UseBasicParsing

    if (!(Test-Path $ConfigFile)) {
        throw "ALITC.bgi download failed."
    }

    # --------------------------------------------------------
    # Create launcher
    # --------------------------------------------------------

    Write-Host "[5/6] Creating BGInfo launcher..."

    $Runner = @'
@echo off
start "" /b "C:\ProgramData\ALIT\BGInfo\Bginfo64.exe" "C:\ProgramData\ALIT\BGInfo\ALITC.bgi" /timer:0 /silent /accepteula
exit /b 0
'@

    Set-Content `
        -Path $RunnerFile `
        -Value $Runner `
        -Encoding ASCII `
        -Force

    # --------------------------------------------------------
    # Configure startup
    # --------------------------------------------------------

    Write-Host "[6/6] Configuring BGInfo at user login..."

    $RunKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"

    New-ItemProperty `
        -Path $RunKey `
        -Name "ALIT-BGInfo" `
        -PropertyType String `
        -Value "`"$RunnerFile`"" `
        -Force | Out-Null

    # --------------------------------------------------------
    # IMPORTANT:
    # Do NOT directly execute BGInfo from Atera on Server.
    # Atera normally runs as SYSTEM in Session 0.
    # --------------------------------------------------------

    if ($IsServer) {

        Write-Host ""
        Write-Host "Windows Server detected."
        Write-Host "Skipping BGInfo desktop execution from SYSTEM session."
        Write-Host "BGInfo will automatically run in the user's"
        Write-Host "interactive session at the next login."

    }
    else {

        Write-Host ""
        Write-Host "Windows workstation detected."

        # Determine whether script itself is running interactively.

        $CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent().Name

        if ($CurrentIdentity -notmatch "SYSTEM") {

            Write-Host "Interactive user detected."
            Write-Host "Applying BGInfo now..."

            Start-Process `
                -FilePath $BGInfoExe `
                -ArgumentList "`"$ConfigFile`" /timer:0 /silent /accepteula" `
                -WindowStyle Hidden

        }
        else {

            Write-Host "Installer is running as SYSTEM."
            Write-Host "Skipping immediate desktop update."
            Write-Host "BGInfo will appear at the next user login."

        }
    }

    # --------------------------------------------------------
    # Final verification
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "Verifying installation..."

    $Errors = @()

    if (!(Test-Path $BGInfoExe)) {
        $Errors += "Bginfo64.exe"
    }

    if (!(Test-Path $ConfigFile)) {
        $Errors += "ALITC.bgi"
    }

    if (!(Test-Path $RunnerFile)) {
        $Errors += "Run-BGInfo.cmd"
    }

    $RunEntry = Get-ItemProperty `
        -Path $RunKey `
        -Name "ALIT-BGInfo" `
        -ErrorAction SilentlyContinue

    if (!$RunEntry) {
        $Errors += "Startup registry entry"
    }

    if ($Errors.Count -gt 0) {

        throw "Installation verification failed: $($Errors -join ', ')"

    }

    Write-Host ""
    Write-Host "============================================"
    Write-Host " ALIT BGInfo INSTALLATION SUCCESSFUL"
    Write-Host "============================================"
    Write-Host ""
    Write-Host "BGInfo:"
    Write-Host " $BGInfoExe"
    Write-Host ""
    Write-Host "Configuration:"
    Write-Host " $ConfigFile"
    Write-Host ""
    Write-Host "Launcher:"
    Write-Host " $RunnerFile"
    Write-Host ""
    Write-Host "Startup:"
    Write-Host " HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    Write-Host " ALIT-BGInfo"
    Write-Host ""
    Write-Host "BGInfo will refresh whenever a user logs in."
    Write-Host ""

    exit 0

}
catch {

    Write-Host ""
    Write-Host "============================================"
    Write-Host " ALIT BGInfo INSTALLATION FAILED"
    Write-Host "============================================"
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)"
    Write-Host ""

    exit 1
}
