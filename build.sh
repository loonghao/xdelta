#!/bin/bash

# Local build script - consistent with CI environment
# This script calls the unified build script to ensure local and CI environments use the same build logic

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Check dependencies
check_dependencies() {
    print_color blue "🔍 Checking build dependencies..."

    local missing_deps=()

    # Check CMake
    if ! command -v cmake &> /dev/null; then
        missing_deps+=("cmake")
    fi

    # Check Git
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi

    # Check vcpkg (if exists)
    if [[ ! -d "vcpkg" ]]; then
        print_color yellow "⚠️ vcpkg directory does not exist, manual vcpkg setup will be required"
    fi

    # Check ccache (optional)
    if ! command -v ccache &> /dev/null; then
        print_color yellow "⚠️ ccache not installed, build may be slower"
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_color red "❌ Missing the following dependencies:"
        for dep in "${missing_deps[@]}"; do
            print_color red "   - $dep"
        done

        print_color blue "📋 Installation suggestions:"
        print_color white "Ubuntu/Debian: sudo apt-get install cmake git ccache"
        print_color white "CentOS/RHEL: sudo yum install cmake git ccache"
        print_color white "macOS: brew install cmake git ccache"
        print_color white "Windows: Use build.ps1 script"

        exit 1
    fi

    print_color green "✅ All required dependencies are installed"
}

# Setup vcpkg (if needed)
setup_vcpkg() {
    if [[ ! -d "vcpkg" ]]; then
        print_color blue "📦 Setting up vcpkg..."

        print_color yellow "vcpkg directory does not exist. Please choose one of the following options:"
        print_color white "1. Clone vcpkg repository (recommended)"
        print_color white "2. Skip vcpkg setup (use system libraries)"
        print_color white "3. Exit"

        read -p "Please choose [1-3]: " choice

        case $choice in
            1)
                print_color blue "Cloning vcpkg repository..."
                git clone https://github.com/Microsoft/vcpkg.git
                cd vcpkg
                ./bootstrap-vcpkg.sh
                cd ..
                print_color green "✅ vcpkg setup completed"
                ;;
            2)
                print_color yellow "⚠️ Skipping vcpkg setup, will use system libraries"
                export SKIP_VCPKG=1
                ;;
            3)
                print_color blue "Exiting build"
                exit 0
                ;;
            *)
                print_color red "❌ Invalid choice"
                exit 1
                ;;
        esac
    fi
}

# Show help information
show_help() {
    print_color blue "Local Build Script"
    print_color blue "=================="
    echo ""
    print_color white "This script uses the same build logic as the CI environment to build the project."
    echo ""
    print_color blue "Usage:"
    print_color white "  $0 [options]"
    echo ""
    print_color blue "Options:"
    print_color white "  -t, --build-type TYPE    Build type (Debug|Release) [default: Release]"
    print_color white "  -a, --arch ARCH         Architecture (x64|x86) [default: x64]"
    print_color white "  -j, --jobs JOBS         Number of parallel jobs [default: 2]"
    print_color white "  --no-ccache             Disable ccache"
    print_color white "  --check-deps            Only check dependencies, don't build"
    print_color white "  -h, --help              Show this help message"
    echo ""
    print_color blue "Examples:"
    print_color white "  $0                      # Build with default settings"
    print_color white "  $0 -t Debug -a x86      # Debug mode, x86 architecture"
    print_color white "  $0 --no-ccache          # Build without ccache"
    print_color white "  $0 --check-deps         # Only check dependencies"
    echo ""
    print_color blue "Notes:"
    print_color white "- vcpkg will be automatically set up on first run (if not present)"
    print_color white "- Installing ccache is recommended for faster builds"
    print_color white "- Windows users should use the build.ps1 script"
}

# Parse command line arguments
parse_args() {
    local args=()
    local check_deps_only=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --check-deps)
                check_deps_only=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done

    if [[ "$check_deps_only" == "true" ]]; then
        check_dependencies
        exit 0
    fi

    # Pass remaining arguments to build script
    BUILD_ARGS=("${args[@]}")
}

# Main function
main() {
    print_color blue "🚀 Starting local build"
    print_color blue "======================="
    echo ""

    parse_args "$@"

    # Check dependencies
    check_dependencies

    # Setup vcpkg
    if [[ -z "$SKIP_VCPKG" ]]; then
        setup_vcpkg
    fi

    # Ensure build script is executable
    chmod +x "$SCRIPT_DIR/.github/scripts/build-common.sh"

    print_color blue "📋 Calling unified build script..."
    print_color white "Script path: $SCRIPT_DIR/.github/scripts/build-common.sh"
    print_color white "Arguments: ${BUILD_ARGS[*]}"
    echo ""

    # Call unified build script
    exec "$SCRIPT_DIR/.github/scripts/build-common.sh" "${BUILD_ARGS[@]}"
}

# If this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
