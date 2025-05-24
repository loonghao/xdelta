#!/bin/bash

# Unified build script - supports both local and CI environments
# Usage: ./build-common.sh [options]

set -e

# Default configuration
BUILD_TYPE="Release"
ARCH="x64"
PLATFORM=""
VCPKG_COMMIT="a34c873a9717a888f58dc05268dea15592c2f0ff"
ENABLE_CCACHE="true"
PARALLEL_JOBS="2"
CONFIG_FILE=".github/config/build-config.yml"

# Help information
show_help() {
    cat << EOF
Unified Build Script

Usage: $0 [options]

Options:
    -t, --build-type TYPE    Build type (Debug|Release) [default: Release]
    -a, --arch ARCH         Architecture (x64|x86) [default: x64]
    -p, --platform PLATFORM Platform (windows|linux) [auto-detect]
    -j, --jobs JOBS         Number of parallel jobs [default: 2]
    --no-ccache             Disable ccache
    --vcpkg-commit COMMIT   vcpkg commit hash
    -c, --config FILE       Configuration file path
    -h, --help              Show this help message

Examples:
    $0                      # Build with default settings
    $0 -t Debug -a x86      # Debug mode, x86 architecture
    $0 --no-ccache          # Build without ccache
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--build-type)
                BUILD_TYPE="$2"
                shift 2
                ;;
            -a|--arch)
                ARCH="$2"
                shift 2
                ;;
            -p|--platform)
                PLATFORM="$2"
                shift 2
                ;;
            -j|--jobs)
                PARALLEL_JOBS="$2"
                shift 2
                ;;
            --no-ccache)
                ENABLE_CCACHE="false"
                shift
                ;;
            --vcpkg-commit)
                VCPKG_COMMIT="$2"
                shift 2
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Detect platform
detect_platform() {
    if [[ -z "$PLATFORM" ]]; then
        case "$(uname -s)" in
            Linux*)     PLATFORM="linux";;
            Darwin*)    PLATFORM="linux";; # Treat macOS as linux
            CYGWIN*|MINGW*|MSYS*) PLATFORM="windows";;
            *)
                echo "❌ Unable to detect platform, please specify with -p parameter"
                exit 1
                ;;
        esac
    fi
    echo "🔍 Detected platform: $PLATFORM"
}

# Read configuration file
read_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "⚠️ Configuration file not found: $CONFIG_FILE, using default configuration"
        return
    fi

    echo "📖 Reading configuration file: $CONFIG_FILE"
    # YAML parsing logic can be added here, currently using default values
}

# Setup environment variables
setup_environment() {
    echo "🔧 Setting up environment variables..."

    # vcpkg environment variables
    export VCPKG_KEEP_ENV_VARS="HTTP_PROXY;HTTPS_PROXY;http_proxy;https_proxy"
    export VCPKG_MAX_CONCURRENCY="$PARALLEL_JOBS"

    # Set triplet based on platform
    case "$PLATFORM-$ARCH" in
        windows-x64) export VCPKG_TRIPLET="x64-windows"; CMAKE_ARCH="-A x64";;
        windows-x86) export VCPKG_TRIPLET="x86-windows"; CMAKE_ARCH="-A Win32";;
        linux-x64)   export VCPKG_TRIPLET="x64-linux"; CMAKE_ARCH="";;
        *)
            echo "❌ Unsupported platform-architecture combination: $PLATFORM-$ARCH"
            exit 1
            ;;
    esac

    echo "✅ Environment variables setup completed"
    echo "   - VCPKG_TRIPLET: $VCPKG_TRIPLET"
    echo "   - CMAKE_ARCH: $CMAKE_ARCH"
}

# Main function
main() {
    echo "🚀 Starting unified build process"
    echo "================================="

    parse_args "$@"
    detect_platform
    read_config
    setup_environment

    echo ""
    echo "📋 Build configuration:"
    echo "   - Build type: $BUILD_TYPE"
    echo "   - Architecture: $ARCH"
    echo "   - Platform: $PLATFORM"
    echo "   - Parallel jobs: $PARALLEL_JOBS"
    echo "   - ccache: $ENABLE_CCACHE"
    echo ""

    # Call platform-specific build script
    if [[ "$PLATFORM" == "windows" ]]; then
        exec .github/scripts/build-windows.ps1 \
            -BuildType "$BUILD_TYPE" \
            -Arch "$ARCH" \
            -ParallelJobs "$PARALLEL_JOBS" \
            -EnableCcache "$ENABLE_CCACHE"
    else
        exec .github/scripts/build-linux.sh \
            --build-type "$BUILD_TYPE" \
            --arch "$ARCH" \
            --jobs "$PARALLEL_JOBS" \
            $([ "$ENABLE_CCACHE" == "false" ] && echo "--no-ccache")
    fi
}

# If this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
