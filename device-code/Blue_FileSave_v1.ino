#include <Adafruit_LittleFS.h> // Internal Library System
#include <InternalFileSystem.h> // Internal file system
#include <Adafruit_TinyUSB.h>   // Bluetooth and low energy cost function
#include <bluefruit.h>          // BLE
BLEUart bleuart;                // BLE connection to serial port
String incomingData = "";       // Buffer for incoming data
// #include <SPI.h>                // SPI for OLED (Commented out for OLED)
// #include <Wire.h>
// #include <Adafruit_GFX.h>
// #include <Adafruit_SSD1306.h>   // For the OLED (Commented out for OLED)
// #define SCREEN_WIDTH 128        // OLED display width, in pixels (Commented out for OLED)
// #define SCREEN_HEIGHT 64        // OLED display height, in pixels (Commented out for OLED)
// #define OLED_RESET 10           // Reset pin # (Commented out for OLED)
// #define SCREEN_ADDRESS 0x3D     // Address for 128x64 OLED (Commented out for OLED)

// Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET); (Commented out for OLED)
// bool oledAvailable = false;  // Flag to check if OLED is connected (Commented out for OLED)

void setup() {
  Serial.begin(115200);
  while (!Serial) delay(10); // Wait for serial to initialize

  Serial.println("Starting BLE setup...");

  // Try to initialize the OLED display (Commented out for OLED)
  /*
  if (display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    oledAvailable = true;  // OLED is available
    display.clearDisplay();
  } else {
    Serial.println(F("OLED not connected, skipping display setup."));
    oledAvailable = false;
  }
  */

  // Initialize the BLE module
  Bluefruit.begin();
  Bluefruit.setName("NODE");  // Name your BLE device
  Bluefruit.Periph.setConnectCallback(connect_callback);
  Bluefruit.Periph.setDisconnectCallback(disconnect_callback);
  bleuart.begin();

  // Make discoverable
  Bluefruit.Advertising.addFlags(BLE_GAP_ADV_FLAGS_LE_ONLY_GENERAL_DISC_MODE);
  Bluefruit.Advertising.addTxPower();   // Add TX power level to the advertising packet
  Bluefruit.Advertising.addName();     // Advertise the device name
  Bluefruit.Advertising.addService(bleuart);   // Advertise the BLE UART service

  // Set advertising interval (in units of 0.625 ms)
  Bluefruit.Advertising.setInterval(32, 244);  // 20ms to 152.5ms
  Bluefruit.Advertising.start(0);

  Serial.println("BLE setup completed, advertising started.");

  // Initialize File system
  if (!InternalFS.begin()) {
    Serial.println("Failed to mount internal flash file system!");
    return;
  }
}

// Function to display text on screen - pass in as char
void displayText(const char* text) {
  /*
  if (oledAvailable) {
    // Only try to update display if OLED is available
    display.clearDisplay();
    display.setTextSize(1);    // Normal 1:1 pixel scale
    display.setTextColor(SSD1306_WHITE);  // Draw white text
    display.setCursor(0, 0);   // Start at top-left corner
    display.println(text);     // Print Text
    display.display();         // Update Display
  } else {
  */
    // If OLED is not available, just print to Serial
    //Serial.println(text);
  // }
  //delay(2000); // Display for at least 2 seconds
}

// Save incoming data to a file
void saveToFile(String data) {
  // Remove the EOF marker
  data.replace("EOF", "");
  // Delete old file, if it exists
  if (InternalFS.exists("/received.txt")) {
    InternalFS.remove("/received.txt");
  }
  // Open file to write
  Adafruit_LittleFS_Namespace::File file = InternalFS.open("/received.txt", Adafruit_LittleFS_Namespace::FILE_O_WRITE);
  if (file) {
    file.print(data);  // Write the received data
    file.close();
    Serial.println("File written successfully.");
    Serial.println(data);
  } else {
    Serial.println("Failed to open file for writing.");
  }
}

void loop() {
  // Check if there is data available over BLE
  while (bleuart.available()) {
    char c = (char)bleuart.read();
    incomingData += c;

    // Check if we received a complete file
  if (incomingData.endsWith("EOF")) {  // If file ends with EOF
    Serial.println("Saving File");
    saveToFile(incomingData);
    
    incomingData = "";  // Reset the buffer after saving
    displayText("File received and saved");
  } else {
    displayText(incomingData.c_str());  // Show ongoing data
  }
  }

  
}

void connect_callback(uint16_t conn_handle) {
  Serial.println("Connected");
}

void disconnect_callback(uint16_t conn_handle, uint8_t reason) {
  Serial.println("Disconnected");
}
