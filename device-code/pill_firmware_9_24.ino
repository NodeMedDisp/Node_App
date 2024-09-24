#include <Adafruit_LittleFS.h> // Internal Library System
#include <InternalFileSystem.h> //Internal file system

#include <SPI.h> //SPI for OLED
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h> //For the OLED

#define SCREEN_WIDTH 128 // OLED display width, in pixels
#define SCREEN_HEIGHT 64 // OLED display height, in pixels

#define OLED_RESET     -1 // Reset pin #
#define SCREEN_ADDRESS 0x3D ///< See datasheet for Address; 0x3D for 128x64, 0x3C for 128x32
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

void setup() {
  Serial.begin(9600);
  while (!Serial); // Wait for serial to initialize

  // Power Display
  if(!display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    Serial.println(F("SSD1306 allocation failed"));
    for(;;); // Loop forever if screen fails to boot
  }

  // Initialize File system
  if (!InternalFS.begin()) {
    Serial.println("Failed to mount internal flash file system!");
    return;
  }

  // Delete Test File
  if (InternalFS.remove("/test.txt")) {
    Serial.println("File deleted successfully.");
  } else {
    Serial.println("Failed to delete file.");
  }

  // Open/Create test file
  Adafruit_LittleFS_Namespace::File file = InternalFS.open("/test.txt", Adafruit_LittleFS_Namespace::FILE_O_WRITE);
  if (file) {
    file.println("Hello World!"); // Write to test file
    file.close();
    Serial.println("File written successfully.");
  } else {
    Serial.println("Failed to open file for writing.");
  }

  // Read file
  Adafruit_LittleFS_Namespace::File file_r = InternalFS.open("/test.txt", Adafruit_LittleFS_Namespace::FILE_O_READ);
  if (file_r) {
    Serial.println("Reading from file:");
    String fileContent = "";

    while (file_r.available()) {
      char c = file_r.read();
      Serial.print(c);  // Print each character to Serial
      fileContent += c; // Save each character to string
    }
    file_r.close();

    displayText(fileContent.c_str());

  } else {
    Serial.println("Failed to open file for reading.");
  } 
}

// Function to display text on screen - pass in as char
void displayText(const char* text){
  // Clear the buffer
  display.clearDisplay();

  display.setTextSize(1); // Normal 1:1 pixel scale
  display.setTextColor(SSD1306_WHITE); // Draw white text
  display.setCursor(0,0); // Start at top-left corner
  display.println(text); // Print Text

  display.display(); // Update Display
  delay(2000); // Display for at least 2 seconds
}

void loop() {
  // put your main code here, to run repeatedly:
}
