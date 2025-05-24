# Windows local build script - consistent with CI environment
# This script calls the unified build script to ensure local and CI environments use the same build logic

param(
    [string]$BuildType = "Release",
    [string]$Arch = "x64",
    [int]$Jobs = 2,
    [switch]$NoCcache,
    [switch]$CheckDeps,
    [switch]$Help
)

# Error handling
$ErrorActionPreference = "Stop"

# Color output function
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")

    $colors = @{
        "Red" = [ConsoleColor]::Red
        "Green" = [ConsoleColor]::Green
        "Yellow" = [ConsoleColor]::Yellow
        "Blue" = [ConsoleColor]::Blue
        "White" = [ConsoleColor]::White
    }

    Write-Host $Message -ForegroundColor $colors[$Color]
}

# Show help information
function Show-Help {
    Write-ColorOutput "Windows Local Build Script" "Blue"
    Write-ColorOutput "==========================" "Blue"
    Write-Host ""
    Write-ColorOutput "This script uses the same build logic as the CI environment to build the project." "White"
    Write-Host ""
    Write-ColorOutput "Usage:" "Blue"
    Write-ColorOutput "  .\build.ps1 [options]" "White"
    Write-Host ""
    Write-ColorOutput "Options:" "Blue"
    Write-ColorOutput "  -BuildType TYPE    Build type (Debug|Release) [default: Release]" "White"
    Write-ColorOutput "  -Arch ARCH         Architecture (x64|x86) [default: x64]" "White"
    Write-ColorOutput "  -Jobs JOBS         Number of parallel jobs [default: 2]" "White"
    Write-ColorOutput "  -NoCcache          Disable ccache" "White"
    Write-ColorOutput "  -CheckDeps         Only check dependencies, don't build" "White"
    Write-ColorOutput "  -Help              Show this help message" "White"
    Write-Host ""
    Write-ColorOutput "Examples:" "Blue"
    Write-ColorOutput "  .\build.ps1                    # Build with default settings" "White"
    Write-ColorOutput "  .\build.ps1 -BuildType Debug   # Debug mode build" "White"
    Write-ColorOutput "  .\build.ps1 -Arch x86          # x86 architecture build" "White"
    Write-ColorOutput "  .\build.ps1 -NoCcache          # Build without ccache" "White"
    Write-ColorOutput "  .\build.ps1 -CheckDeps         # Only check dependencies" "White"
    Write-Host ""
    Write-ColorOutput "Notes:" "Blue"
    Write-ColorOutput "- vcpkg will be automatically set up on first run (if not present)" "White"
    Write-ColorOutput "- Installing ccache is recommended for faster builds" "White"
    Write-ColorOutput "- Visual Studio or Build Tools installation is required" "White"
}

# Check dependencies
function Test-Dependencies {
    Write-ColorOutput "🔍 Checking build dependencies..." "Blue"

    $missingDeps = @()

    # Check CMake
    try {
        $null = Get-Command cmake -ErrorAction Stop
    }
    catch {
        $missingDeps += "cmake"
    }

    # Check Git
    try {
        $null = Get-Command git -ErrorAction Stop
    }
    catch {
        $missingDeps += "git"
    }

    # Check Visual Studio or Build Tools
    $vsInstalled = $false
    $vsPaths = @(
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\*\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\2019\*\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\*\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\*\MSBuild\Current\Bin\MSBuild.exe"
    )

    foreach ($path in $vsPaths) {
        if (Test-Path $path) {
            $vsInstalled = $true
            break
        }
    }

    if (-not $vsInstalled) {
        $missingDeps += "Visual Studio or Build Tools"
    }

    # Check vcpkg directory
    if (-not (Test-Path "vcpkg")) {
        Write-ColorOutput "⚠️ vcpkg directory does not exist, manual vcpkg setup will be required" "Yellow"
    }

    # Check ccache (optional)
    try {
        $null = Get-Command ccache -ErrorAction Stop
    }
    catch {
        Write-ColorOutput "⚠️ ccache not installed, build may be slower" "Yellow"
    }

    if ($missingDeps.Count -gt 0) {
        Write-ColorOutput "❌ Missing the following dependencies:" "Red"
        foreach ($dep in $missingDeps) {
            Write-ColorOutput "   - $dep" "Red"
        }

        Write-ColorOutput "📋 Installation suggestions:" "Blue"
        Write-ColorOutput "CMake: https://cmake.org/download/" "White"
        Write-ColorOutput "Git: https://git-scm.com/download/win" "White"
        Write-ColorOutput "Visual Studio: https://visualstudio.microsoft.com/downloads/" "White"
        Write-ColorOutput "ccache: choco install ccache or https://ccache.dev/" "White"

        exit 1
    }

    Write-ColorOutput "✅ All required dependencies are installed" "Green"
}

# Setup vcpkg
function Set-Vcpkg {
    if (-not (Test-Path "vcpkg")) {
        Write-ColorOutput "📦 Setting up vcpkg..." "Blue"

        Write-ColorOutput "vcpkg directory does not exist. Please choose one of the following options:" "Yellow"
        Write-ColorOutput "1. Clone vcpkg repository (recommended)" "White"
        Write-ColorOutput "2. Skip vcpkg setup (use system libraries)" "White"
        Write-ColorOutput "3. Exit" "White"

        $choice = Read-Host "Please choose [1-3]"

        switch ($choice) {
            "1" {
                Write-ColorOutput "Cloning vcpkg repository..." "Blue"
                git clone https://github.com/Microsoft/vcpkg.git
                Set-Location vcpkg
                .\bootstrap-vcpkg.bat
                Set-Location ..
                Write-ColorOutput "✅ vcpkg setup completed" "Green"
            }
            "2" {
                Write-ColorOutput "⚠️ Skipping vcpkg setup, will use system libraries" "Yellow"
                $script:SkipVcpkg = $true
            }
            "3" {
                Write-ColorOutput "Exiting build" "Blue"
                exit 0
            }
            default {
                Write-ColorOutput "❌ Invalid choice" "Red"
                exit 1
            }
        }
    }
}

# Main function
function Main {
    Write-ColorOutput "🚀 Starting Windows local build" "Blue"
    Write-ColorOutput "===============================" "Blue"
    Write-Host ""

    # Show help
    if ($Help) {
        Show-Help
        return
    }

    # Only check dependencies
    if ($CheckDeps) {
        Test-Dependencies
        return
    }

    # Check dependencies
    Test-Dependencies

    # Setup vcpkg
    if (-not $SkipVcpkg) {
        Set-Vcpkg
    }

    # Build arguments
    $buildArgs = @{
        BuildType = $BuildType
        Arch = $Arch
        ParallelJobs = $Jobs
        EnableCcache = -not $NoCcache
    }

    Write-ColorOutput "📋 Calling Windows build script..." "Blue"
    Write-ColorOutput "Script path: .github\scripts\build-windows.ps1" "White"
    Write-ColorOutput "Arguments:" "White"
    foreach ($key in $buildArgs.Keys) {
        Write-ColorOutput "  -$key $($buildArgs[$key])" "White"
    }
    Write-Host ""

    # Call Windows build script
    try {
        & ".github\scripts\build-windows.ps1" @buildArgs
        Write-ColorOutput "🎉 Build completed!" "Green"
    }
    catch {
        Write-ColorOutput "💥 Build failed: $_" "Red"
        exit 1
    }
}

# Execute main function
Main
