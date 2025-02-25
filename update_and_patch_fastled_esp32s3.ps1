# FastLED ESP32-S3 Update & Patch Script
# Run this script from your project root to update and patch FastLED for ESP32-S3

# --- CONFIGURATION ---
$FASTLED_DIR = "components/FastLED"
$EXTENSION_DIR = "components/FastLED-ESP32S3_250224"

# --- FUNCTIONS ---
function EnsureDirectoryExists($path) {
    if (-not (Test-Path $path)) { New-Item -Path $path -ItemType Directory -Force | Out-Null }
}

function BackupFile($path) {
    if (Test-Path $path -and -not (Test-Path "$path.original")) {
        Copy-Item $path "$path.original"
    }
}

# --- MAIN SCRIPT ---
# Check if running from project root
if (-not (Test-Path "components")) {
    Write-Host "Error: Run script from project root (where components directory is located)" -ForegroundColor Red
    exit 1
}

# 1. Prompt to update FastLED
$updateFastLED = $false
if (Test-Path $FASTLED_DIR) {
    $updateChoice = Read-Host "Update FastLED to latest? (y/n)"
    $updateFastLED = ($updateChoice -eq "y" -or $updateChoice -eq "Y")
} else {
    Write-Host "FastLED not found, will install it" -ForegroundColor Yellow
    $updateFastLED = $true
}

# 2. Update FastLED if requested
if ($updateFastLED) {
    # Backup existing FastLED if present
    if (Test-Path $FASTLED_DIR) {
        $backupDir = "$FASTLED_DIR.bak"
        if (Test-Path $backupDir) { Remove-Item $backupDir -Recurse -Force }
        Write-Host "Backing up existing FastLED" -ForegroundColor Yellow
        Move-Item $FASTLED_DIR $backupDir
    }
    
    # Clone latest FastLED
    Write-Host "Installing latest FastLED..." -ForegroundColor Yellow
    Push-Location components
    git clone https://github.com/FastLED/FastLED.git
    $success = $?
    Pop-Location
    
    if (-not $success) {
        Write-Host "Error: Failed to clone FastLED" -ForegroundColor Red
        if (Test-Path "$FASTLED_DIR.bak") {
            Move-Item "$FASTLED_DIR.bak" $FASTLED_DIR
        }
        exit 1
    }
}

# 3. Create extension component
Write-Host "Creating extension component..." -ForegroundColor Yellow
EnsureDirectoryExists $EXTENSION_DIR

# 3.1 Create engine_events.cpp
$engineEvents = @'
#include "fl/engine_events.h"
namespace fl {
    EngineEvents* EngineEvents::getInstance() { static EngineEvents instance; return &instance; }
    void EngineEvents::_onBeginFrame() {}
    void EngineEvents::_onEndShowLeds() {}
    void EngineEvents::_onEndFrame() {}
    void EngineEvents::_onStripAdded(CLEDController* strip, unsigned long leds) {}
}
'@
Set-Content -Path "$EXTENSION_DIR/engine_events.cpp" -Value $engineEvents

# 3.2 Create led_strip_adapter.cpp
$ledStripAdapter = @'
#include "led_strip.h"
extern "C" {
    esp_err_t led_strip_refresh_async(led_strip_handle_t strip) {
        return strip ? led_strip_refresh(strip) : ESP_ERR_INVALID_ARG;
    }
    esp_err_t led_strip_refresh_wait_done(led_strip_handle_t strip) {
        return strip ? ESP_OK : ESP_ERR_INVALID_ARG;
    }
}
'@
Set-Content -Path "$EXTENSION_DIR/led_strip_adapter.cpp" -Value $ledStripAdapter

# 3.3 Create extension CMakeLists.txt
$extensionCMake = @'
cmake_minimum_required(VERSION 3.5)
idf_component_register(
    SRCS "engine_events.cpp" "led_strip_adapter.cpp" "FastLED-ESP32S3_250224.c"
    INCLUDE_DIRS "."
    REQUIRES FastLED led_strip
)
target_compile_definitions(${COMPONENT_LIB} PUBLIC 
    FASTLED_ESP32=1 FASTLED_ESP32_S3=1 FASTLED_FORCE_RMT=1 FASTLED_RMT_BUILTIN_DRIVER=1
)
'@
Set-Content -Path "$EXTENSION_DIR/CMakeLists.txt" -Value $extensionCMake

# 3.4 Create stub C file
$stubC = @'
#include <stdio.h>
void fastled_esp32s3_support_init(void) {} // Empty implementation
'@
Set-Content -Path "$EXTENSION_DIR/FastLED-ESP32S3_250224.c" -Value $stubC

# 4. Patch FastLED
Write-Host "Patching FastLED..." -ForegroundColor Yellow

# 4.1 Create adapter file in FastLED
$fastLEDAdapter = @'
#include "led_strip.h"
esp_err_t led_strip_refresh_async(led_strip_handle_t strip) {
    return strip ? led_strip_refresh(strip) : ESP_ERR_INVALID_ARG;
}
esp_err_t led_strip_refresh_wait_done(led_strip_handle_t strip) {
    return strip ? ESP_OK : ESP_ERR_INVALID_ARG;
}
'@
Set-Content -Path "$FASTLED_DIR/led_strip_adapter.c" -Value $fastLEDAdapter

# 4.2 Update FastLED CMakeLists.txt
BackupFile "$FASTLED_DIR/CMakeLists.txt"
$fastledCMake = @'
cmake_minimum_required(VERSION 3.5)
file(GLOB_RECURSE FASTLED_SRCS "src/*.cpp" "src/platforms/esp/32/*.cpp")
list(APPEND FASTLED_SRCS "led_strip_adapter.c")
idf_component_register(
    SRCS ${FASTLED_SRCS}
    INCLUDE_DIRS "src"
    REQUIRES arduino-esp32 esp_driver_rmt driver esp_lcd led_strip FastLED-ESP32S3_250224
)
target_compile_definitions(${COMPONENT_LIB} PRIVATE 
    FASTLED_ESP32=1 FASTLED_ESP32_S3=1 FASTLED_RMT_BUILTIN_DRIVER=1
)
project(FastLED)
'@
Set-Content -Path "$FASTLED_DIR/CMakeLists.txt" -Value $fastledCMake

# 5. Create platform_defines.h if needed
if (-not (Test-Path "main/platform_defines.h")) {
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
#define ESP32S3 1
#endif // PLATFORM_DEFINES_H
'@
    Set-Content -Path "main/platform_defines.h" -Value $platformDefines
}

# 6. Update main CMakeLists.txt to include extension
$mainCMakePath = "main/CMakeLists.txt"
if (Test-Path $mainCMakePath) {
    $mainCMakeContent = Get-Content $mainCMakePath -Raw
    if ($mainCMakeContent -notmatch "FastLED-ESP32S3_250224") {
        BackupFile $mainCMakePath
        $updatedContent = $mainCMakeContent -replace "(REQUIRES\s+[^)]*)", "`$1 FastLED-ESP32S3_250224 led_strip"
        Set-Content -Path $mainCMakePath -Value $updatedContent
    }
}

# 7. Clean build directory
if (Test-Path "build") {
    $cleanBuild = Read-Host "Clean build directory? (y/n)"
    if ($cleanBuild -eq "y") {
        Remove-Item -Path "build" -Recurse -Force
    }
}

Write-Host "✓ FastLED patched for ESP32-S3!" -ForegroundColor Green
Write-Host "Run 'idf.py build' to build your project" -ForegroundColor Cyan