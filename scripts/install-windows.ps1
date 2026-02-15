# Sidecar Windows Installer
# PowerShell script to install sidecar on Windows 11
# Supports both native Windows and WSL2 environments

param(
    [switch]$Force,
    [switch]$CreateShortcut,
    [string]$InstallPath = "$env:LOCALAPPDATA\Programs\sidecar"
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Write-Header($Message) {
    Write-ColorOutput Cyan "`n=== $Message ==="
}

function Write-Success($Message) {
    Write-ColorOutput Green "✓ $Message"
}

function Write-Warning($Message) {
    Write-ColorOutput Yellow "! $Message"
}

function Write-Error($Message) {
    Write-ColorOutput Red "✗ $Message"
}

Write-Header "Sidecar Windows Installer"

# Detect architecture
$arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "386" }
Write-Output "Detected: Windows $arch"

# Get latest release version
Write-Output "`nFetching latest release..."
try {
    $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/marcus/sidecar/releases/latest"
    $version = $latestRelease.tag_name
    Write-Success "Latest version: $version"
} catch {
    Write-Error "Failed to fetch latest release from GitHub"
    exit 1
}

# Check if already installed
$exePath = Join-Path $InstallPath "sidecar.exe"
$alreadyInstalled = Test-Path $exePath

if ($alreadyInstalled -and -not $Force) {
    Write-Output "`nSidecar is already installed at: $exePath"
    $currentVersion = & $exePath --version 2>$null
    Write-Output "Current version: $currentVersion"
    
    $response = Read-Host "Reinstall? (y/N)"
    if ($response -ne "y" -and $response -ne "Y") {
        Write-Output "Installation cancelled."
        exit 0
    }
}

# Download binary
$downloadUrl = "https://github.com/marcus/sidecar/releases/download/$version/sidecar_${version}_windows_${arch}.zip"
$tempZip = Join-Path $env:TEMP "sidecar-${version}.zip"
$tempExtract = Join-Path $env:TEMP "sidecar-extract"

Write-Output "`nDownloading $downloadUrl..."
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip
    Write-Success "Downloaded to $tempZip"
} catch {
    Write-Error "Download failed: $_"
    exit 1
}

# Extract archive
Write-Output "`nExtracting..."
try {
    if (Test-Path $tempExtract) {
        Remove-Item $tempExtract -Recurse -Force
    }
    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force
    Write-Success "Extracted"
} catch {
    Write-Error "Extraction failed: $_"
    exit 1
}

# Install binary
Write-Output "`nInstalling to $InstallPath..."
try {
    if (-not (Test-Path $InstallPath)) {
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    }
    
    $sourceBinary = Join-Path $tempExtract "sidecar.exe"
    if (-not (Test-Path $sourceBinary)) {
        Write-Error "Binary not found in archive"
        exit 1
    }
    
    Copy-Item $sourceBinary $exePath -Force
    Write-Success "Installed to $exePath"
} catch {
    Write-Error "Installation failed: $_"
    exit 1
}

# Add to PATH if not already present
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*$InstallPath*") {
    Write-Output "`nAdding to PATH..."
    [Environment]::SetEnvironmentVariable(
        "PATH",
        "$userPath;$InstallPath",
        "User"
    )
    Write-Success "Added to PATH (restart terminal to apply)"
    $env:PATH = "$env:PATH;$InstallPath"
} else {
    Write-Success "Already in PATH"
}

# Create desktop shortcut
if ($CreateShortcut) {
    Write-Output "`nCreating desktop shortcut..."
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $shortcutPath = Join-Path $env:USERPROFILE "Desktop\Sidecar.lnk"
        $shortcut = $WshShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $exePath
        $shortcut.WorkingDirectory = $env:USERPROFILE
        $shortcut.Description = "Sidecar - AI-assisted development workspace"
        $shortcut.Save()
        Write-Success "Desktop shortcut created"
    } catch {
        Write-Warning "Could not create desktop shortcut: $_"
    }
}

# Check for tmux (WSL2)
Write-Output "`nChecking dependencies..."
$wslInstalled = Get-Command wsl -ErrorAction SilentlyContinue
if ($wslInstalled) {
    Write-Success "WSL detected"
    try {
        $tmuxCheck = wsl -- which tmux 2>$null
        if ($tmuxCheck) {
            Write-Success "tmux found in WSL"
        } else {
            Write-Warning "tmux not found in WSL"
            Write-Output "  Install tmux in WSL for interactive workspace features:"
            Write-Output "  wsl -- sudo apt update && sudo apt install -y tmux"
        }
    } catch {
        Write-Warning "Could not check for tmux in WSL"
    }
} else {
    Write-Warning "WSL not detected"
    Write-Output "  Install WSL2 for interactive workspace features:"
    Write-Output "  wsl --install"
}

# Cleanup
Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

# Verify installation
Write-Header "Installation Complete"
try {
    $installedVersion = & $exePath --version 2>$null
    Write-Success "Sidecar $installedVersion installed successfully"
    Write-Output "`nInstalled to: $exePath"
    Write-Output "`nUsage:"
    Write-Output "  1. Open a terminal (PowerShell or Command Prompt)"
    Write-Output "  2. Navigate to your project directory"
    Write-Output "  3. Run: sidecar"
    Write-Output "`nFor interactive workspace features, ensure WSL2 and tmux are installed."
} catch {
    Write-Error "Installation verification failed"
    exit 1
}
