#!/bin/bash

# Unified Packaging Script
# Consolidates all packaging logic for xdelta3 across platforms and package types
# Eliminates duplication between Windows/Linux packaging and different package formats

set -e

# Script directory and configuration
SCRIPT_DIR="$(dirname "$0")"
CONFIG_FILE="$SCRIPT_DIR/../config/build-config.yml"

# Default values
PACKAGE_TYPE="binary"
OS=""
ARCH=""
VERSION=""
ARTIFACTS_DIR=""
OUTPUT_DIR="packages"
BUILD_TYPE="Release"
CREATE_ARCHIVES="false"
VERBOSE=false

# Color output functions
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

# Logging functions
log_info() { print_color blue "ℹ️ $1"; }
log_success() { print_color green "✅ $1"; }
log_warning() { print_color yellow "⚠️ $1"; }
log_error() { print_color red "❌ $1"; }

# Help information
show_help() {
    cat << EOF
Unified Packaging Script for xdelta3

Usage: $0 [options]

Options:
    --type TYPE         Package type (binary|vcpkg|test) [default: binary]
    --os OS             Operating system (windows|linux)
    --arch ARCH         Architecture (x64|x86) [default: x64]
    --version VERSION   Version string (e.g., 3.1.0)
    --artifacts-dir DIR Directory containing build artifacts
    --output-dir DIR    Output directory for packages [default: packages]
    --build-type TYPE   Build type (Debug|Release) [default: Release]
    --create-archives   Create archive files (zip/tar.gz)
    --verbose           Enable verbose output
    -h, --help          Show this help message

Package Types:
    binary    - Standard binary distribution package
    vcpkg     - vcpkg registry compatible package
    test      - Minimal test package for PR validation

Examples:
    $0 --type binary --os windows --arch x64 --version 3.1.0 --artifacts-dir artifacts
    $0 --type vcpkg --version 3.1.0 --artifacts-dir downloaded-artifacts
    $0 --type test --os linux --arch x64 --artifacts-dir artifacts
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --type)
                PACKAGE_TYPE="$2"
                shift 2
                ;;
            --os)
                OS="$2"
                shift 2
                ;;
            --arch)
                ARCH="$2"
                shift 2
                ;;
            --version)
                VERSION="$2"
                shift 2
                ;;
            --artifacts-dir)
                ARTIFACTS_DIR="$2"
                shift 2
                ;;
            --output-dir)
                OUTPUT_DIR="$2"
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
            --verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Validate configuration
validate_config() {
    local errors=0

    # Check required parameters based on package type
    case "$PACKAGE_TYPE" in
        binary|test)
            if [[ -z "$OS" || -z "$ARCH" ]]; then
                log_error "OS and ARCH are required for $PACKAGE_TYPE packages"
                errors=$((errors + 1))
            fi
            ;;
        vcpkg)
            if [[ -z "$VERSION" ]]; then
                log_error "VERSION is required for vcpkg packages"
                errors=$((errors + 1))
            fi
            ;;
    esac

    # For binary packages, check if we have either build directory or artifacts directory
    if [[ "$PACKAGE_TYPE" == "binary" ]]; then
        local has_build_dir=false
        local has_artifacts_dir=false

        # Check for build directory with built files
        if [[ -d "build" ]]; then
            case "$OS" in
                windows)
                    if [[ -f "build/$BUILD_TYPE/xdelta3.exe" ]]; then
                        has_build_dir=true
                    fi
                    ;;
                linux)
                    if [[ -f "build/xdelta3" ]]; then
                        has_build_dir=true
                    fi
                    ;;
            esac
        fi

        # Check for artifacts directory
        if [[ -n "$ARTIFACTS_DIR" && -d "$ARTIFACTS_DIR" ]]; then
            has_artifacts_dir=true
        fi

        if [[ "$has_build_dir" == "false" && "$has_artifacts_dir" == "false" ]]; then
            log_error "Neither build directory with built files nor artifacts directory found"
            log_error "Expected: build/$BUILD_TYPE/xdelta3.exe (Windows) or build/xdelta3 (Linux)"
            log_error "Or: artifacts directory at $ARTIFACTS_DIR"
            errors=$((errors + 1))
        fi
    else
        # For non-binary packages, artifacts directory is required
        if [[ -z "$ARTIFACTS_DIR" ]]; then
            log_error "ARTIFACTS_DIR is required for $PACKAGE_TYPE packages"
            errors=$((errors + 1))
        fi

        if [[ ! -d "$ARTIFACTS_DIR" ]]; then
            log_error "Artifacts directory does not exist: $ARTIFACTS_DIR"
            errors=$((errors + 1))
        fi
    fi

    if [[ $errors -gt 0 ]]; then
        log_error "Configuration validation failed with $errors error(s)"
        exit 1
    fi
}

# Get package configuration from YAML (simplified parser)
get_config_value() {
    local key_path="$1"
    local default_value="$2"

    # Simple YAML parser for our specific needs
    # This is a basic implementation - for production use, consider yq or similar
    if [[ -f "$CONFIG_FILE" ]]; then
        # Try to extract the value using grep and sed
        local value=$(grep -A 10 "$key_path" "$CONFIG_FILE" 2>/dev/null | head -1 | sed 's/.*: *"\?\([^"]*\)"\?.*/\1/' 2>/dev/null)
        if [[ -n "$value" && "$value" != "$key_path" ]]; then
            echo "$value"
        else
            echo "$default_value"
        fi
    else
        echo "$default_value"
    fi
}

# Detect version if not provided
detect_version() {
    if [[ -z "$VERSION" ]]; then
        log_info "Detecting version from CMakeLists.txt..."

        # Try to extract version from CMakeLists.txt
        if [[ -f "CMakeLists.txt" ]]; then
            VERSION=$(grep -o 'project(xdelta.*VERSION [0-9.]*' CMakeLists.txt | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
        fi

        # Fallback to default version
        if [[ -z "$VERSION" ]]; then
            VERSION="3.1.0"
            log_warning "Could not detect version, using fallback: $VERSION"
        else
            log_success "Detected version: $VERSION"
        fi
    fi
}

# Set default architecture if not provided
set_defaults() {
    if [[ -z "$ARCH" ]]; then
        ARCH="x64"
        log_info "Using default architecture: $ARCH"
    fi
}

# Main packaging function
main() {
    log_info "🚀 Starting unified packaging process"
    log_info "======================================="

    parse_args "$@"
    validate_config
    detect_version
    set_defaults

    log_info "📋 Packaging configuration:"
    log_info "   - Package type: $PACKAGE_TYPE"
    log_info "   - Operating system: $OS"
    log_info "   - Architecture: $ARCH"
    log_info "   - Version: $VERSION"
    log_info "   - Artifacts directory: $ARTIFACTS_DIR"
    log_info "   - Output directory: $OUTPUT_DIR"
    log_info "   - Build type: $BUILD_TYPE"
    echo ""

    # Create output directory
    mkdir -p "$OUTPUT_DIR"

    # Route to appropriate packaging function
    case "$PACKAGE_TYPE" in
        binary)
            package_binary
            ;;
        vcpkg)
            package_vcpkg
            ;;
        test)
            package_test
            ;;
        *)
            log_error "Unknown package type: $PACKAGE_TYPE"
            exit 1
            ;;
    esac

    log_success "🎉 Packaging completed successfully!"
}

# Package binary distribution
package_binary() {
    log_info "📦 Creating binary package for $OS-$ARCH"

    # Use simple OS-ARCH format for compatibility with workflow expectations
    local package_name="$OS-$ARCH"
    local package_dir="$OUTPUT_DIR/$package_name"

    # For binary packaging, check if we're working with build directory or artifacts directory
    local artifact_source
    if [[ -d "build" && -f "build/$BUILD_TYPE/xdelta3.exe" ]] || [[ -d "build" && -f "build/xdelta3" ]]; then
        # We're in the build workflow context
        artifact_source="build"
        log_info "Using build directory as artifact source"
    elif [[ -d "$ARTIFACTS_DIR" ]]; then
        # We're in a context where artifacts have been downloaded/prepared
        artifact_source="$ARTIFACTS_DIR"
        log_info "Using artifacts directory as source: $artifact_source"
    else
        log_error "Neither build directory nor artifacts directory found"
        return 1
    fi

    # Create package directory
    mkdir -p "$package_dir"

    # Copy artifacts based on platform and source type
    case "$OS" in
        windows)
            if [[ "$artifact_source" == "build" ]]; then
                copy_windows_artifacts_from_build "$artifact_source" "$package_dir"
            else
                copy_windows_artifacts "$artifact_source/$package_name" "$package_dir"
            fi
            create_readme_windows "$package_dir"
            if [[ "$CREATE_ARCHIVES" == "true" ]]; then
                create_archive_zip "$package_dir" "$OUTPUT_DIR/xdelta3-$package_name.zip"
            fi
            ;;
        linux)
            if [[ "$artifact_source" == "build" ]]; then
                copy_linux_artifacts_from_build "$artifact_source" "$package_dir"
            else
                copy_linux_artifacts "$artifact_source/$package_name" "$package_dir"
            fi
            create_readme_linux "$package_dir"
            if [[ "$CREATE_ARCHIVES" == "true" ]]; then
                create_archive_tar "$package_dir" "$OUTPUT_DIR/xdelta3-$package_name.tar.gz"
            fi
            ;;
        *)
            log_error "Unsupported OS for binary packaging: $OS"
            return 1
            ;;
    esac

    log_success "Binary package created: $package_name"
}

# Package vcpkg distribution
package_vcpkg() {
    log_info "📦 Creating vcpkg package for version $VERSION"

    local package_name="xdelta-$VERSION-windows"
    local package_dir="$OUTPUT_DIR/$package_name"

    # Create vcpkg directory structure
    mkdir -p "$package_dir/$VERSION"

    # Create architecture-specific directories
    for arch in x64 x86; do
        mkdir -p "$package_dir/$VERSION/$arch-windows/bin"
        mkdir -p "$package_dir/$VERSION/$arch-windows/lib"
        mkdir -p "$package_dir/$VERSION/$arch-windows/include/xdelta3"
    done

    # Copy artifacts for each architecture
    copy_vcpkg_artifacts "$package_dir"
    create_vcpkg_documentation "$package_dir/$VERSION"
    create_archive_zip "$package_dir" "$OUTPUT_DIR/$package_name.zip"
    create_sha512_hash "$OUTPUT_DIR/$package_name.zip"

    log_success "vcpkg package created: $package_name"
}

# Package test distribution (minimal for PR validation)
package_test() {
    log_info "📦 Creating test package for $OS-$ARCH"

    # Create vcpkg-style structure for test package compatibility
    local package_name="xdelta-$VERSION-$OS"
    local package_dir="$OUTPUT_DIR/$package_name"
    local artifact_source="$ARTIFACTS_DIR/$OS-$ARCH"

    # Create vcpkg-style directory structure
    local arch_dir="$package_dir/$VERSION/$ARCH-$OS"
    mkdir -p "$arch_dir/bin"
    mkdir -p "$arch_dir/lib"
    mkdir -p "$arch_dir/include/xdelta3"

    # Copy files based on OS
    case "$OS" in
        windows)
            # Copy executable
            if [[ -f "$artifact_source/xdelta3.exe" ]]; then
                cp "$artifact_source/xdelta3.exe" "$arch_dir/bin/"
                log_success "Copied executable to bin/"
            else
                log_error "xdelta3.exe not found in $artifact_source"
                return 1
            fi

            # Copy library files if available
            if [[ -f "$artifact_source/xdelta.lib" ]]; then
                cp "$artifact_source/xdelta.lib" "$arch_dir/lib/"
                log_success "Copied library to lib/"
            fi

            # Copy essential DLLs
            find "$artifact_source" -name "*.dll" -exec cp {} "$arch_dir/bin/" \; 2>/dev/null || true

            # Create minimal header file for testing
            cat > "$arch_dir/include/xdelta3/xdelta3.h" << 'EOF'
// Minimal xdelta3.h for test package compatibility
#ifndef XDELTA3_H
#define XDELTA3_H

// This is a minimal header file for testing purposes
// For full functionality, use the complete xdelta3 source

#ifdef __cplusplus
extern "C" {
#endif

// Basic type definitions for compatibility
typedef unsigned char uint8_t;
typedef unsigned int uint32_t;

// Minimal function declarations
int xdelta3_encode_memory(const uint8_t *input, uint32_t input_size,
                         const uint8_t *source, uint32_t source_size,
                         uint8_t *output, uint32_t *output_size,
                         uint32_t flags);

int xdelta3_decode_memory(const uint8_t *input, uint32_t input_size,
                         const uint8_t *source, uint32_t source_size,
                         uint8_t *output, uint32_t *output_size,
                         uint32_t flags);

#ifdef __cplusplus
}
#endif

#endif // XDELTA3_H
EOF
            log_success "Created minimal header file"

            create_archive_zip "$package_dir" "$OUTPUT_DIR/xdelta3-$OS-$ARCH-test.zip"
            ;;
        linux)
            # Copy executable
            if [[ -f "$artifact_source/xdelta3" ]]; then
                cp "$artifact_source/xdelta3" "$arch_dir/bin/"
                chmod +x "$arch_dir/bin/xdelta3"
                log_success "Copied executable to bin/"
            else
                log_error "xdelta3 not found in $artifact_source"
                return 1
            fi

            # Copy library files if available
            if [[ -f "$artifact_source/libxdelta.a" ]]; then
                cp "$artifact_source/libxdelta.a" "$arch_dir/lib/"
                log_success "Copied library to lib/"
            fi

            # Create minimal header file for testing
            cat > "$arch_dir/include/xdelta3/xdelta3.h" << 'EOF'
// Minimal xdelta3.h for test package compatibility
#ifndef XDELTA3_H
#define XDELTA3_H

// This is a minimal header file for testing purposes
// For full functionality, use the complete xdelta3 source

#ifdef __cplusplus
extern "C" {
#endif

// Basic type definitions for compatibility
typedef unsigned char uint8_t;
typedef unsigned int uint32_t;

// Minimal function declarations
int xdelta3_encode_memory(const uint8_t *input, uint32_t input_size,
                         const uint8_t *source, uint32_t source_size,
                         uint8_t *output, uint32_t *output_size,
                         uint32_t flags);

int xdelta3_decode_memory(const uint8_t *input, uint32_t input_size,
                         const uint8_t *source, uint32_t source_size,
                         uint8_t *output, uint32_t *output_size,
                         uint32_t flags);

#ifdef __cplusplus
}
#endif

#endif // XDELTA3_H
EOF
            log_success "Created minimal header file"

            create_archive_tar "$package_dir" "$OUTPUT_DIR/xdelta3-$OS-$ARCH-test.tar.gz"
            ;;
    esac

    log_success "Test package created: $package_name (vcpkg-style structure)"
}

# Copy Windows artifacts from build directory
copy_windows_artifacts_from_build() {
    local build_dir="$1"
    local dest_dir="$2"

    log_info "Copying Windows artifacts from build directory $build_dir to $dest_dir"

    # Copy executable
    local exe_path="$build_dir/$BUILD_TYPE/xdelta3.exe"
    if [[ -f "$exe_path" ]]; then
        cp "$exe_path" "$dest_dir/"
        log_success "Copied xdelta3.exe"
    else
        log_error "xdelta3.exe not found at $exe_path"
        return 1
    fi

    # Copy library file - try different possible locations
    local lib_paths=(
        "$build_dir/$BUILD_TYPE/xdelta.lib"    # Standard MSVC location
        "$build_dir/xdelta.lib"                # Alternative location
    )

    local lib_found=false
    for lib_path in "${lib_paths[@]}"; do
        if [[ -f "$lib_path" ]]; then
            cp "$lib_path" "$dest_dir/"
            log_success "Copied xdelta.lib from $lib_path"
            lib_found=true
            break
        fi
    done

    if [[ "$lib_found" == "false" ]]; then
        log_warning "xdelta.lib not found in any of the expected locations:"
        for lib_path in "${lib_paths[@]}"; do
            log_warning "  - $lib_path"
        done

        # List available files for debugging
        log_info "Available files in build directory:"
        find "$build_dir" -name "*.lib" -o -name "xdelta*" | head -10
    fi

    # Copy vcpkg DLL files
    local vcpkg_bin_dir
    case "$ARCH" in
        x64) vcpkg_bin_dir="vcpkg/installed/x64-windows/bin" ;;
        x86) vcpkg_bin_dir="vcpkg/installed/x86-windows/bin" ;;
    esac

    if [[ -d "$vcpkg_bin_dir" ]]; then
        log_info "Copying vcpkg DLL files from $vcpkg_bin_dir"
        find "$vcpkg_bin_dir" -name "*.dll" | while read dll; do
            if [[ "$(basename "$dll")" =~ (lzma|zlib|bzip2) ]]; then
                cp "$dll" "$dest_dir/"
                log_success "Copied DLL: $(basename "$dll")"
            fi
        done
    fi
}

# Copy Linux artifacts from build directory
copy_linux_artifacts_from_build() {
    local build_dir="$1"
    local dest_dir="$2"

    log_info "Copying Linux artifacts from build directory $build_dir to $dest_dir"

    # Copy executable
    local exe_path="$build_dir/xdelta3"
    if [[ -f "$exe_path" ]]; then
        cp "$exe_path" "$dest_dir/"
        chmod +x "$dest_dir/xdelta3"
        log_success "Copied xdelta3"
    else
        log_error "xdelta3 not found at $exe_path"
        return 1
    fi

    # Copy library file - try different possible locations
    local lib_paths=(
        "$build_dir/libxdelta.a"           # Standard location
        "$build_dir/$BUILD_TYPE/libxdelta.a"  # Build type subdirectory
    )

    local lib_found=false
    for lib_path in "${lib_paths[@]}"; do
        if [[ -f "$lib_path" ]]; then
            cp "$lib_path" "$dest_dir/"
            log_success "Copied libxdelta.a from $lib_path"
            lib_found=true
            break
        fi
    done

    if [[ "$lib_found" == "false" ]]; then
        log_warning "libxdelta.a not found in any of the expected locations:"
        for lib_path in "${lib_paths[@]}"; do
            log_warning "  - $lib_path"
        done

        # List available files for debugging
        log_info "Available files in build directory:"
        find "$build_dir" -name "*.a" -o -name "libxdelta*" | head -10
    fi
}

# Copy Windows artifacts (for downloaded artifacts)
copy_windows_artifacts() {
    local source_dir="$1"
    local dest_dir="$2"

    log_info "Copying Windows artifacts from $source_dir to $dest_dir"

    # Copy executable
    if [[ -f "$source_dir/xdelta3.exe" ]]; then
        cp "$source_dir/xdelta3.exe" "$dest_dir/"
        log_success "Copied xdelta3.exe"
    else
        log_error "xdelta3.exe not found in $source_dir"
        return 1
    fi

    # Copy library files
    if [[ -f "$source_dir/xdelta.lib" ]]; then
        cp "$source_dir/xdelta.lib" "$dest_dir/"
        log_success "Copied xdelta.lib"
    fi

    # Copy DLL dependencies
    find "$source_dir" -name "*.dll" | while read dll; do
        cp "$dll" "$dest_dir/"
        log_success "Copied $(basename "$dll")"
    done
}

# Copy Linux artifacts
copy_linux_artifacts() {
    local source_dir="$1"
    local dest_dir="$2"

    log_info "Copying Linux artifacts from $source_dir to $dest_dir"

    # Copy executable
    if [[ -f "$source_dir/xdelta3" ]]; then
        cp "$source_dir/xdelta3" "$dest_dir/"
        chmod +x "$dest_dir/xdelta3"
        log_success "Copied xdelta3"
    else
        log_error "xdelta3 not found in $source_dir"
        return 1
    fi

    # Copy library files
    if [[ -f "$source_dir/libxdelta.a" ]]; then
        cp "$source_dir/libxdelta.a" "$dest_dir/"
        log_success "Copied libxdelta.a"
    fi
}

# Copy vcpkg artifacts
copy_vcpkg_artifacts() {
    local package_dir="$1"

    log_info "Copying vcpkg artifacts"

    # Copy artifacts for each architecture
    for arch in x64 x86; do
        # Try different possible artifact source paths
        local artifact_sources=(
            "$ARTIFACTS_DIR/xdelta3-windows-$arch"  # From reusable build workflow
            "$ARTIFACTS_DIR/windows-$arch"          # Alternative naming
        )

        local dest_dir="$package_dir/$VERSION/$arch-windows"
        local artifact_source=""

        # Find the correct artifact source directory
        for source in "${artifact_sources[@]}"; do
            if [[ -d "$source" ]]; then
                artifact_source="$source"
                log_info "Found $arch artifacts at: $artifact_source"
                break
            fi
        done

        if [[ -n "$artifact_source" && -d "$artifact_source" ]]; then
            # Copy executable
            if [[ -f "$artifact_source/xdelta3.exe" ]]; then
                cp "$artifact_source/xdelta3.exe" "$dest_dir/bin/"
                log_success "Copied $arch executable to bin/"
            else
                log_warning "xdelta3.exe not found in $artifact_source"
            fi

            # Copy library files
            if [[ -f "$artifact_source/xdelta.lib" ]]; then
                cp "$artifact_source/xdelta.lib" "$dest_dir/lib/"
                log_success "Copied $arch library to lib/"
            else
                log_warning "xdelta.lib not found in $artifact_source"
            fi

            # Copy DLLs
            local dll_count=0
            while IFS= read -r -d '' dll; do
                cp "$dll" "$dest_dir/bin/"
                log_success "Copied DLL: $(basename "$dll")"
                ((dll_count++))
            done < <(find "$artifact_source" -name "*.dll" -print0 2>/dev/null)

            if [[ $dll_count -eq 0 ]]; then
                log_info "No DLL files found in $artifact_source"
            fi
        else
            log_error "$arch artifacts not found. Checked paths:"
            for source in "${artifact_sources[@]}"; do
                log_error "  - $source"
            done

            # List available directories for debugging
            log_info "Available directories in $ARTIFACTS_DIR:"
            if [[ -d "$ARTIFACTS_DIR" ]]; then
                find "$ARTIFACTS_DIR" -maxdepth 2 -type d | sort
            else
                log_error "Artifacts directory $ARTIFACTS_DIR does not exist"
            fi
            return 1
        fi
    done

    # Copy header files
    copy_header_files "$package_dir/$VERSION"
}

# Copy header files for vcpkg
copy_header_files() {
    local version_dir="$1"

    log_info "Copying header files"

    # Look for header files in the source tree
    local header_files=("xdelta3.h" "xdelta3-decode.h" "xdelta3-list.h" "xdelta3-main.h" "xdelta3-second.h" "xdelta3-test.h")

    for header in "${header_files[@]}"; do
        # Try different possible locations
        local header_paths=("xdelta3/$header" "src/$header" "$header")

        for path in "${header_paths[@]}"; do
            if [[ -f "$path" ]]; then
                # Copy to both architectures
                cp "$path" "$version_dir/x64-windows/include/xdelta3/"
                cp "$path" "$version_dir/x86-windows/include/xdelta3/"
                log_success "Copied $header"
                break
            fi
        done
    done

    # Create minimal header if none found
    if [[ ! -f "$version_dir/x64-windows/include/xdelta3/xdelta3.h" ]]; then
        log_warning "No header files found, creating minimal xdelta3.h"
        echo "// Minimal xdelta3.h for vcpkg compatibility" > "$version_dir/x64-windows/include/xdelta3/xdelta3.h"
        echo "// Minimal xdelta3.h for vcpkg compatibility" > "$version_dir/x86-windows/include/xdelta3/xdelta3.h"
    fi
}

# Create Windows README
create_readme_windows() {
    local dest_dir="$1"
    local readme_path="$dest_dir/README.txt"

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

    log_success "Created README.txt"
}

# Create Linux README
create_readme_linux() {
    local dest_dir="$1"
    local readme_path="$dest_dir/README.txt"

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

    log_success "Created README.txt"
}

# Create vcpkg documentation
create_vcpkg_documentation() {
    local version_dir="$1"

    # Create README.md
    cat > "$version_dir/README.md" << EOF
# Xdelta $VERSION

Xdelta binary diff and differential compression tools.

This package provides the xdelta3 command-line tool and header files for use with vcpkg.

## Features

- Binary delta compression
- VCDIFF/RFC 3284 compatible
- Cross-platform support
- High compression ratios

For more information, visit: https://github.com/jmacd/xdelta
EOF

    # Create usage.md
    cat > "$version_dir/usage.md" << EOF
# Using Xdelta with vcpkg

This package provides the xdelta3 command-line tool and header files for use with vcpkg.

## Command-line Usage

The xdelta3 executable is available at:
- \${VCPKG_INSTALLED_DIR}/\${VCPKG_TARGET_TRIPLET}/tools/xdelta/xdelta3.exe

## Including in Your Project

To use xdelta in your C/C++ project:

\`\`\`cpp
#include <xdelta3/xdelta3.h>
\`\`\`

For more information, see the [official documentation](https://github.com/jmacd/xdelta/blob/wiki/CommandLineSyntax.md).
EOF

    log_success "Created vcpkg documentation"
}

# Create ZIP archive
create_archive_zip() {
    local source_dir="$1"
    local archive_path="$2"

    log_info "Creating ZIP archive: $archive_path"

    # Remove existing archive
    [[ -f "$archive_path" ]] && rm "$archive_path"

    # Create archive using different methods based on availability
    if command -v powershell.exe &> /dev/null; then
        # Use PowerShell on Windows
        powershell.exe -Command "Compress-Archive -Path '$source_dir' -DestinationPath '$archive_path' -Force"
    elif command -v zip &> /dev/null; then
        # Use zip command
        (cd "$(dirname "$source_dir")" && zip -r "$(basename "$archive_path")" "$(basename "$source_dir")")
        mv "$(dirname "$source_dir")/$(basename "$archive_path")" "$archive_path"
    else
        log_error "No ZIP creation tool available"
        return 1
    fi

    if [[ -f "$archive_path" ]]; then
        log_success "Created ZIP archive: $archive_path"
    else
        log_error "Failed to create ZIP archive"
        return 1
    fi
}

# Create TAR.GZ archive
create_archive_tar() {
    local source_dir="$1"
    local archive_path="$2"

    log_info "Creating TAR.GZ archive: $archive_path"

    # Remove existing archive
    [[ -f "$archive_path" ]] && rm "$archive_path"

    # Get absolute paths to avoid confusion
    local abs_source_dir=$(realpath "$source_dir")
    local abs_archive_path=$(realpath "$archive_path" 2>/dev/null || echo "$archive_path")

    # Create tar.gz archive
    local temp_archive="/tmp/$(basename "$archive_path")"
    (cd "$(dirname "$abs_source_dir")" && tar -czf "$temp_archive" "$(basename "$abs_source_dir")")

    # Move to final location if different
    if [[ "$temp_archive" != "$abs_archive_path" ]]; then
        mv "$temp_archive" "$abs_archive_path"
    fi

    if [[ -f "$abs_archive_path" ]]; then
        log_success "Created TAR.GZ archive: $abs_archive_path"
    else
        log_error "Failed to create TAR.GZ archive"
        return 1
    fi
}

# Create SHA512 hash file
create_sha512_hash() {
    local file_path="$1"
    local hash_path="$file_path.sha512"

    log_info "Creating SHA512 hash for: $file_path"

    if [[ -f "$file_path" ]]; then
        # Calculate SHA512 hash
        local hash
        if command -v sha512sum &> /dev/null; then
            hash=$(sha512sum "$file_path" | awk '{print $1}')
        elif command -v shasum &> /dev/null; then
            hash=$(shasum -a 512 "$file_path" | awk '{print $1}')
        else
            log_error "No SHA512 calculation tool available"
            return 1
        fi

        # Write hash to file
        echo "$hash" > "$hash_path"
        log_success "Created SHA512 hash file: $hash_path"
        log_info "SHA512: $hash"
    else
        log_error "File not found for hash calculation: $file_path"
        return 1
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
