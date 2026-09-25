# ============================================================
# ALIT Consulting - BGInfo Installer
# ============================================================

$ErrorActionPreference = "Stop"

$InstallPath = "C:\ProgramData\ALIT\BGInfo"
$BGInfoZip   = "$env:TEMP\BGInfo.zip"
$BGInfoURL   = "https://download.sysinternals.com/files/BGInfo.zip"

$ConfigURL   = "https://raw.githubusercontent.com/Alitconsulting/ALITC_repo/main/ALITC.bgi"
$ConfigFile  = "$InstallPath\ALITC.bgi"

Write-Host "======================================"
Write-Host " ALIT Consulting BGInfo Installation"
Write-Host "======================================"

# Create folder
New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null

# Download BGInfo directly from Microsoft
Write-Host "[1/4] Downloading Microsoft BGInfo..."

Invoke-WebRequest `
    -Uri $BGInfoURL `
    -OutFile $BGInfoZip `
    -UseBasicParsing

# Extract
Write-Host "[2/4] Installing BGInfo..."

Expand-Archive `
    -Path $BGInfoZip `
    -DestinationPath $InstallPath `
    -Force

Remove-Item $BGInfoZip -Force -ErrorAction SilentlyContinue

# Download our current ALIT configuration
Write-Host "[3/4] Downloading ALIT configuration..."

Invoke-WebRequest `
    -Uri $ConfigURL `
    -OutFile $ConfigFile `
    -UseBasicParsing

# Create launcher
Write-Host "[4/4] Configuring automatic startup..."

$Launcher = @'
@echo off
"C:\ProgramData\ALIT\BGInfo\Bginfo64.exe" "C:\ProgramData\ALIT\BGInfo\ALITC.bgi" /timer:0 /silent /accepteula
'@

$Launcher | Set-Content `
    "$InstallPath\Run-BGInfo.cmd" `
    -Encoding ASCII

# Run BGInfo whenever a user logs in
$RunKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"

New-ItemProperty `
    -Path $RunKey `
    -Name "ALIT-BGInfo" `
    -PropertyType String `
    -Value "`"$InstallPath\Run-BGInfo.cmd`"" `
    -Force | Out-Null

# Verify installation

if (
    (Test-Path "$InstallPath\Bginfo64.exe") -and
    (Test-Path $ConfigFile)
) {

    Write-Host ""
    Write-Host "======================================"
    Write-Host " ALIT BGInfo installed successfully!"
    Write-Host "======================================"
    Write-Host ""
    Write-Host "BGInfo: $InstallPath\Bginfo64.exe"
    Write-Host "Config: $ConfigFile"
    Write-Host ""
    Write-Host "BGInfo will run at the next user login."

    exit 0
}

Write-Error "BGInfo installation failed."
exit 1
