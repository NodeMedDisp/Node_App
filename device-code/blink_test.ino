void setup() {
  pinMode(T2, OUTPUT);  // Initialize the built-in LED pin as an output
}

void loop() {
  digitalWrite(T2, HIGH);  // Turn the LED on
  delay(1000);                      // Wait for a second
  digitalWrite(T2, LOW);   // Turn the LED off
  delay(1000);                      // Wait for a second
}
