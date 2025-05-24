# Windows build script
# Supports unified building for both local and CI environments

param(
    [string]$BuildType = "Release",
    [string]$Arch = "x64",
    [int]$ParallelJobs = 2,
    [bool]$EnableCcache = $true,
    [string]$VcpkgCommit = "a34c873a9717a888f58dc05268dea15592c2f0ff",
    [int]$MaxRetries = 3,
    [int]$RetryDelay = 30
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

# Retry execution function
function Invoke-WithRetry {
    param(
        [scriptblock]$ScriptBlock,
        [string]$Description,
        [int]$MaxAttempts = $MaxRetries,
        [int]$DelaySeconds = $RetryDelay
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        Write-ColorOutput "🔄 Attempt $attempt/$MaxAttempts : $Description" "Blue"

        try {
            & $ScriptBlock
            Write-ColorOutput "✅ $Description succeeded" "Green"
            return
        }
        catch {
            Write-ColorOutput "❌ Attempt $attempt failed: $_" "Red"

            if ($attempt -lt $MaxAttempts) {
                Write-ColorOutput "⏳ Waiting $DelaySeconds seconds before retry..." "Yellow"
                Start-Sleep -Seconds $DelaySeconds
            }
        }
    }

    throw "❌ $Description failed after $MaxAttempts attempts"
}

# Set triplet and CMake architecture
function Set-PlatformConfig {
    switch ($Arch) {
        "x64" {
            $script:Triplet = "x64-windows"
            $script:CmakeArch = "-A x64"
        }
        "x86" {
            $script:Triplet = "x86-windows"
            $script:CmakeArch = "-A Win32"
        }
        default {
            throw "❌ Unsupported architecture: $Arch"
        }
    }

    Write-ColorOutput "📋 Platform configuration:" "Blue"
    Write-ColorOutput "   - Architecture: $Arch" "White"
    Write-ColorOutput "   - Triplet: $Triplet" "White"
    Write-ColorOutput "   - CMake architecture: $CmakeArch" "White"
}

# Setup environment variables
function Set-BuildEnvironment {
    Write-ColorOutput "🔧 Setting up build environment..." "Blue"

    # vcpkg environment variables
    $env:VCPKG_KEEP_ENV_VARS = "HTTP_PROXY;HTTPS_PROXY;http_proxy;https_proxy"
    $env:VCPKG_MAX_CONCURRENCY = $ParallelJobs

    Write-ColorOutput "✅ Environment variables setup completed" "Green"
}

# Install vcpkg dependencies
function Install-VcpkgDependencies {
    Write-ColorOutput "📦 Installing vcpkg dependencies..." "Blue"

    # Check if vcpkg.json exists (manifest mode)
    if (Test-Path "vcpkg.json") {
        Write-ColorOutput "📋 Using manifest mode (vcpkg.json found)" "Blue"
        Invoke-WithRetry -Description "Install dependencies from manifest" -ScriptBlock {
            vcpkg install --triplet=$Triplet
            if ($LASTEXITCODE -ne 0) {
                throw "vcpkg install failed with exit code: $LASTEXITCODE"
            }
        }
    } else {
        Write-ColorOutput "📋 Using classic mode (installing individual packages)" "Blue"
        Invoke-WithRetry -Description "Install liblzma dependency" -ScriptBlock {
            vcpkg install liblzma:$Triplet --triplet=$Triplet
            if ($LASTEXITCODE -ne 0) {
                throw "vcpkg install failed with exit code: $LASTEXITCODE"
            }
        }
    }

    # List installed packages
    Write-ColorOutput "📋 Installed vcpkg packages:" "Blue"
    vcpkg list
}

# Configure CMake
function Invoke-CMakeConfigure {
    Write-ColorOutput "⚙️ Configuring CMake..." "Blue"

    # Get vcpkg paths
    $vcpkgToolchain = "$env:GITHUB_WORKSPACE/vcpkg/scripts/buildsystems/vcpkg.cmake"
    if (-not $env:GITHUB_WORKSPACE) {
        $vcpkgToolchain = "./vcpkg/scripts/buildsystems/vcpkg.cmake"
    }

    $vcpkgIncludePath = "./vcpkg_installed/$Triplet/include"
    $vcpkgLibPath = "./vcpkg_installed/$Triplet/lib"

    # Build CMake arguments
    $cmakeArgs = @(
        "-B", "build"
        "-S", "."
    )

    if ($CmakeArch) {
        $cmakeArgs += $CmakeArch
    }

    $cmakeArgs += @(
        "-DCMAKE_BUILD_TYPE=$BuildType"
        "-DCMAKE_TOOLCHAIN_FILE=$vcpkgToolchain"
        "-DVCPKG_TARGET_TRIPLET=$Triplet"
        "-DXDELTA_ENABLE_LZMA=ON"
        "-DXDELTA_BUILD_TESTS=OFF"
        "-DCMAKE_INCLUDE_PATH=$vcpkgIncludePath"
        "-DCMAKE_LIBRARY_PATH=$vcpkgLibPath"
        "-DLIBLZMA_INCLUDE_DIR=$vcpkgIncludePath"
        "-DLIBLZMA_LIBRARY=$vcpkgLibPath/liblzma.lib"
        "-DCMAKE_VERBOSE_MAKEFILE=ON"
    )

    if ($EnableCcache) {
        $cmakeArgs += @(
            "-DCMAKE_C_COMPILER_LAUNCHER=ccache"
            "-DCMAKE_CXX_COMPILER_LAUNCHER=ccache"
        )
    }

    Invoke-WithRetry -Description "CMake configuration" -ScriptBlock {
        & cmake @cmakeArgs
        if ($LASTEXITCODE -ne 0) {
            throw "CMake configuration failed with exit code: $LASTEXITCODE"
        }
    }
}

# Build project
function Invoke-Build {
    Write-ColorOutput "🔨 Building project..." "Blue"

    Invoke-WithRetry -Description "Project build" -ScriptBlock {
        cmake --build build --config $BuildType --parallel $ParallelJobs
        if ($LASTEXITCODE -ne 0) {
            throw "Build failed with exit code: $LASTEXITCODE"
        }
    }
}

# Test executable
function Test-Executable {
    Write-ColorOutput "🧪 Testing executable..." "Blue"

    $exePath = "build\$BuildType\xdelta3.exe"
    if (Test-Path $exePath) {
        Write-ColorOutput "Testing executable: $exePath" "White"
        & $exePath --help
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Executable test passed" "Green"
        } else {
            Write-ColorOutput "⚠️ Executable test returned non-zero exit code: $LASTEXITCODE" "Yellow"
        }
    } else {
        throw "❌ Executable not found: $exePath"
    }
}

# Main function
function Main {
    Write-ColorOutput "🚀 Starting Windows build process" "Blue"
    Write-ColorOutput "=================================" "Blue"

    Write-ColorOutput "📋 Build parameters:" "Blue"
    Write-ColorOutput "   - Build type: $BuildType" "White"
    Write-ColorOutput "   - Architecture: $Arch" "White"
    Write-ColorOutput "   - Parallel jobs: $ParallelJobs" "White"
    Write-ColorOutput "   - Enable ccache: $EnableCcache" "White"
    Write-ColorOutput "   - Max retries: $MaxRetries" "White"
    Write-ColorOutput "" "White"

    try {
        Set-PlatformConfig
        Set-BuildEnvironment
        Install-VcpkgDependencies
        Invoke-CMakeConfigure
        Invoke-Build
        Test-Executable

        Write-ColorOutput "🎉 Windows build completed!" "Green"
    }
    catch {
        Write-ColorOutput "💥 Build failed: $_" "Red"
        exit 1
    }
}

# Execute main function
Main
