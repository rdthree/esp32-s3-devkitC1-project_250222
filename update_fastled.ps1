# PowerShell script to update FastLED while preserving the extension component
# Run this from your project root directory

Write-Host "Updating FastLED component..." -ForegroundColor Cyan

# Back up the extension component if it exists
if (Test-Path "components/FastLED-ESP32S3") {
    Write-Host "Backing up FastLED-ESP32S3 extension..." -ForegroundColor Yellow
    Copy-Item -Path "components/FastLED-ESP32S3" -Destination "components/FastLED-ESP32S3.bak" -Recurse -Force
}

# Remove the old FastLED
if (Test-Path "components/FastLED") {
    Write-Host "Removing old FastLED..." -ForegroundColor Yellow
    Remove-Item -Path "components/FastLED" -Recurse -Force
}

# Clone the latest FastLED
Write-Host "Cloning latest FastLED..." -ForegroundColor Yellow
Push-Location "components"
git clone https://github.com/FastLED/FastLED.git
Pop-Location

# # Clean the build directory
# Write-Host "Cleaning build directory..." -ForegroundColor Yellow
# if (Test-Path "build") {
#     Remove-Item -Path "build" -Recurse -Force
# }

# # Build the project
# Write-Host "Building project..." -ForegroundColor Green
# idf.py build

Write-Host "Done!" -ForegroundColor Cyan