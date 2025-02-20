// NODE Code Last Updated: 11/22/24
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
#include <vector>                     // For Prompts and Options
#include <sstream> // For parsing options (if not Arduino, but similar logic applies)

#define FORMAT_SPIFFS_IF_FAILED true

String incomingData = "";        // Buffer for incoming data
BLECharacteristic *pCharacteristic;
bool deviceConnected = false;
String prompt1;

// Variables for storing parsed data from file
time_t currentTime;       // Parsed current time from file
time_t reminderTime;      // Parsed medication reminder time
std::vector<String> prompts;  // Dynamic array to store all prompts
std::vector<String> options;  // Dynamic array to store all prompts

// Screen Initialization
#define TFT_CS     5
#define TFT_RST    17
#define TFT_DC     16
Adafruit_ILI9341 tft = Adafruit_ILI9341(TFT_CS, TFT_DC, TFT_RST);
int screen_h = 240;
int screen_w = 320;
int connection_bar = 13;

//Button Initialization
#define BUTTON_ENTER 15
#define BUTTON_NEXT 13
#define BUTTON_BACK 2


//Function declaration
void saveToFile(String data, String file_name);
void createTestFile();
void readFile(String file_name);
void deleteFile(String file_name);
void startClock(String currentTimeString);
void parseMedicationTime(String timeString);

//Bluetooth callback class
class MyCallbacks : public BLECharacteristicCallbacks {
  // Handle receiving data
  //3rd
  void onWrite(BLECharacteristic* pCharacteristic) {
    // Each value that is received
    String rxValue = pCharacteristic->getValue().c_str(); // Convert to String using c_str()
    
    // If the value is good data, save it
    if (rxValue.length() > 0) {
      Serial.println(rxValue);  // Display the received data
      incomingData += rxValue;

      // Check if incomingData ends with EOF to simulate end of file
      if (incomingData.indexOf("EOF") != -1) {
        Serial.println("Complete message received:");
        Serial.println(incomingData);
        
        // Save the data to received file
        saveToFile(incomingData,"/received.txt");
        deleteFile ("/log.txt");

        //createTestFile();

        // Read the file to parse the information
        readFile("/received.txt");
        
        // Clear the buffer after processing
        incomingData = "";
      }
    }
  }

  // Handle returning the data
  public:
    void sendFile(BLECharacteristic *pCharacteristic, const char *filename) {
      if (!SPIFFS.exists(filename)) {
        Serial.println("Send failed: No log file exists");
        return;
      }

      File file = SPIFFS.open(filename, "r");
      if (!file) {
        Serial.println("Send failed: Failed to open file");
        return;
      }

      size_t maxChunkSize = 512;
      char buffer[maxChunkSize + 1];

      Serial.println("Sending file contents:");

      while (file.available()) {
        size_t bytesRead = file.readBytes(buffer, maxChunkSize);
        buffer[bytesRead] = '\0'; //Null-terminate the chunk

        // Print the chunk to the Serial Monitor
        Serial.println(buffer);


        pCharacteristic->setValue((uint8_t *)buffer, bytesRead);
        pCharacteristic->notify();

        delay(50);
      }

      file.close();
      Serial.println("File sent successfully");
    }
};

// Callbacks for connection and disconnection events
class MyServerCallbacks : public BLEServerCallbacks {
  //2nd step
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    tft.fillRect(0,0,screen_w,connection_bar,ILI9341_DARKGREY);
    tft.setCursor(10, 3);
    tft.setTextSize(1);
    tft.println("BLE: Connected");
    Serial.println("Device connected");
  }

  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("Device disconnected");
    tft.fillRect(0,0,screen_w,connection_bar,ILI9341_DARKGREY);
    tft.setCursor(10, 3);
    tft.setTextSize(1);
    tft.println("BLE: Disconnected");
    // Start advertising again after disconnect
    pServer->getAdvertising()->start();
  }
};

// Create a class object to be able to access the functions
MyCallbacks myCallbacks;

//First
// This is the setup, everything here is done only once - when the device is turned on
void setup() {
  Serial.begin(115200);
  while (!Serial) delay(10); // Wait for serial to initialize

  // Initialize Screen
  tft.begin();
  tft.fillScreen(ILI9341_BLACK);
  tft.setRotation(1);
  
  //Setup cursor and text on screen
  tft.setCursor(25, 75);
  tft.setTextColor(ILI9341_WHITE);
  tft.setTextSize(12);
  tft.println("NODE");
  delay(3000);

  //Initialize Buttons
  pinMode(BUTTON_ENTER, INPUT_PULLUP); // Set up the middle button as an input with pull-up
  pinMode(BUTTON_NEXT, INPUT_PULLUP); // Set up the right button as an input with pull-up
  pinMode(BUTTON_BACK, INPUT_PULLUP); // Set up the left button as an input with pull-up

  // Initialize File system
  if(!SPIFFS.begin(FORMAT_SPIFFS_IF_FAILED)){
      Serial.println("SPIFFS Mount Failed");
    } else {
      Serial.println("SPIFFS Mounted Successfully");
    }
  
  // Initialize BLE
  BLEDevice::init("NODE");
  BLEServer *pServer = BLEDevice::createServer(); // Create BLE server
  pServer->setCallbacks(new MyServerCallbacks()); // Attach the server callbacks

  BLEService *pService = pServer->createService(BLEUUID((uint16_t)0xFFE0)); // Create BLE service with FFE0 ID

  pCharacteristic = pService->createCharacteristic(
    BLEUUID((uint16_t)0xFFE1),
    BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_NOTIFY); // Create pcharacteristic

  pCharacteristic->setCallbacks(&myCallbacks); // Setup call backs for p characteristic
  pCharacteristic->addDescriptor(new BLE2902());

  pService->start();
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->start();
  
  Serial.println("Waiting for client connection..."); //Once connected, go to onConnect
  
  //Create a file for testing without bluetooth - Comment out if testing bluetooth
  //createTestFile();
  //readFile("/received.txt");
  
}

String getFormattedDateTime() {
  char buffer[20];
  snprintf(buffer, sizeof(buffer), "%04d-%02d-%02d %02d:%02d:%02d", year(), month(), day(), hour(), minute(), second());
  return String(buffer);
}

//4th
// Save incoming data to a file
void saveToFile(String data, String file_name) {
  data.replace("EOF", "");  // Remove the EOF marker

  // Delete old file, if it exists
  deleteFile(file_name);                 //!!! If the user does not connect to the device when they are dosing we do not want it to delete the file

  // Open file to write
  File file = SPIFFS.open(file_name, "w");
  if (file) {
    String dateTime = getFormattedDateTime();
     file.println("Date: " + dateTime); // Add date and time
    file.print(data);  // Write the received data
    file.close();
    Serial.println("File written successfully with date and time.");
  } else {
    Serial.println("Failed to open file for writing.");
  }
}

//8th
// Save incoming data to a file
void saveData(String data, String file_name) {
  data.replace("EOF", "");  // Remove the EOF marker

  // Delete old file, if it exists
  //deleteFile(file_name);                 //!!! If the user does not connect to the device when they are dosing we do not want it to delete the file

  // Open file to write
  File file = SPIFFS.open(file_name, "a"); //This will append the data because it is 'a' instead of 'w'
  if (file) {
    // Check if the data contains "Medication Taken:"
    if (data.indexOf("Medication Taken:") != -1) {
      String dateTime = getFormattedDateTime();
      file.println("Date: " + dateTime); // Add date and time
    }
    file.println(data);  // Write the received data
    file.close();
    Serial.println("File written successfully with date and time.");
  } else {
    Serial.println("Failed to open file for writing.");
  }
}

// Create a file for testing without Bluetooth
void createTestFile() {
    File file = SPIFFS.open("/received.txt", "w");

    if (file) {
        file.print(
            "Current Time: 2025-02-11 16:51:35\n\n"
            "Medication: Methadone\n"
            "Dose: 100\n"
            "Frequency: Once daily\n"
            "Times: 4:52 PM\n"
            "Days: 1 to 5\n\n"
            
            "Prompt: stress?\n"
            "Required Response: Yes\n"
            "Options: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10\n"
            "Days: 1 to 5\n\n"
            
            "Prompt: opioids?\n"
            "Required Response: Yes\n"
            "Options: Yes, No\n"
            "Days: 1 to 5\n\n"
            
            "Prompt: momma?\n"
            "Required Response: Journal Response\n"
            "Options: Respond in Journal\n"
            "Days: 1 to 5\n"
        );

        file.close();
        Serial.println("File written successfully.");
    } else {
        Serial.println("Failed to create file for writing.");
    }
}


//6th
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
  } else if (line.startsWith("Prompt: ")) {
    // Dynamically extract and store any line starting with "Prompt"
    prompts.push_back(line.substring(line.indexOf(":") + 2)); // Extract prompt text after "PromptX: "
  } else if (line.startsWith("Options: ")) {
    // Dynamically extract and store any line starting with "Options"
      options.push_back(line.substring(line.indexOf(":") + 2));
  }
}
file.close();
}


//5th
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

//7th
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

//8th
// Parse medication time and store as reminder time
void parseMedicationTime(String timeString) {
  int h_alarm, m_alarm, h, m;
  char period[3];
  sscanf(timeString.c_str(), "%d:%d %s", &h_alarm, &m_alarm, period);

  // Set reminder time to today at the parsed hour and minute                                     //Update to work if it is the same hour
    if (h_alarm < hour() || (h_alarm == hour() && m_alarm <= minute())) {
    // If the reminder time is earlier than the current time, set it for the next day
    h = 24 - (hour() - h_alarm); // Hours to the next day's alarm
  } else {
    h = h_alarm - hour(); // Hours difference for the same day
  }

  // Adjust for AM/PM format if necessary
  if (strcmp(period, "PM") == 0 && h_alarm < 12) h -= 12;
  Serial.print("Your alarm will go off at: ");
  Serial.println(timeString);

  // Calculate minutes difference
  if (m_alarm < minute()) {
    m = 60 - (minute() - m_alarm);
    h -= 1; // Adjust for crossing the hour boundary
  } else {
    m = m_alarm - minute();
  }

// Set the reminder time
  reminderTime = now() + (h * 60 * 60) + (m * 60);
  Serial.print("Medication Reminder Set for: ");
  Serial.print(h);
  Serial.print(":");
  Serial.println(m);
}

void splitOptions(const String& optionString, std::vector<String>& optionList) {
    size_t start = 0, end = 0;

    while ((end = optionString.indexOf(',', start)) != -1) {
        String option = optionString.substring(start, end); // Extract substring
        option.trim(); // Trim whitespace in-place
        optionList.push_back(option); // Add to the list
        start = end + 1;
    }

    if (start < optionString.length()) {
        String option = optionString.substring(start); // Add the last option
        option.trim(); // Trim whitespace in-place
        optionList.push_back(option);
    }
}

int waitForNavigation() {
    while (true) {
        if (digitalRead(BUTTON_NEXT) == LOW) {
            delay(200);  // Debounce delay
            return 1;  // Move forward
        }
        if (digitalRead(BUTTON_BACK) == LOW) {
            delay(200);
            return -1; // Move backward
        }
        if (digitalRead(BUTTON_ENTER) == LOW) {
            delay(200);
            return 0; // Confirm selection
        }
        delay(10);  // Small delay to avoid high CPU usage
    }
}

void loop() {
    // Update time and check if it's time for the reminder
    if (reminderTime != 0) { // Make sure there is a reminder time in the system
        if (now() >= reminderTime && now() < reminderTime + 60) {  // If it's the reminder time within a minute
            tft.fillRect(0, connection_bar, screen_w, screen_h - connection_bar, ILI9341_BLACK);
            tft.setCursor(10, 30);
            tft.setTextSize(2);
            tft.println("Time to take your meds");
            tft.println("Press the button below to dispense");

            // Wait for the user to press ENTER before proceeding
            while (waitForNavigation() != 0);

            // Save prompts and dynamically selected responses to log
            String logEntry = ""; // Initialize variable

            for (int i = 0; i < prompts.size(); i++) {
                // Clear the screen before displaying each prompt
                tft.fillRect(0, connection_bar, screen_w, screen_h - connection_bar, ILI9341_BLACK);
                
                // Center the prompt text
                tft.setCursor(screen_w / 2 - (prompts[i].length() * 6), screen_h / 3);
                tft.setTextSize(2);
                tft.setTextColor(ILI9341_WHITE);
                tft.println(prompts[i]);

                // Parse options and dynamically select one
                std::vector<String> optionList;
                if (i < options.size()) {
                    splitOptions(options[i], optionList);
                }

                // Set up and start button commands
                String selectedOption = optionList.empty() ? "No response" : optionList[0]; // Default to first option
                int selectedIndex = 0;

                while (true) {
                    // Clear screen area for options
                    tft.fillRect(0, screen_h / 2, screen_w, screen_h / 3, ILI9341_BLACK);
                    
                    // Display the currently selected option, centered
                    tft.setCursor(screen_w / 2 - (optionList[selectedIndex].length() * 6), screen_h / 2);
                    tft.setTextSize(2);
                    tft.setTextColor(ILI9341_YELLOW);
                    tft.println("< " + optionList[selectedIndex] + " >");

                    int action = waitForNavigation();

                    if (action == 1) { // NEXT button pressed
                        selectedIndex = (selectedIndex + 1) % optionList.size(); // Cycle forward
                    } else if (action == -1) { // BACK button pressed
                        selectedIndex = (selectedIndex - 1 + optionList.size()) % optionList.size(); // Cycle backward
                    } else if (action == 0) { // ENTER button pressed
                        selectedOption = optionList[selectedIndex];
                        break; // Confirm selection and move on
                    }
                }

                // Append the prompt and selected option to the log entry
                logEntry += "Prompt: " + prompts[i] + "  Response: " + selectedOption + '\n';
            }

            // Save the log to file
            Serial.print(logEntry); // Print all entries

            // Save medication to log
            String medEntry = "Medication Taken: " + String(hour()) + ":" + String(minute()) + ":" + String(second());
            Serial.print(medEntry);
            saveData(medEntry, "/log.txt");
            saveData(logEntry, "/log.txt"); // Save prompts and responses to log

            // Trigger Bluetooth file send
            myCallbacks.sendFile(pCharacteristic, "/log.txt");
            tft.println("\nConnecting to your phone");

            // Set reminder for the next day
            reminderTime += 86400;  // Add 24 hours (in seconds)
            Serial.println("Reminder set for the same time tomorrow:");
            Serial.println(reminderTime);
        }
    }

    // Default screen between doses
    if (now() < reminderTime) {
        tft.fillScreen(ILI9341_BLACK);
        tft.setCursor(25,75);
        tft.setTextColor(ILI9341_WHITE);
        tft.setTextSize(12);
        tft.println("NODE");
        delay(10000);  // Refresh every 10 seconds
    }
}
