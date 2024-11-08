#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

String incomingData = "";  // Buffer for incoming data

class MyCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) {
    // Using String instead of std::string
    String rxValue = pCharacteristic->getValue().c_str(); // Convert to String using c_str()

    if (rxValue.length() > 0) {
      Serial.println(rxValue);  // Display the received data
      incomingData += rxValue;

      // Check if incomingData ends with EOF to simulate end of file
      if (incomingData.endsWith("EOF")) {
        Serial.println("Complete message received:");
        Serial.println(incomingData);

        // You can call your function here, like saveToFile(incomingData);
        
        // Clear the buffer after processing
        incomingData = "";
      }
    }
  }
};

void setup() {
  Serial.begin(115200);

  // Initialize BLE
  BLEDevice::init("ESP32_BLE");
  BLEServer* pServer = BLEDevice::createServer();
  BLEService* pService = pServer->createService(BLEUUID((uint16_t)0xFFE0));

  BLECharacteristic* pCharacteristic = pService->createCharacteristic(
                                         BLEUUID((uint16_t)0xFFE1),
                                         BLECharacteristic::PROPERTY_WRITE
                                       );

  pCharacteristic->setCallbacks(new MyCallbacks());
  pCharacteristic->addDescriptor(new BLE2902());

  pService->start();
  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->start();
  
  Serial.println("Waiting for client connection...");
}

void loop() {
  // Add any additional loop code here
}
