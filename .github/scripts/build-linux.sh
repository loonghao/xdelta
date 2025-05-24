#!/bin/bash

# Linux build script
# Supports unified building for both local and CI environments

set -e

# Default configuration
BUILD_TYPE="Release"
ARCH="x64"
PARALLEL_JOBS="2"
ENABLE_CCACHE="true"
VCPKG_COMMIT="a34c873a9717a888f58dc05268dea15592c2f0ff"
MAX_RETRIES="3"
RETRY_DELAY="30"

# Color output function
print_color() {
    local color=$1
    local message=$2
    case $color in
        red)    echo -e "\033[31m$message\033[0m" ;;
        green)  echo -e "\033[32m$message\033[0m" ;;
        yellow) echo -e "\033[33m$message\033[0m" ;;
        blue)   echo -e "\033[34m$message\033[0m" ;;
        *)      echo "$message" ;;
    esac
}

# Help information
show_help() {
    cat << EOF
Linux Build Script

Usage: $0 [options]

Options:
    --build-type TYPE    Build type (Debug|Release) [default: Release]
    --arch ARCH         Architecture (x64) [default: x64]
    --jobs JOBS         Number of parallel jobs [default: 2]
    --no-ccache         Disable ccache
    --vcpkg-commit COMMIT vcpkg commit hash
    --max-retries NUM   Maximum retry attempts [default: 3]
    --retry-delay SEC   Retry delay in seconds [default: 30]
    -h, --help          Show this help message

Examples:
    $0                      # Build with default settings
    $0 --build-type Debug   # Debug mode build
    $0 --no-ccache          # Build without ccache
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --build-type)
                BUILD_TYPE="$2"
                shift 2
                ;;
            --arch)
                ARCH="$2"
                shift 2
                ;;
            --jobs)
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
            --max-retries)
                MAX_RETRIES="$2"
                shift 2
                ;;
            --retry-delay)
                RETRY_DELAY="$2"
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

# Retry execution function
retry_command() {
    local description="$1"
    local max_attempts="$MAX_RETRIES"
    local delay="$RETRY_DELAY"
    shift

    for attempt in $(seq 1 $max_attempts); do
        print_color blue "🔄 Attempt $attempt/$max_attempts : $description"

        if "$@"; then
            print_color green "✅ $description succeeded"
            return 0
        else
            print_color red "❌ Attempt $attempt failed"

            if [ $attempt -lt $max_attempts ]; then
                print_color yellow "⏳ Waiting $delay seconds before retry..."
                sleep $delay
            fi
        fi
    done

    print_color red "❌ $description failed after $max_attempts attempts"
    return 1
}

# Set platform configuration
set_platform_config() {
    case "$ARCH" in
        x64)
            TRIPLET="x64-linux"
            CMAKE_ARCH=""
            ;;
        *)
            print_color red "❌ Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac

    print_color blue "📋 Platform configuration:"
    print_color white "   - Architecture: $ARCH"
    print_color white "   - Triplet: $TRIPLET"
}

# Setup environment variables
set_build_environment() {
    print_color blue "🔧 Setting up build environment..."

    # vcpkg environment variables
    export VCPKG_KEEP_ENV_VARS="HTTP_PROXY;HTTPS_PROXY;http_proxy;https_proxy"
    export VCPKG_MAX_CONCURRENCY="$PARALLEL_JOBS"

    print_color green "✅ Environment variables setup completed"
}

# Install vcpkg dependencies
install_vcpkg_dependencies() {
    print_color blue "📦 Installing vcpkg dependencies..."

    # Check if vcpkg.json exists (manifest mode)
    if [[ -f "vcpkg.json" ]]; then
        print_color blue "📋 Using manifest mode (vcpkg.json found)"
        retry_command "Install dependencies from manifest" \
            vcpkg install --triplet=$TRIPLET
    else
        print_color blue "📋 Using classic mode (installing individual packages)"
        retry_command "Install liblzma dependency" \
            vcpkg install liblzma:$TRIPLET --triplet=$TRIPLET
    fi

    # List installed packages
    print_color blue "📋 Installed vcpkg packages:"
    vcpkg list || true
}

# Configure CMake
configure_cmake() {
    print_color blue "⚙️ Configuring CMake..."

    # Get vcpkg paths
    local vcpkg_toolchain
    if [[ -n "$GITHUB_WORKSPACE" ]]; then
        vcpkg_toolchain="$GITHUB_WORKSPACE/vcpkg/scripts/buildsystems/vcpkg.cmake"
    else
        vcpkg_toolchain="./vcpkg/scripts/buildsystems/vcpkg.cmake"
    fi

    # Build CMake arguments
    local cmake_args=(
        "-B" "build"
        "-S" "."
        "-DCMAKE_BUILD_TYPE=$BUILD_TYPE"
        "-DCMAKE_TOOLCHAIN_FILE=$vcpkg_toolchain"
        "-DVCPKG_TARGET_TRIPLET=$TRIPLET"
        "-DXDELTA_ENABLE_LZMA=ON"
        "-DXDELTA_BUILD_TESTS=OFF"
        "-DCMAKE_DISABLE_FIND_PACKAGE_LibLZMA=OFF"
        "-DCMAKE_VERBOSE_MAKEFILE=ON"
    )

    if [[ "$ENABLE_CCACHE" == "true" ]]; then
        cmake_args+=(
            "-DCMAKE_C_COMPILER_LAUNCHER=ccache"
            "-DCMAKE_CXX_COMPILER_LAUNCHER=ccache"
        )
    fi

    retry_command "CMake configuration" \
        cmake "${cmake_args[@]}"
}

# Build project
build_project() {
    print_color blue "🔨 Building project..."

    retry_command "Project build" \
        cmake --build build --config "$BUILD_TYPE" --parallel "$PARALLEL_JOBS"
}

# Test executable
test_executable() {
    print_color blue "🧪 Testing executable..."

    local exe_path="build/xdelta3"
    if [[ -f "$exe_path" ]]; then
        print_color white "Testing executable: $exe_path"
        if "$exe_path" --help; then
            print_color green "✅ Executable test passed"
        else
            print_color yellow "⚠️ Executable test returned non-zero exit code: $?"
        fi
    else
        print_color red "❌ Executable not found: $exe_path"
        return 1
    fi
}

# Main function
main() {
    print_color blue "🚀 Starting Linux build process"
    print_color blue "================================"

    parse_args "$@"

    print_color blue "📋 Build parameters:"
    print_color white "   - Build type: $BUILD_TYPE"
    print_color white "   - Architecture: $ARCH"
    print_color white "   - Parallel jobs: $PARALLEL_JOBS"
    print_color white "   - Enable ccache: $ENABLE_CCACHE"
    print_color white "   - Max retries: $MAX_RETRIES"
    echo ""

    set_platform_config
    set_build_environment
    install_vcpkg_dependencies
    configure_cmake
    build_project
    test_executable

    print_color green "🎉 Linux build completed!"
}

# If this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
