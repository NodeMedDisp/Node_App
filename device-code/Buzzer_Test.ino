int buzzerPin = 2;  // Pin connected to the buzzer


int melody[] = {
  220, 262, 294, 349, 294, 349, 294, 262, 220,  // A3-C4-D4-F4-D4-F4-D4-C4-A3
  294, 220, 349, 294, 220, 196,
};

int noteDurations[] = {
  200, 200, 200, 400, 200, 400, 200, 200, 400,
  200, 200, 400, 200, 200, 600
};

void setup() {
  pinMode(buzzerPin, OUTPUT);
}

void loop() {
  for (int i = 0; i < sizeof(melody) / sizeof(melody[0]); i++) {
    tone(buzzerPin, melody[i]);  // Play note
    delay(noteDurations[i]);     // Wait for the duration
    noTone(buzzerPin);           // Stop
    delay(50);                   // Short pause between notes
  }
  
  delay(10000);  // Pause before playing again
}
