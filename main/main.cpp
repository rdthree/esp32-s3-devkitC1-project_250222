#include "platform_defines.h"
#include <Arduino.h>
#include <FastLED.h>
#include <WiFi.h>
#include <ESPAsyncWebServer.h>

// ====== CONFIGURE THIS ======
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
#define LED_PIN 48  // Onboard NeoPixel pin
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
    // Initialize Serial for debugging
    Serial.begin(115200);
    delay(1000);
    Serial.println("Starting ESP32-S3 NeoPixel Controller");

    // Initialize FastLED
    Serial.println("Initializing FastLED using RMT driver...");
    FastLED.addLeds<WS2812, LED_PIN, GRB>(leds, NUM_LEDS);
    FastLED.setBrightness(BRIGHTNESS);
    FastLED.clear();
    FastLED.show();
    
    // Test pattern - blink R, G, B
    Serial.println("Starting test pattern...");
    
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
    
    // Clear LEDs after test
    leds[0] = CRGB::Black;
    FastLED.show();
    
    Serial.println("LED test complete!");

    // Connect to WiFi if credentials are set
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
            Serial.print("IP address: ");
            Serial.println(WiFi.localIP());
            
            // Set up web server
            server.on("/setColor", HTTP_GET, handleColor);
            server.begin();
            Serial.println("HTTP server started");
        } else {
            Serial.println("\nFailed to connect to WiFi");
        }
    } else {
        Serial.println("WiFi credentials not set - skipping WiFi connection");
    }
}

// ====== MAIN LOOP ======
void loop() {
    // Rainbow effect on the LED
    static uint8_t hue = 0;
    leds[0] = CHSV(hue++, 255, 255);
    FastLED.show();
    delay(20);
}

extern "C" void app_main(void) {
    initArduino(); // Initialize Arduino environment
    setup();       // Call the Arduino setup function
    while (true) { // Call the loop function repeatedly
        loop();
    }
}