##########################################
# FastLED ESP32-S3 Update & Patch Script
# This script can update FastLED and patch it to work with ESP32-S3
##########################################

Write-Host "====== FastLED ESP32-S3 Update & Patch Script ======" -ForegroundColor Cyan

# Ensure we're running from the project root
if (-not (Test-Path "components" -PathType Container)) {
    Write-Host "ERROR: Please run this script from your project root directory" -ForegroundColor Red
    Write-Host "The 'components' directory was not found!" -ForegroundColor Red
    exit 1
}

# 1. Check if user wants to update/reinstall FastLED
$fastledDir = "components/FastLED"
$updateFastLED = $false

if (Test-Path $fastledDir) {
    Write-Host "`nFastLED already exists at $fastledDir" -ForegroundColor Yellow
    $updateChoice = Read-Host "Would you like to update FastLED to the latest version? (y/n)"
    
    if ($updateChoice -eq "y" -or $updateChoice -eq "Y") {
        $updateFastLED = $true
    }
} else {
    Write-Host "`nFastLED not found, will install it..." -ForegroundColor Yellow
    $updateFastLED = $true
}

# 2. Update/Install FastLED if requested
if ($updateFastLED) {
    Write-Host "`nStep 1: Updating/Installing FastLED..." -ForegroundColor Yellow
    
    # Backup existing FastLED if it exists
    if (Test-Path $fastledDir) {
        $backupDir = "components/FastLED_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Write-Host "Backing up existing FastLED to $backupDir" -ForegroundColor Green
        Move-Item $fastledDir $backupDir
    }
    
    # Clone the latest FastLED
    Write-Host "Cloning latest FastLED from GitHub..." -ForegroundColor Green
    Push-Location components
    git clone https://github.com/FastLED/FastLED.git
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error cloning FastLED repository" -ForegroundColor Red
        # Try to restore backup if we had one
        if (Test-Path $backupDir) {
            Write-Host "Restoring FastLED from backup..." -ForegroundColor Yellow
            Move-Item $backupDir $fastledDir
        }
        exit 1
    }
    Pop-Location
    
    Write-Host "FastLED successfully installed" -ForegroundColor Green
} else {
    Write-Host "Skipping FastLED update, will use existing installation" -ForegroundColor Yellow
}

# 3. Create or update FastLED-ESP32S3 extension component
Write-Host "`nStep 2: Creating FastLED-ESP32S3 extension component..." -ForegroundColor Yellow

$extensionDir = "components/FastLED-ESP32S3_250224"
if (-not (Test-Path $extensionDir)) {
    New-Item -Path $extensionDir -ItemType Directory -Force | Out-Null
    Write-Host "Created extension component directory" -ForegroundColor Green
}

# Create extension CMakeLists.txt
$extensionCMake = @'
cmake_minimum_required(VERSION 3.5)

idf_component_register(
    SRCS "engine_events.cpp" "led_strip_adapter.cpp" "FastLED-ESP32S3_250224.c"
    INCLUDE_DIRS "."
    REQUIRES FastLED led_strip
)

# Add necessary compile definitions for ESP32-S3 support
target_compile_definitions(${COMPONENT_LIB} PUBLIC 
    FASTLED_ESP32=1
    FASTLED_ESP32_S3=1
    FASTLED_FORCE_RMT=1
    FASTLED_RMT_BUILTIN_DRIVER=1
)
'@

Set-Content -Path "$extensionDir/CMakeLists.txt" -Value $extensionCMake
Write-Host "Extension CMakeLists.txt created" -ForegroundColor Green

# Create engine_events.cpp
$engineEvents = @'
#include "fl/engine_events.h"

namespace fl {

// Implement the getInstance method using Meyer's singleton pattern
EngineEvents* EngineEvents::getInstance() {
    static EngineEvents instance;
    return &instance;
}

void EngineEvents::_onBeginFrame() {
    // Empty implementation
}

void EngineEvents::_onEndShowLeds() {
    // Empty implementation
}

void EngineEvents::_onEndFrame() {
    // Empty implementation
}

void EngineEvents::_onStripAdded(CLEDController* strip, unsigned long leds) {
    // Empty implementation
}

} // namespace fl
'@

Set-Content -Path "$extensionDir/engine_events.cpp" -Value $engineEvents
Write-Host "engine_events.cpp created" -ForegroundColor Green

# Create led_strip_adapter.cpp
$ledStripAdapter = @'
#include "led_strip.h"
#include "driver/rmt_types.h"
#include "esp_log.h"

extern "C" {
    // These are the missing functions that the linker is complaining about
    esp_err_t led_strip_refresh_async(led_strip_handle_t strip) {
        // This ensures the function is exported properly
        // Wrap the actual implementation to avoid linking issues
        if (strip == NULL) {
            return ESP_ERR_INVALID_ARG;
        }
        return led_strip_refresh(strip);
    }
    
    esp_err_t led_strip_refresh_wait_done(led_strip_handle_t strip) {
        // This ensures the function is exported properly
        // We return OK directly since we don't need to wait
        if (strip == NULL) {
            return ESP_ERR_INVALID_ARG;
        }
        return ESP_OK;
    }
}
'@

Set-Content -Path "$extensionDir/led_strip_adapter.cpp" -Value $ledStripAdapter
Write-Host "led_strip_adapter.cpp created" -ForegroundColor Green

# Create stub .c file
$stubC = @'
#include <stdio.h>

// This file exists just to make the component valid
void fastled_esp32s3_support_init(void) {
    // Empty initialization function
}
'@

Set-Content -Path "$extensionDir/FastLED-ESP32S3_250224.c" -Value $stubC
Write-Host "FastLED-ESP32S3_250224.c created" -ForegroundColor Green

# 4. Patch FastLED CMakeLists.txt
Write-Host "`nStep 3: Patching FastLED CMakeLists.txt..." -ForegroundColor Yellow

$fastledCMake = "$fastledDir/CMakeLists.txt"

if (-not (Test-Path $fastledCMake)) {
    Write-Host "ERROR: FastLED CMakeLists.txt not found at $fastledCMake" -ForegroundColor Red
    Write-Host "Make sure FastLED is installed in your components directory." -ForegroundColor Red
    exit 1
}

# Create backup
if (-not (Test-Path "$fastledCMake.original")) {
    Copy-Item $fastledCMake "$fastledCMake.original"
    Write-Host "Backup created: $fastledCMake.original" -ForegroundColor Green
}

# Create an additional led_strip_adapter.c directly in FastLED to ensure linking works
$fastLEDAdapterC = @'
// Direct implementation in FastLED to ensure linking works
#include "led_strip.h"

// Explicit implementation of missing functions within FastLED component
esp_err_t led_strip_refresh_async(led_strip_handle_t strip) {
    if (strip == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    // Delegate to standard refresh
    return led_strip_refresh(strip);
}

esp_err_t led_strip_refresh_wait_done(led_strip_handle_t strip) {
    if (strip == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    // No need to wait
    return ESP_OK;
}
'@

Set-Content -Path "$fastledDir/led_strip_adapter.c" -Value $fastLEDAdapterC
Write-Host "Created led_strip_adapter.c in FastLED component" -ForegroundColor Green

# Modify FastLED's CMakeLists.txt to include the adapter
$updatedFastLEDCMake = @'
cmake_minimum_required(VERSION 3.5)

# Gather all FastLED sources
file(GLOB_RECURSE FASTLED_SRCS 
    "src/*.cpp"
    "src/platforms/esp/32/*.cpp"
)

# Add our adapter
list(APPEND FASTLED_SRCS "led_strip_adapter.c")

idf_component_register(
    SRCS ${FASTLED_SRCS}
    INCLUDE_DIRS "src"
    REQUIRES arduino-esp32 esp_driver_rmt driver esp_lcd led_strip FastLED-ESP32S3_250224
)

# Add compiler definitions for ESP32-S3
target_compile_definitions(${COMPONENT_LIB} PRIVATE 
    FASTLED_ESP32=1
    FASTLED_ESP32_S3=1
    FASTLED_RMT_BUILTIN_DRIVER=1
)

project(FastLED)
'@

Set-Content -Path $fastledCMake -Value $updatedFastLEDCMake
Write-Host "Updated FastLED CMakeLists.txt to include adapter" -ForegroundColor Green

# 5. Create platform_defines.h in main directory if it doesn't exist
if (-not (Test-Path "main/platform_defines.h")) {
    Write-Host "`nStep 4: Creating platform_defines.h..." -ForegroundColor Yellow
    
    $platformDefines = @'
#ifndef PLATFORM_DEFINES_H
#define PLATFORM_DEFINES_H

// ESP32-S3 specific defines
#define FASTLED_ESP32 1
#define FASTLED_ESP32_S3 1
#define FASTLED_NO_AVR 1
#define FASTLED_DISABLE_INTERRUPTS 0
#define FASTLED_INTERRUPT_RETRY_COUNT 0
#define FASTLED_ALLOW_INTERRUPTS 0
#define FASTLED_FORCE_RMT 1
#define FASTLED_RMT_BUILTIN_DRIVER 1

// Make sure we're defining ESP32S3
#ifndef ESP32S3
#define ESP32S3 1
#endif

#endif // PLATFORM_DEFINES_H
'@

    Set-Content -Path "main/platform_defines.h" -Value $platformDefines
    Write-Host "platform_defines.h created" -ForegroundColor Green
} else {
    Write-Host "`nStep 4: platform_defines.h already exists, not overwriting" -ForegroundColor Yellow
}

# 6. Update main CMakeLists.txt to include the extension component
# Only modify if FastLED-ESP32S3_250224 is missing
$mainCMakePath = "main/CMakeLists.txt"
if (Test-Path $mainCMakePath) {
    Write-Host "`nStep 5: Checking main CMakeLists.txt for FastLED-ESP32S3_250224..." -ForegroundColor Yellow
    
    $mainCMakeContent = Get-Content $mainCMakePath -Raw
    if ($mainCMakeContent -notmatch "FastLED-ESP32S3_250224") {
        # Found main CMakeLists.txt but it doesn't include our extension, need to update
        Write-Host "Updating main CMakeLists.txt to include FastLED-ESP32S3_250224..." -ForegroundColor Green
        
        # Backup first
        Copy-Item $mainCMakePath "$mainCMakePath.bak" -Force
        
        # Update the REQUIRES line to include our extension
        $updatedContent = $mainCMakeContent -replace "(REQUIRES\s+[^)]*)", "`$1 FastLED-ESP32S3_250224"
        
        # Also make sure it includes led_strip
        if ($updatedContent -notmatch "led_strip") {
            $updatedContent = $updatedContent -replace "(REQUIRES\s+[^)]*)", "`$1 led_strip"
        }
        
        Set-Content -Path $mainCMakePath -Value $updatedContent
        Write-Host "Updated main CMakeLists.txt" -ForegroundColor Green
    } else {
        Write-Host "main CMakeLists.txt already includes FastLED-ESP32S3_250224" -ForegroundColor Green
    }
} else {
    Write-Host "`nStep 5: main/CMakeLists.txt not found, creating minimal one..." -ForegroundColor Yellow
    
    $minimalMainCMake = @'
idf_component_register(SRCS "main.cpp"
                      INCLUDE_DIRS "."
                      REQUIRES arduino-esp32 FastLED FastLED-ESP32S3_250224 led_strip)
'@
    
    Set-Content -Path $mainCMakePath -Value $minimalMainCMake
    Write-Host "Created minimal main CMakeLists.txt" -ForegroundColor Green
}

# 7. Clean build directory (optional)
Write-Host "`nStep 6: Clean build directory?" -ForegroundColor Yellow
$cleanBuild = Read-Host "Would you like to clean the build directory? (y/n)"
if ($cleanBuild -eq "y" -or $cleanBuild -eq "Y") {
    if (Test-Path "build") {
        Remove-Item -Path "build" -Recurse -Force
        Write-Host "Build directory cleaned" -ForegroundColor Green
    } else {
        Write-Host "No build directory found, nothing to clean" -ForegroundColor Yellow
    }
} else {
    Write-Host "Skipping build directory cleaning" -ForegroundColor Yellow
}

Write-Host "`n====== FastLED Update & Patch Complete! ======" -ForegroundColor Green
Write-Host "The FastLED library is now patched for ESP32-S3" -ForegroundColor Cyan
Write-Host "You can now build your project using:" -ForegroundColor Cyan
Write-Host "idf.py build" -ForegroundColor Yellow
Write-Host "`nRemember to run this script again if you update FastLED!" -ForegroundColor Cyan