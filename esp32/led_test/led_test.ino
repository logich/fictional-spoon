// Blinks common ESP32 LED pins one at a time.
// Watch which pin lights up the "L" LED.

int pins[] = {2, 4, 5, 12, 13, 14, 15, 16, 17, 18, 19, 21, 22, 23, 25, 26, 27, 32, 33};
int numPins = sizeof(pins) / sizeof(pins[0]);

void setup() {
  Serial.begin(115200);
  for (int i = 0; i < numPins; i++) {
    pinMode(pins[i], OUTPUT);
    digitalWrite(pins[i], LOW);
  }
}

void loop() {
  for (int i = 0; i < numPins; i++) {
    Serial.printf("Testing GPIO %d...\n", pins[i]);
    digitalWrite(pins[i], HIGH);
    delay(1500);
    digitalWrite(pins[i], LOW);
    delay(300);
  }
  Serial.println("--- Restarting cycle ---");
}
