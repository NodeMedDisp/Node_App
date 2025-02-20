#include <Adafruit_GFX.h>
#include <Adafruit_ILI9341.h>
#include <SPI.h>

// Pin definitions
#define TFT_CS 9
#define TFT_DC 7
#define TFT_RST 6
#define TFT_MOSI 10
#define TFT_SCK 8

Adafruit_ILI9341 tft = Adafruit_ILI9341(TFT_CS, TFT_DC, TFT_RST);

void setup() {
  Serial.begin(115200);
  tft.begin();
  tft.fillScreen(ILI9341_BLUE); // Test screen by filling it with blue
}

void loop() {
  // Example of drawing text
  tft.setCursor(10, 10);
  tft.setTextColor(ILI9341_WHITE);
  tft.setTextSize(2);
  tft.println("Hello World!");
  delay(2000);
}
