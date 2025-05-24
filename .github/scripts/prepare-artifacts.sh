#!/bin/bash

# Artifact preparation script
# Unified handling of Windows and Linux artifact preparation

set -e

# Default configuration
OS=""
ARCH=""
BUILD_TYPE="Release"
CREATE_ARCHIVES="false"

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
Artifact Preparation Script

Usage: $0 [options]

Options:
    --os OS             Operating system (windows|linux)
    --arch ARCH         Architecture (x64|x86)
    --build-type TYPE   Build type (Debug|Release) [default: Release]
    --create-archives   Create archives
    -h, --help          Show this help message

Examples:
    $0 --os windows --arch x64 --build-type Release
    $0 --os linux --arch x64 --create-archives
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --os)
                OS="$2"
                shift 2
                ;;
            --arch)
                ARCH="$2"
                shift 2
                ;;
            --build-type)
                BUILD_TYPE="$2"
                shift 2
                ;;
            --create-archives)
                CREATE_ARCHIVES="true"
                shift
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

    # Validate required parameters
    if [[ -z "$OS" || -z "$ARCH" ]]; then
        echo "Error: --os and --arch parameters are required"
        show_help
        exit 1
    fi
}

# Prepare Windows artifacts
prepare_windows_artifacts() {
    print_color blue "📦 Preparing Windows artifacts..."

    local artifacts_dir="artifacts/$OS-$ARCH"
    mkdir -p "$artifacts_dir"

    # Copy executable file
    local exe_path="build/$BUILD_TYPE/xdelta3.exe"
    if [[ -f "$exe_path" ]]; then
        cp "$exe_path" "$artifacts_dir/"
        print_color green "✅ Copied executable: $exe_path"
    else
        print_color red "❌ Executable not found: $exe_path"
        return 1
    fi

    # Copy library file
    local lib_path="build/$BUILD_TYPE/xdelta.lib"
    if [[ -f "$lib_path" ]]; then
        cp "$lib_path" "$artifacts_dir/"
        print_color green "✅ Copied library: $lib_path"
    else
        print_color yellow "⚠️ Library not found: $lib_path"
    fi

    # Copy vcpkg DLL files
    local vcpkg_bin_dir
    case "$ARCH" in
        x64) vcpkg_bin_dir="vcpkg/installed/x64-windows/bin" ;;
        x86) vcpkg_bin_dir="vcpkg/installed/x86-windows/bin" ;;
    esac

    if [[ -d "$vcpkg_bin_dir" ]]; then
        print_color blue "📋 Copying vcpkg DLL files..."
        find "$vcpkg_bin_dir" -name "*.dll" | while read dll; do
            if [[ "$(basename "$dll")" =~ (lzma|zlib|bzip2) ]]; then
                cp "$dll" "$artifacts_dir/"
                print_color green "✅ Copied DLL: $(basename "$dll")"
            fi
        done
    fi

    # Copy vcpkg library files
    local vcpkg_lib_dir
    case "$ARCH" in
        x64) vcpkg_lib_dir="vcpkg/installed/x64-windows/lib" ;;
        x86) vcpkg_lib_dir="vcpkg/installed/x86-windows/lib" ;;
    esac

    if [[ -d "$vcpkg_lib_dir" ]]; then
        print_color blue "📋 Copying vcpkg library files..."
        find "$vcpkg_lib_dir" -name "*.lib" | while read lib; do
            if [[ "$(basename "$lib")" =~ (lzma|zlib|bzip2) ]]; then
                cp "$lib" "$artifacts_dir/"
                print_color green "✅ Copied library: $(basename "$lib")"
            fi
        done
    fi

    # Create README file
    create_readme_windows "$artifacts_dir"

    # Create archive
    if [[ "$CREATE_ARCHIVES" == "true" ]]; then
        create_windows_archive "$artifacts_dir"
    fi
}

# Prepare Linux artifacts
prepare_linux_artifacts() {
    print_color blue "📦 Preparing Linux artifacts..."

    local artifacts_dir="artifacts/$OS-$ARCH"
    mkdir -p "$artifacts_dir"

    # Copy executable file
    local exe_path="build/xdelta3"
    if [[ -f "$exe_path" ]]; then
        cp "$exe_path" "$artifacts_dir/"
        print_color green "✅ Copied executable: $exe_path"
    else
        print_color red "❌ Executable not found: $exe_path"
        return 1
    fi

    # Copy library file
    local lib_path="build/libxdelta.a"
    if [[ -f "$lib_path" ]]; then
        cp "$lib_path" "$artifacts_dir/"
        print_color green "✅ Copied library: $lib_path"
    else
        print_color yellow "⚠️ Library not found: $lib_path"
    fi

    # Create README file
    create_readme_linux "$artifacts_dir"

    # Create archive
    if [[ "$CREATE_ARCHIVES" == "true" ]]; then
        create_linux_archive "$artifacts_dir"
    fi
}

# Create Windows README
create_readme_windows() {
    local artifacts_dir="$1"
    local readme_path="$artifacts_dir/README.txt"

    cat > "$readme_path" << 'EOF'
Xdelta3 Windows Binary
======================

This package contains the xdelta3 command-line utility for Windows.

Command Line Syntax
-------------------

make patch:

  xdelta3.exe -e -s old_file new_file delta_file

apply patch:

  xdelta3.exe -d -s old_file delta_file decoded_new_file

standard options:
   -0 .. -9     compression level
   -c           use stdout
   -d           decompress
   -e           compress
   -f           force (overwrite, ignore trailing garbage)
   -h           show help
   -q           be quiet
   -v           be verbose (max 2)
   -V           show version

For full documentation, run: xdelta3.exe --help
EOF

    print_color green "✅ Created README.txt"
}

# Create Linux README
create_readme_linux() {
    local artifacts_dir="$1"
    local readme_path="$artifacts_dir/README.txt"

    cat > "$readme_path" << 'EOF'
Xdelta3 Linux Binary
====================

This package contains the xdelta3 command-line utility for Linux.

Command Line Syntax
-------------------

make patch:

  ./xdelta3 -e -s old_file new_file delta_file

apply patch:

  ./xdelta3 -d -s old_file delta_file decoded_new_file

standard options:
   -0 .. -9     compression level
   -c           use stdout
   -d           decompress
   -e           compress
   -f           force (overwrite, ignore trailing garbage)
   -h           show help
   -q           be quiet
   -v           be verbose (max 2)
   -V           show version

For full documentation, run: ./xdelta3 --help
EOF

    print_color green "✅ Created README.txt"
}

# Create Windows archive
create_windows_archive() {
    local artifacts_dir="$1"
    local archive_path="$artifacts_dir/xdelta3-$OS-$ARCH.zip"

    print_color blue "📦 Creating ZIP archive..."

    # Use PowerShell to create ZIP file (if in Windows environment)
    if command -v powershell.exe &> /dev/null; then
        powershell.exe -Command "Compress-Archive -Path '$artifacts_dir/*' -DestinationPath '$archive_path' -Force"
    elif command -v zip &> /dev/null; then
        (cd "$artifacts_dir" && zip -r "$(basename "$archive_path")" .)
    else
        print_color yellow "⚠️ Unable to create ZIP file, missing compression tools"
        return 1
    fi

    if [[ -f "$archive_path" ]]; then
        print_color green "✅ Created archive: $archive_path"
    else
        print_color red "❌ Archive creation failed"
        return 1
    fi
}

# Create Linux archive
create_linux_archive() {
    local artifacts_dir="$1"
    local archive_path="$artifacts_dir/xdelta3-$OS-$ARCH.tar.gz"

    print_color blue "📦 Creating tar.gz archive..."

    (cd "$artifacts_dir" && tar -czf "$(basename "$archive_path")" *)

    if [[ -f "$archive_path" ]]; then
        print_color green "✅ Created archive: $archive_path"
    else
        print_color red "❌ Archive creation failed"
        return 1
    fi
}

# Main function
main() {
    print_color blue "🚀 Starting artifact preparation process"
    print_color blue "========================================"

    parse_args "$@"

    print_color blue "📋 Artifact preparation parameters:"
    print_color white "   - Operating system: $OS"
    print_color white "   - Architecture: $ARCH"
    print_color white "   - Build type: $BUILD_TYPE"
    print_color white "   - Create archives: $CREATE_ARCHIVES"
    echo ""

    case "$OS" in
        windows)
            prepare_windows_artifacts
            ;;
        linux)
            prepare_linux_artifacts
            ;;
        *)
            print_color red "❌ Unsupported operating system: $OS"
            exit 1
            ;;
    esac

    print_color green "🎉 Artifact preparation completed!"
}

# If this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
