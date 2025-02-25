Write-Host "=== Checking Environment Versions ===" -ForegroundColor Cyan

# Check ESP-IDF version
Write-Host "ESP-IDF Version:" -ForegroundColor Yellow
$idfVersionCmd = idf.py --version
if ($idfVersionCmd -match "v[\d\.]+") {
    Write-Host $Matches[0] -ForegroundColor Green
} else {
    Write-Host "Unknown - Cannot determine ESP-IDF version" -ForegroundColor Red
}

# Check FastLED version
Write-Host "`nFastLED Version:" -ForegroundColor Yellow
$fastledPath = "components\FastLED\src\FastLED.h"
if (Test-Path $fastledPath) {
    $fastledVersionLine = Get-Content $fastledPath | Select-String "FASTLED_VERSION"
    if ($fastledVersionLine) {
        Write-Host $fastledVersionLine -ForegroundColor Green
    } else {
        Write-Host "Found FastLED.h but couldn't determine version" -ForegroundColor Red
    }
} else {
    Write-Host "FastLED.h not found at $fastledPath" -ForegroundColor Red
}

# Check for ESP32-S3 support
Write-Host "`n=== FastLED Compatibility Check ===" -ForegroundColor Cyan
$clocklessFile = "components\FastLED\src\platforms\esp\32\clockless_esp32.h"
if (Test-Path $clocklessFile) {
    $s3Support = Get-Content $clocklessFile | Select-String "ESP32S3"
    if ($s3Support) {
        Write-Host "✓ ESP32-S3 support found in FastLED" -ForegroundColor Green
    } else {
        Write-Host "✗ ESP32-S3 support might be missing in this FastLED version" -ForegroundColor Red
        Write-Host "  Consider updating to the latest FastLED version from GitHub" -ForegroundColor Yellow
    }
} else {
    Write-Host "✗ clockless_esp32.h not found - FastLED might not be properly installed" -ForegroundColor Red
}