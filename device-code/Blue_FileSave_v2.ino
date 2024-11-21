// NODE Code Last Updated: 11/20/24
#include <Arduino.h>
#include <FS.h>
#include <SPIFFS.h>  // Internal Library System
#include <BLEDevice.h>           // BLE
#include <BLEServer.h>            // BLE Server
#include <BLEUtils.h>
#include <BLE2902.h>
#include <TimeLib.h>                // Time library by Michael Margolis
#include <Adafruit_GFX.h>           // For Screen
#include <Adafruit_ILI9341.h>       // For Screen

#define FORMAT_SPIFFS_IF_FAILED true
/*
BLEServer *pServer = NULL;
BLECharacteristic *pCharacteristic = NULL;
bool deviceConnected = false;

// UUIDs for BLE service and characteristic
#define SERVICE_UUID        "12345678-1234-5678-1234-56789abcdef0"  // Custom Service UUID
#define CHARACTERISTIC_UUID "12345678-1234-5678-1234-56789abcdef1"  // Custom Characteristic UUID
*/
String incomingData = "";        // Buffer for incoming data

// Variables for storing parsed data from file
time_t currentTime;       // Parsed current time from file
time_t reminderTime;      // Parsed medication reminder time

// Function prototypes
void startClock(String currentTimeString);
void parseMedicationTime(String timeString);

// Screen Initialization
#define TFT_CS     5
#define TFT_RST    17
#define TFT_DC     16
Adafruit_ILI9341 tft = Adafruit_ILI9341(TFT_CS, TFT_DC, TFT_RST);

//Function declaration
void saveToFile(String data, String file_name);
void createTestFile();
void readFile();

//Bluetooth callback class
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
        
        saveToFile(incomingData,"/received.txt");
        
        // Clear the buffer after processing
        incomingData = "";
      }
    }
  }
};

// This is the setup, everything here is done only once - when the device is turned on
void setup() {
  Serial.begin(115200);
  while (!Serial) delay(10); // Wait for serial to initialize

  // Initialize Screen
  tft.begin();
  tft.fillScreen(ILI9341_BLACK);
  tft.setRotation(3);
  
  //Setup cursor and text on screen
  tft.setCursor(10, 10);
  tft.setTextColor(ILI9341_WHITE);
  tft.setTextSize(2);

  // Initialize File system

  if(!SPIFFS.begin(FORMAT_SPIFFS_IF_FAILED)){
        Serial.println("SPIFFS Mount Failed");
        return;
    }

  // Delete any existing file
  if (SPIFFS.exists("/received.txt")) {
    // Attempt to remove the file
    if (SPIFFS.remove("/received.txt")) {
      Serial.println("File deleted successfully!");
    } else {
      Serial.println("Failed to delete the file.");
    }
  } else {
    Serial.println("File does not exist.");
  }

  // Initialize BLE
  BLEDevice::init("NODE");
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

  // Create a file for testing without bluetooth - Comment out if testing bluetooth
  //createTestFile();

  // Read the File
  readFile();
  
}

// Save incoming data to a file
void saveToFile(String data, String file_name) {
  data.replace("EOF", "");  // Remove the EOF marker

  // Delete old file, if it exists
  if (SPIFFS.exists(file_name)) {
    SPIFFS.remove(file_name);
  }

  // Open file to write
  File file = SPIFFS.open(file_name, "w");
  if (file) {
    file.print(data);  // Write the received data
    file.close();
    Serial.println("File written successfully.");
  } else {
    Serial.println("Failed to open file for writing.");
  }
}

// Create a file for testing without bluetooth
void createTestFile(){
  File file = SPIFFS.open("/received.txt", "w");
  // Write to file if it was created
  if (file) {
    file.println("Current Time: 2024-11-05 11:34:27"
      "\nMedication: fcb\nDose: 1\nFrequency: Once daily\nTimes: 11:34 AM\nDays: 1 to 5"
      "\nPrompt1: What have you accomplished in the past 24 hours?\nRequired Response: No\nOptions: No options\nDays: 1 to 5");
    file.close();
    Serial.println("File written successfully.");
  } else {
    Serial.println("Failed to create file for writing.");
  }
}

// Function to read the file
void readFile(){
  // Load the file to read times
  File file = SPIFFS.open("/received.txt", "r");

  // Check if the file opened
  if (!file) {
    Serial.println("Failed to open received.txt");
    return;
  } else {
    Serial.println("Opened received.txt");
  }

  String line;
  while (file.available()) {
    line = file.readStringUntil('\n');
    tft.println(line);

    // Look for the current time and medication time in the file and parse
    if (line.startsWith("Current Time: ")) {
      String timeString = line.substring(14);  // Extract time
      startClock(timeString);                  // Set internal clock to this time
    } else if (line.startsWith("Times: ")) {
      String timeString = line.substring(7);   // Extract medication time
      parseMedicationTime(timeString);         // Set reminder time
    } else if (line.startsWith("Prompt1: ")){
      String prompt1 = line.substring(9);      // Extract Prompt 1
      Serial.println(prompt1);                 // Print to Serial
    } else if (line.startsWith("Prompt2: ")){
      String prompt2 = line.substring(9);      // Extract Prompt 2
      Serial.println(prompt2);                 // Print to Serial
    }
  }
  file.close();
}

// Function to initialize the internal clock with the current time from file
void startClock(String currentTimeString) {
  int year, month, day, hour, minute, second;
  sscanf(currentTimeString.c_str(), "%d-%d-%d %d:%d:%d", &year, &month, &day, &hour, &minute, &second);
  setTime(hour, minute, second, day, month, year);  // Initialize internal clock
  currentTime = now();  // Store current time as reference
  Serial.print("Current Time Set: ");
  Serial.println(currentTimeString);
}

// Parse medication time and store as reminder time
void parseMedicationTime(String timeString) {
  int hour, minute;
  char period[3];
  sscanf(timeString.c_str(), "%d:%d %s", &hour, &minute, period);

  // Adjust for AM/PM format if necessary
  if (strcmp(period, "PM") == 0 && hour < 12) hour += 12;
  if (strcmp(period, "AM") == 0 && hour == 12) hour = 0;

  // Set reminder time to today at the parsed hour and minute
  reminderTime = now() - (hour * SECS_PER_HOUR + minute * SECS_PER_MIN) + (hour * SECS_PER_HOUR + minute * SECS_PER_MIN);
  Serial.print("Medication Reminder Set for: ");
  Serial.print(hour);
  Serial.print(":");
  Serial.println(minute);
}

/*
// Callbacks for connection and disconnection events
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("Device connected");
  }

  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("Device disconnected");
    // Start advertising again after disconnect
    pServer->getAdvertising()->start();
  }
};
*/

// This is the run stage, everything here keeps happening, forever.
void loop() {

  // Update time and check if it's time for the reminder
  if (now() >= reminderTime && now() < reminderTime + SECS_PER_MIN) {  // If it's the reminder time within a minute
    Serial.println("Time to take your meds");
    delay(10000); // Wait 10 seconds before checking again
  }
}

/*
#include <BluetoothSerial.h>
 
#if !defined(CONFIG_BT_ENABLED) || !defined(CONFIG_BLUEDROID_ENABLED)
#error Bluetooth is not enabled! Please run `make menuconfig` to and enable it
#endif
 
#if !defined(CONFIG_BT_SPP_ENABLED)
#error Serial Bluetooth not available or not enabled. It is only available for the ESP32 chip.
#endif
 
BluetoothSerial SerialBT;
 
#define BT_DISCOVER_TIME  10000
static bool btScanSync = true;
 
void setup() {
  Serial.begin(115200);
  SerialBT.begin("ESP32test"); //Bluetooth device name
  Serial.println("The device started, now you can pair it with bluetooth!");
  if (btScanSync) {
    Serial.println("Starting discover...");
    BTScanResults *pResults = SerialBT.discover(BT_DISCOVER_TIME);
    if (pResults)
      pResults->dump(&Serial);
    else
      Serial.println("Error on BT Scan, no result!");
  }
}
 
void loop() {
  delay(100);
}
*/
