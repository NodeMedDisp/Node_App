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
void readFile(String file_name);
void deleteFile(String file_name);

//Bluetooth callback class
class MyCallbacks : public BLECharacteristicCallbacks {
  // Handle receiving data
  void onWrite(BLECharacteristic* pCharacteristic) {
    // Each value that is received
    String rxValue = pCharacteristic->getValue().c_str(); // Convert to String using c_str()
    
    // If the value is good data, save it
    if (rxValue.length() > 0) {
      Serial.println(rxValue);  // Display the received data
      incomingData += rxValue;

      // Check if incomingData ends with EOF to simulate end of file
      if (incomingData.endsWith("EOF")) {
        Serial.println("Complete message received:");
        Serial.println(incomingData);
        
        // Save the data to received file
        saveToFile(incomingData,"/received.txt");

        // Read the file to parse the information
        readFile("/received.txt");
        
        // Clear the buffer after processing
        incomingData = "";
      }
    }
  }
  // Handle returning the data
  void onRead(BLECharacteristic *pCharacteristic) {
    const char *filename = "/log.txt";

    if (!SPIFFS.exists(filename)) {
      Serial.println("Send failed: No log file exists");
      return;
    }

    File file = SPIFFS.open(filename,"r");
    if (!file) {
      Serial.println("Send failed: Failed to open file");
      return;
    }

    // Read the file and send in chunks
    size_t maxChunkSize = 512;
    char buffer[maxChunkSize + 1];

    while (file.available()) {
      size_t bytesRead = file.readBytes(buffer, maxChunkSize);
      buffer[bytesRead] = '\0'; // Null-terminate the string

      // Send the chunks over bluetooth
      pCharacteristic->setValue((uint8_t *)buffer,bytesRead);
      pCharacteristic->notify();

      delay(50); // Give delay for processing
    }

    file.close();
    Serial.println("File sent successfully");
  }
};
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

// This is the setup, everything here is done only once - when the device is turned on
void setup() {
  Serial.begin(256000);
  while (!Serial) delay(10); // Wait for serial to initialize

  // Initialize Screen
  tft.begin();
  tft.fillScreen(ILI9341_BLACK);
  tft.setRotation(3);
  
  //Setup cursor and text on screen
  tft.setCursor(10, 400);
  tft.setTextColor(ILI9341_WHITE);
  tft.setTextSize(12);
  tft.println("NODE");
/*
  // Initialize File system
  if(!SPIFFS.begin(FORMAT_SPIFFS_IF_FAILED)){
      Serial.println("SPIFFS Mount Failed");
    } else {
      Serial.println("SPIFFS Mounted Successfully");
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
  //readFile("/received.txt");
  */
}

// Save incoming data to a file
void saveToFile(String data, String file_name) {
  data.replace("EOF", "");  // Remove the EOF marker

  // Delete old file, if it exists
  deleteFile(file_name);

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
      "\nMedication: fcb\nDose: 1\nFrequency: Once daily\nTimes: 11:36 AM\nDays: 1 to 5"
      "\nPrompt1: What have you accomplished in the past 24 hours?\nRequired Response: No\nOptions: No options\nDays: 1 to 5");
    file.close();
    Serial.println("File written successfully.");
  } else {
    Serial.println("Failed to create file for writing.");
  }
}

// Function to read the file
void readFile(String file_name){
  // Load the file to read times
  File file = SPIFFS.open(file_name, "r");

  // Check if the file opened
  if (!file) {
    Serial.println("Failed to open " + file_name);
    return;
  } else {
    Serial.println("Opened " + file_name);
  }

  String line;
  while (file.available()) {
    line = file.readStringUntil('\n');

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

void deleteFile(String file_name){
  // Delete the existing file
  if (SPIFFS.exists(file_name)) {
    // Attempt to remove the file
    if (SPIFFS.remove(file_name)) {
      Serial.println("File deleted successfully!");
    } else {
      Serial.println("Failed to delete the file.");
    }
  } else {
    Serial.println("File does not exist.");
  }
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

void printTime() {
  Serial.print("Current Time: ");
  Serial.print(hour());    // Print current hour
  Serial.print(":");
  Serial.print(minute());  // Print current minute
  Serial.print(":");
  Serial.println(second());  // Print current second
}

// Parse medication time and store as reminder time
void parseMedicationTime(String timeString) {
  int h, m;
  char period[3];
  sscanf(timeString.c_str(), "%d:%d %s", &h, &m, period);

  // Adjust for AM/PM format if necessary
  if (strcmp(period, "PM") == 0 && h < 12) h += 12;

  // Set reminder time to today at the parsed hour and minute
  reminderTime = now() + ((hour() - h)*60*60) + ((minute() - m) * 60);
  Serial.print("Medication Reminder Set for: ");
  Serial.print(h);
  Serial.print(":");
  Serial.println(m);
}

// This is the run stage, everything here keeps happening, forever.
void loop() {
  
  Serial.print("Now: ");
  printTime();
  Serial.println(reminderTime);
  // Update time and check if it's time for the reminder
  if (now() >= reminderTime && now() < reminderTime + 60) {  // If it's the reminder time within a minute
    tft.fillScreen(ILI9341_BLACK);
    tft.setTextSize(5);
    tft.println("Time to take your meds");
    tft.println("Press the button below to dispense");
    delay(60000); // Wait 60

    
  }
  delay(10000); // Wait 10 seconds before checking again
}
