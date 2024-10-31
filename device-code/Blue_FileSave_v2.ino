#include <Adafruit_LittleFS.h>  // Internal Library System
#include <InternalFileSystem.h>  // Internal file system
#include <Adafruit_TinyUSB.h>    // Bluetooth and low energy cost function
#include <bluefruit.h>           // BLE
#include <Time.h>                // Time library by Michael Margolis

BLEUart bleuart;                 // BLE connection to serial port
String incomingData = "";        // Buffer for incoming data

// Variables for storing parsed data from file
time_t currentTime;       // Parsed current time from file
time_t reminderTime;      // Parsed medication reminder time

// Function prototypes
void startClock(String currentTimeString);
void parseMedicationTime(String timeString);

void setup() {
  Serial.begin(115200);
  while (!Serial) delay(10); // Wait for serial to initialize

  Serial.println("Starting BLE setup...");

  // Initialize the BLE module
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

  // Initialize File system
  if (!InternalFS.begin()) {
    Serial.println("Failed to mount internal flash file system!");
    return;
  }

  // Load the file to get times
  Adafruit_LittleFS_Namespace::File file = InternalFS.open("/received.txt", Adafruit_LittleFS_Namespace::FILE_O_READ);
  if (!file) {
    Serial.println("Failed to open received.txt");
    return;
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
  reminderTime = now() - (hour() * SECS_PER_HOUR + minute() * SECS_PER_MIN) + (hour * SECS_PER_HOUR + minute * SECS_PER_MIN);
  Serial.print("Medication Reminder Set for: ");
  Serial.print(hour);
  Serial.print(":");
  Serial.println(minute);
}

void loop() {
  // Update time and check if it's time for the reminder
  if (now() >= reminderTime && now() < reminderTime + SECS_PER_MIN) {  // If it's the reminder time within a minute
    Serial.println("Time to take your meds");
    delay(60000); // Wait 1 minute before checking again
  }

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
