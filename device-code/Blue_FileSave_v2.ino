// NODE Code Last Updated: 11/1/24
#include <Arduino.h>
#include <Adafruit_LittleFS.h>  // Internal Library System
#include <InternalFileSystem.h>  // Internal file system
#include <Adafruit_TinyUSB.h>    // Bluetooth and low energy cost function
#include <bluefruit.h>           // BLE
#include <TimeLib.h>                // Time library by Michael Margolis

BLEUart bleuart;                 // BLE connection to serial port
String incomingData = "";        // Buffer for incoming data

InternalFileSystem fs; // Initialize file system class

// Variables for storing parsed data from file
time_t currentTime;       // Parsed current time from file
time_t reminderTime;      // Parsed medication reminder time

// Function prototypes
void startClock(String currentTimeString);
void parseMedicationTime(String timeString);

// This is the setup, everything here is done only once - when the device is turned on
void setup() {
  Serial.begin(115200);
  while (!Serial) delay(10); // Wait for serial to initialize

  // Initialize File system
  if (!fs.begin()) {
    Serial.println("Failed to mount internal flash file system");
    return;
  } else {
    Serial.println("Filesystem mounted successfully");
  }

  // Delete any existing file
  if (fs.exists("/received.txt")) {
    // Attempt to remove the file
    if (fs.remove("/received.txt")) {
      Serial.println("File deleted successfully!");
    } else {
      Serial.println("Failed to delete the file.");
    }
  } else {
    Serial.println("File does not exist.");
  }
  /* Commented out to test without bluetooth
  // Initialize the BLE module
  Serial.println("Starting BLE setup...");
  Bluefruit.begin();
  Bluefruit.setName("NODE");  // Name your BLE device
  Bluefruit.Periph.setConnectCallback(connect_callback);
  Bluefruit.Periph.setDisconnectCallback(disconnect_callback);
  bleuart.begin();

  // Make discoverable
  Bluefruit.Advertising.addFlags(BLE_GAP_ADV_FLAGS_LE_ONLY_GENERAL_DISC_MODE);
  Bluefruit.Advertising.addTxPower();
  Bluefruit.Advertising.addName();
  Bluefruit.Advertising.addService(bleuart);

  // Set advertising interval
  Bluefruit.Advertising.setInterval(32, 244);  // 20ms to 152.5ms
  Bluefruit.Advertising.start(0);
  Serial.println("BLE setup completed, advertising started.");
  

  // Handle incoming data over BLE
  while (bleuart.available()) {
    char c = (char)bleuart.read();
    incomingData += c;

    // Check if we received a complete file
    if (incomingData.endsWith("EOF")) {
      Serial.println("Saving File");
      saveToFile(incomingData);
      incomingData = "";  // Reset the buffer after saving
    }
  }
  */
  // Create a file for testing without bluetooth - Comment out if testing bluetooth
  createTestFile();

  // Read the File
  readFile();
  
}

// Create a file for testing without bluetooth
void createTestFile(){
  Adafruit_LittleFS_Namespace::File file = fs.open("/received.txt", Adafruit_LittleFS_Namespace::FILE_O_WRITE);
  // Write to file if it was created
  if (file) {
    file.println("\nCurrent Time: 2024-10-31 10:56:24"
      "\nMedication: methadone\nDose: 1\nFrequency: Once daily\nTimes: 8:42 AM\nDays: 1 to 15"
      "\nPrompt1: What have you accomplished in the past 24 hours?\nRequired Response: No\nOptions: No options\nDays: 1 to 14"
      "\nPrompt2: Have you taken non-prescribed opioids in the past 24 hours?\nRequired Response: Yes\nOptions: yes no\nDays: 1 to 14");
    file.close();
    Serial.println("File written successfully.");
  } else {
    Serial.println("Failed to create file for writing.");
  }
}

// Function to read the file
void readFile(){
  // Load the file to read times
  Adafruit_LittleFS_Namespace::File file = fs.open("/received.txt", Adafruit_LittleFS_Namespace::FILE_O_READ);

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

// Save incoming data to a file
void saveToFile(String data) {
  data.replace("EOF", "");  // Remove the EOF marker

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
  } else {
    Serial.println("Failed to open file for writing.");
  }
}

// Connection callback
void connect_callback(uint16_t conn_handle) {
  Serial.println("Connected");
}

// Disconnection callback
void disconnect_callback(uint16_t conn_handle, uint8_t reason) {
  Serial.println("Disconnected");
}

// This is the run stage, everything here keeps happening, forever.
void loop() {

  // Update time and check if it's time for the reminder
  if (now() >= reminderTime && now() < reminderTime + SECS_PER_MIN) {  // If it's the reminder time within a minute
    Serial.println("Time to take your meds");
    delay(10000); // Wait 10 seconds before checking again
  }
}
