#define FASTLED_DISABLE_RGBW 1
#define FASTLED_ESP32_S3 1     // Add this to specify ESP32-S3
#include <Arduino.h>
#include <FastLED.h>
#include <WiFi.h>
#include <ESPAsyncWebServer.h>

// ====== CONFIGURE THIS ======
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
#define LED_PIN 48  // Onboard NeoPixel pin (verify this is correct for your specific board)
#define NUM_LEDS 1  // Single NeoPixel
#define BRIGHTNESS 50  // Set initial brightness (0-255)

// ====== GLOBALS ======
CRGB leds[NUM_LEDS];
AsyncWebServer server(80);

// ====== FUNCTION TO HANDLE COLOR CHANGES ======
void handleColor(AsyncWebServerRequest *request) {
    if (request->hasParam("color")) {
        String color = request->getParam("color")->value();
        int r, g, b;
        sscanf(color.c_str(), "%d,%d,%d", &r, &g, &b);
        leds[0] = CRGB(r, g, b);
        FastLED.show();
        request->send(200, "text/plain", "Color updated");
    } else {
        request->send(400, "text/plain", "Missing color param");
    }
}

// ====== SETUP ======
void setup() {
    initArduino();  // Required when using Arduino inside ESP-IDF
    
    // Initialize Serial for debugging
    Serial.begin(115200);
    Serial.println("Starting ESP32-S3 NeoPixel Controller");

    // Initialize FastLED with extra debug info
    Serial.println("Initializing FastLED...");
    FastLED.addLeds<WS2812, LED_PIN, GRB>(leds, NUM_LEDS);
    FastLED.setBrightness(BRIGHTNESS);
    FastLED.clear();
    
    // Test pattern - blink red then green then blue
    leds[0] = CRGB::Red;
    FastLED.show();
    delay(500);
    leds[0] = CRGB::Green;
    FastLED.show();
    delay(500);
    leds[0] = CRGB::Blue;
    FastLED.show();
    delay(500);
    
    // Clear LEDs after test
    FastLED.clear();
    FastLED.show();
    Serial.println("FastLED initialized successfully");

    // Connect to WiFi
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
        Serial.print("IP address: ");
        Serial.println(WiFi.localIP());
        
        // Set up web server
        server.on("/setColor", HTTP_GET, handleColor);
        server.begin();
        Serial.println("HTTP server started");
    } else {
        Serial.println("\nFailed to connect to WiFi");
    }
}

// ====== MAIN LOOP (LIGHT SLEEP) ======
void loop() {
    // Keep LED running, disable sleep for debugging
    delay(5000);
    
    /* Uncomment for light sleep mode once everything is working
    Serial.println("Entering light sleep...");
    esp_sleep_enable_timer_wakeup(5000000);  // Wake up in 5 sec
    esp_light_sleep_start();  // Enter low-power mode
    Serial.println("Waking up...");
    */
}

extern "C" void app_main(void) {
    initArduino(); // Initialize Arduino environment
    setup();       // Call the Arduino setup function
    while (true) { // Call the loop function repeatedly
        loop();
    }
}