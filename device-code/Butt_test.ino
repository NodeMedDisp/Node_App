#define NUM_BUTTONS 3  // Number of buttons
const int buttonPins[NUM_BUTTONS] = {13, 15, 2};  // GPIO pins for buttons
bool buttonState[NUM_BUTTONS] = {HIGH, HIGH, HIGH};  // Tracks previous state
unsigned long lastDebounceTime[NUM_BUTTONS] = {0};  // Last time button state changed
const int debounceDelay = 200;  // Debounce delay in milliseconds

void setup() {
    Serial.begin(115200);  // Start serial communication
    for (int i = 0; i < NUM_BUTTONS; i++) {
        pinMode(buttonPins[i], INPUT_PULLUP);  // Enable internal pull-up
    }
}

void loop() {
    for (int i = 0; i < NUM_BUTTONS; i++) {
        int currentReading = digitalRead(buttonPins[i]);

        if (currentReading == LOW && buttonState[i] == HIGH && millis() - lastDebounceTime[i] > debounceDelay) {
            // Button was just pressed
            Serial.print("Button ");
            Serial.print(i + 1);
            Serial.println(" pressed!");

            buttonState[i] = LOW;  // Update state
            lastDebounceTime[i] = millis();  // Reset debounce timer
        } 
        else if (currentReading == HIGH) {
            buttonState[i] = HIGH;  // Reset state when button is released
        }
    }
}
