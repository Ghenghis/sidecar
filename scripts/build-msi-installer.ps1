# Build Windows MSI Installer for Sidecar
# Requires WiX Toolset: https://wixtoolset.org/

param(
    [string]$Version = "0.73.1",
    [string]$Architecture = "x64"
)

$ErrorActionPreference = "Stop"

Write-Host "Building Sidecar MSI Installer v$Version for $Architecture" -ForegroundColor Cyan

# Check if WiX is installed
$wixPath = "${env:ProgramFiles(x86)}\WiX Toolset v3.11\bin"
if (-not (Test-Path "$wixPath\candle.exe")) {
    Write-Error "WiX Toolset not found. Install from https://wixtoolset.org/"
    exit 1
}

# Add WiX to PATH temporarily
$env:PATH = "$wixPath;$env:PATH"

# Create WiX source file
$wxsContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
    <Product Id="*" Name="Sidecar" Language="1033" Version="$Version" 
             Manufacturer="Sidecar" UpgradeCode="F8E9D6C4-B3A2-4F1E-9D7C-8E5F6A3B2C1D">
        <Package InstallerVersion="200" Compressed="yes" InstallScope="perMachine" />
        
        <MajorUpgrade DowngradeErrorMessage="A newer version is already installed." />
        <MediaTemplate EmbedCab="yes" />

        <Feature Id="ProductFeature" Title="Sidecar" Level="1">
            <ComponentGroupRef Id="ProductComponents" />
        </Feature>

        <Directory Id="TARGETDIR" Name="SourceDir">
            <Directory Id="ProgramFiles64Folder">
                <Directory Id="INSTALLFOLDER" Name="Sidecar" />
            </Directory>
            <Directory Id="ProgramMenuFolder">
                <Directory Id="ApplicationProgramsFolder" Name="Sidecar"/>
            </Directory>
        </Directory>

        <DirectoryRef Id="INSTALLFOLDER">
            <Component Id="SidecarExecutable" Guid="A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D">
                <File Id="SidecarEXE" Source="bin\sidecar-windows-$Architecture.exe" 
                      KeyPath="yes" Checksum="yes" />
                <Environment Id="PATH" Name="PATH" Value="[INSTALLFOLDER]" 
                            Permanent="no" Part="last" Action="set" System="yes" />
            </Component>
            <Component Id="InstallScript" Guid="B2C3D4E5-F6A7-5B6C-9D0E-1F2A3B4C5D6E">
                <File Source="scripts\install-windows.ps1" />
            </Component>
        </DirectoryRef>

        <DirectoryRef Id="ApplicationProgramsFolder">
            <Component Id="ApplicationShortcut" Guid="C3D4E5F6-A7B8-6C7D-0E1F-2A3B4C5D6E7F">
                <Shortcut Id="ApplicationStartMenuShortcut" Name="Sidecar" 
                         Description="AI Coding Agent Dashboard" Target="[INSTALLFOLDER]sidecar-windows-$Architecture.exe"
                         WorkingDirectory="INSTALLFOLDER"/>
                <RemoveFolder Id="CleanUpShortCut" Directory="ApplicationProgramsFolder" On="uninstall"/>
                <RegistryValue Root="HKCU" Key="Software\Sidecar" Name="installed" Type="integer" Value="1" KeyPath="yes"/>
            </Component>
        </DirectoryRef>

        <ComponentGroup Id="ProductComponents" Directory="INSTALLFOLDER">
            <ComponentRef Id="SidecarExecutable" />
            <ComponentRef Id="InstallScript" />
        </ComponentGroup>
    </Product>
</Wix>
"@

Set-Content -Path "installer.wxs" -Value $wxsContent

# Compile WiX source
Write-Host "Compiling WiX source..." -ForegroundColor Yellow
& candle.exe installer.wxs -arch $Architecture

if ($LASTEXITCODE -ne 0) {
    Write-Error "WiX compilation failed"
    exit 1
}

# Link to create MSI
Write-Host "Creating MSI package..." -ForegroundColor Yellow
& light.exe installer.wixobj -out "dist\sidecar-$Version-$Architecture.msi"

if ($LASTEXITCODE -ne 0) {
    Write-Error "MSI creation failed"
    exit 1
}

# Clean up
Remove-Item installer.wxs, installer.wixobj -Force

Write-Host "Successfully created: dist\sidecar-$Version-$Architecture.msi" -ForegroundColor Green
