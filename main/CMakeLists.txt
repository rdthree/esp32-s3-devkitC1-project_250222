idf_component_register(SRCS "main.cpp"
                      INCLUDE_DIRS "."
                      REQUIRES arduino-esp32 FastLED FastLED-ESP32S3_250224 ESPAsyncWebServer AsyncTCP led_strip)
