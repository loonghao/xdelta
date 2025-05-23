#!/usr/bin/env pwsh
# Simple verification script for vcpkg registry

param(
    [string]$Version = "3.1.0",
    [string]$ExpectedSHA512 = "5255fb6d078ef182c7d0974ecf4db68aa5f2756f2f15f91d7dd0ee751821bdab5b8c8268c42eb21b4450b981637a7adb39d2342988737b2faa76341cf915afab"
)

Write-Host "Verifying vcpkg registry for version $Version" -ForegroundColor Green

$errors = 0

# Check portfile.cmake
$portfilePath = "vcpkg-registry/ports/xdelta/portfile.cmake"
if (Test-Path $portfilePath) {
    $portfileContent = Get-Content $portfilePath -Raw
    if ($portfileContent -match 'SHA512 "([a-f0-9]+)"') {
        $actualSHA512 = $matches[1]
        if ($actualSHA512 -eq $ExpectedSHA512) {
            Write-Host "✅ portfile.cmake SHA512 is correct" -ForegroundColor Green
        } else {
            Write-Host "❌ portfile.cmake SHA512 mismatch" -ForegroundColor Red
            Write-Host "  Expected: $ExpectedSHA512" -ForegroundColor Yellow
            Write-Host "  Found:    $actualSHA512" -ForegroundColor Yellow
            $errors++
        }
    } else {
        Write-Host "❌ SHA512 not found in portfile.cmake" -ForegroundColor Red
        $errors++
    }
} else {
    Write-Host "❌ portfile.cmake not found" -ForegroundColor Red
    $errors++
}

# Check vcpkg.json
$vcpkgJsonPath = "vcpkg-registry/ports/xdelta/vcpkg.json"
if (Test-Path $vcpkgJsonPath) {
    $vcpkgJson = Get-Content $vcpkgJsonPath | ConvertFrom-Json
    if ($vcpkgJson.version -eq $Version) {
        Write-Host "✅ vcpkg.json version is correct" -ForegroundColor Green
    } else {
        Write-Host "❌ vcpkg.json version mismatch" -ForegroundColor Red
        Write-Host "  Expected: $Version" -ForegroundColor Yellow
        Write-Host "  Found:    $($vcpkgJson.version)" -ForegroundColor Yellow
        $errors++
    }
} else {
    Write-Host "❌ vcpkg.json not found" -ForegroundColor Red
    $errors++
}

# Check versions/x-/xdelta.json
$versionJsonPath = "vcpkg-registry/versions/x-/xdelta.json"
if (Test-Path $versionJsonPath) {
    $versionJson = Get-Content $versionJsonPath | ConvertFrom-Json
    $latestVersion = $versionJson.versions[0]
    if ($latestVersion.version -eq $Version) {
        Write-Host "✅ xdelta.json version is correct" -ForegroundColor Green
    } else {
        Write-Host "❌ xdelta.json version mismatch" -ForegroundColor Red
        Write-Host "  Expected: $Version" -ForegroundColor Yellow
        Write-Host "  Found:    $($latestVersion.version)" -ForegroundColor Yellow
        $errors++
    }
    
    if ($latestVersion.'git-tree') {
        Write-Host "✅ xdelta.json git-tree exists: $($latestVersion.'git-tree')" -ForegroundColor Green
    } else {
        Write-Host "❌ xdelta.json git-tree is missing" -ForegroundColor Red
        $errors++
    }
} else {
    Write-Host "❌ xdelta.json not found" -ForegroundColor Red
    $errors++
}

# Check baseline.json
$baselineJsonPath = "vcpkg-registry/versions/baseline.json"
if (Test-Path $baselineJsonPath) {
    $baselineJson = Get-Content $baselineJsonPath | ConvertFrom-Json
    if ($baselineJson.default.xdelta.baseline -eq $Version) {
        Write-Host "✅ baseline.json version is correct" -ForegroundColor Green
    } else {
        Write-Host "❌ baseline.json version mismatch" -ForegroundColor Red
        Write-Host "  Expected: $Version" -ForegroundColor Yellow
        Write-Host "  Found:    $($baselineJson.default.xdelta.baseline)" -ForegroundColor Yellow
        $errors++
    }
} else {
    Write-Host "❌ baseline.json not found" -ForegroundColor Red
    $errors++
}

if ($errors -eq 0) {
    Write-Host "✅ All vcpkg registry files are correctly configured!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ Found $errors error(s) in vcpkg registry configuration" -ForegroundColor Red
    exit 1
}
