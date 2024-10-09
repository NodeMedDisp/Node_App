#include <bluefruit.h>

BLEUart bleuart;  // Create a BLE UART object

void setup() {
  Serial.begin(115200);
  while (!Serial) delay(10);  // Wait for serial connection
  
  Serial.println("Starting BLE setup...");
  
  // Initialize BLE
  Bluefruit.begin();
  Bluefruit.setName("Xiao BLE");  // Set device name
  Bluefruit.Periph.setConnectCallback(connect_callback);
  Bluefruit.Periph.setDisconnectCallback(disconnect_callback);
  
  // Setup BLE UART service
  bleuart.begin();

  // Start advertising
  startAdv();
  
  Serial.println("BLE setup completed, advertising started.");
}

void loop() {
  // Check for incoming data from the app
  if (bleuart.available()) {
    // Read the incoming message and print it to the Serial Monitor
    while (bleuart.available()) {
      char receivedChar = bleuart.read();
      Serial.print(receivedChar);  // Print each received character to the Serial Monitor
    }
    Serial.println();  // Print a newline once the message is fully received
  }
}

void startAdv(void) {
  // Configure the advertising packet
  Bluefruit.Advertising.addFlags(BLE_GAP_ADV_FLAGS_LE_ONLY_GENERAL_DISC_MODE);
  Bluefruit.Advertising.addTxPower();  // Add TX power level to the advertising packet
  Bluefruit.Advertising.addName();     // Advertise the device name
  Bluefruit.Advertising.addService(bleuart);  // Advertise the BLE UART service

  // Set advertising interval (in units of 0.625 ms)
  Bluefruit.Advertising.setInterval(32, 244);  // 20ms to 152.5ms

  // Start advertising
  Bluefruit.Advertising.start(0);  // 0 = Advertising until explicitly stopped
}

void connect_callback(uint16_t conn_handle) {
  Serial.println("Connected");
}

void disconnect_callback(uint16_t conn_handle, uint8_t reason) {
  Serial.println("Disconnected");
}
