##########################################
# FastLED ESP32-S3 Setup Script
# Run this script from your project root
# whenever you install or update FastLED
##########################################

Write-Host "====== FastLED ESP32-S3 Setup Script ======" -ForegroundColor Cyan

# Ensure we're running from the project root
if (-not (Test-Path "components" -PathType Container)) {
    Write-Host "ERROR: Please run this script from your project root directory" -ForegroundColor Red
    Write-Host "The 'components' directory was not found!" -ForegroundColor Red
    exit 1
}

# 1. Install Required Components
Write-Host "`nStep 1: Installing required components..." -ForegroundColor Yellow

# Check and install ESPAsyncWebServer
$asyncWebServerDir = "components/ESPAsyncWebServer"
$asyncTCPDir = "components/AsyncTCP"

if (-not (Test-Path $asyncWebServerDir)) {
    Write-Host "Installing ESPAsyncWebServer..." -ForegroundColor Green
    
    # First check if AsyncTCP is installed (it's a dependency)
    if (-not (Test-Path $asyncTCPDir)) {
        Write-Host "Installing AsyncTCP dependency..." -ForegroundColor Green
        Push-Location components
        git clone https://github.com/me-no-dev/AsyncTCP.git
        Pop-Location
    } else {
        Write-Host "AsyncTCP already installed" -ForegroundColor Green
    }
    
    # Now install ESPAsyncWebServer
    Push-Location components
    git clone https://github.com/me-no-dev/ESPAsyncWebServer.git
    Pop-Location
    
    Write-Host "ESPAsyncWebServer installed" -ForegroundColor Green
} else {
    Write-Host "ESPAsyncWebServer already installed" -ForegroundColor Green
}

# 2. Create or update FastLED-ESP32S3 extension component
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

# 3. Patch FastLED CMakeLists.txt to add esp_lcd dependency
Write-Host "`nStep 3: Patching FastLED CMakeLists.txt..." -ForegroundColor Yellow

$fastledDir = "components/FastLED"
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

# Replace with our fixed version
$newCMakeContent = @'
cmake_minimum_required(VERSION 3.5)

# Gather all FastLED sources
file(GLOB_RECURSE FASTLED_SRCS 
    "src/*.cpp"
    "src/platforms/esp/32/*.cpp"
)

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

Set-Content -Path $fastledCMake -Value $newCMakeContent
Write-Host "FastLED CMakeLists.txt updated successfully" -ForegroundColor Green

# 4. Create an additional led_strip_adapter.c directly in FastLED to ensure linking works
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

# 5. Create platform_defines.h in main directory
Write-Host "`nStep 4: Creating platform_defines.h..." -ForegroundColor Yellow

$mainDir = "main"
if (-not (Test-Path $mainDir)) {
    New-Item -Path $mainDir -ItemType Directory -Force | Out-Null
    Write-Host "Created main directory" -ForegroundColor Green
}

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

Set-Content -Path "$mainDir/platform_defines.h" -Value $platformDefines
Write-Host "platform_defines.h created" -ForegroundColor Green

# 6. Update main CMakeLists.txt
Write-Host "`nStep 5: Updating main CMakeLists.txt..." -ForegroundColor Yellow

$mainCMake = "$mainDir/CMakeLists.txt"
$mainCMakeContent = @'
idf_component_register(SRCS "main.cpp"
                      INCLUDE_DIRS "."
                      REQUIRES arduino-esp32 FastLED FastLED-ESP32S3_250224 ESPAsyncWebServer AsyncTCP led_strip)
'@

# Backup existing if it exists
if (Test-Path $mainCMake) {
    Copy-Item $mainCMake "$mainCMake.bak" -Force
    Write-Host "Backed up existing main CMakeLists.txt" -ForegroundColor Green
}

Set-Content -Path $mainCMake -Value $mainCMakeContent
Write-Host "main CMakeLists.txt updated" -ForegroundColor Green

# 7. Create a test main.cpp if it doesn't exist
$testMainContent = @'
#include "platform_defines.h"
#include <Arduino.h>
#include <FastLED.h>
#include <WiFi.h>
#include <ESPAsyncWebServer.h>

// Configuration
#define LED_PIN 48  // Onboard NeoPixel pin
#define NUM_LEDS 1  // Single NeoPixel
#define BRIGHTNESS 50  // Set brightness (0-255)

// WiFi credentials
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// LED data array
CRGB leds[NUM_LEDS];

// Web server
AsyncWebServer server(80);

// Handler for color setting
void handleColor(AsyncWebServerRequest *request) {
  if (request->hasParam("color")) {
    String color = request->getParam("color")->value();
    int r, g, b;
    sscanf(color.c_str(), "%d,%d,%d", &r, &g, &b);
    leds[0] = CRGB(r, g, b);
    FastLED.show();
    request->send(200, "text/plain", "Color updated");
  } else {
    request->send(400, "text/plain", "Missing color parameter");
  }
}

void setup() {
  // Initialize serial
  Serial.begin(115200);
  delay(1000);
  Serial.println("ESP32-S3 FastLED Test");

  // Initialize FastLED
  Serial.println("Initializing FastLED...");
  FastLED.addLeds<WS2812, LED_PIN, GRB>(leds, NUM_LEDS);
  FastLED.setBrightness(BRIGHTNESS);
  
  // Test pattern - red, green, blue
  Serial.println("Running test pattern");
  
  // Red
  leds[0] = CRGB::Red;
  FastLED.show();
  delay(500);
  
  // Green
  leds[0] = CRGB::Green;
  FastLED.show();
  delay(500);
  
  // Blue
  leds[0] = CRGB::Blue;
  FastLED.show();
  delay(500);
  
  // Off
  leds[0] = CRGB::Black;
  FastLED.show();
  
  Serial.println("Test complete");

  // Connect to WiFi if credentials provided
  if (strcmp(ssid, "YOUR_WIFI_SSID") != 0) {
    Serial.print("Connecting to WiFi...");
    WiFi.begin(ssid, password);
    
    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 20) {
      delay(500);
      Serial.print(".");
      attempts++;
    }
    
    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("\nConnected to WiFi");
      Serial.print("IP Address: ");
      Serial.println(WiFi.localIP());
      
      // Set up web server routes
      server.on("/setColor", HTTP_GET, handleColor);
      server.begin();
      Serial.println("Web server started");
    } else {
      Serial.println("\nFailed to connect to WiFi");
    }
  } else {
    Serial.println("WiFi credentials not set - skipping WiFi setup");
  }
}

void loop() {
  // Rainbow effect
  static uint8_t hue = 0;
  leds[0] = CHSV(hue++, 255, 255);
  FastLED.show();
  delay(20);
}

extern "C" void app_main(void) {
  initArduino();
  setup();
  while (true) {
    loop();
  }
}
'@

if (-not (Test-Path "$mainDir/main.cpp")) {
    Set-Content -Path "$mainDir/main.cpp" -Value $testMainContent
    Write-Host "Created test main.cpp" -ForegroundColor Green
} else {
    Write-Host "main.cpp already exists, not overwriting" -ForegroundColor Yellow
}

# 8. Create compile_flags.txt for IntelliSense
$compileFlags = @'
-DFASTLED_ESP32=1
-DFASTLED_ESP32_S3=1
-DFASTLED_NO_AVR=1
-DFASTLED_DISABLE_INTERRUPTS=0
-DFASTLED_INTERRUPT_RETRY_COUNT=0
-DFASTLED_ALLOW_INTERRUPTS=0
-DFASTLED_FORCE_RMT=1
-DESP32
-DESP32S3
'@

Set-Content -Path "compile_flags.txt" -Value $compileFlags
Write-Host "compile_flags.txt created for IntelliSense" -ForegroundColor Green

# 9. Clean build directory
Write-Host "`nStep 6: Cleaning build directory..." -ForegroundColor Yellow
if (Test-Path "build") {
    Remove-Item -Path "build" -Recurse -Force
    Write-Host "Build directory cleaned" -ForegroundColor Green
} else {
    Write-Host "No build directory found, skipping clean" -ForegroundColor Yellow
}

Write-Host "`n====== Setup Complete! ======" -ForegroundColor Green
Write-Host "The FastLED library is now configured for ESP32-S3" -ForegroundColor Cyan
Write-Host "You can now build your project using:" -ForegroundColor Cyan
Write-Host "idf.py build" -ForegroundColor Yellow
Write-Host "`nRemember to run this script again if you update FastLED!" -ForegroundColor Cyan