#include <Servo.h>

Servo myServo;  // Create a servo object

int servoPin = 2;  // Pin connected to the servo signal

void setup() {
  myServo.attach(servoPin);  // Attach the servo to pin 9
}

void loop() {
  myServo.write(0);    // Move servo to 0 degrees
  delay(1000);         // Wait 1 second
  myServo.write(90);   // Move servo to 90 degrees
  delay(1000);         // Wait 1 second
  myServo.write(180);  // Move servo to 180 degrees
  delay(1000);         // Wait 1 second
}
