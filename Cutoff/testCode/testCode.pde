#include "pitches.h"

//buzzer
#define BUZZER   12
//relays
#define RELAY1   18
#define RELAY2   19
#define RELAY3   20  //no led
#define LVRELAY  13
//leds
#define LED1     23
#define LED2     22
#define LEDFAIL  14
#define LEDCAN    3
//readings
#define CGND     26
#define C1       27
#define C2       28
#define V1       29
#define V2       30
//input/output
//top port
#define IO1      31  //right ethernet
#define IO2       0
#define IO3       1
#define IO4       2  //left ethernet
//bottom port
#define IO5       4  //left ethernet
#define IO6       5
#define IO7       6
#define IO8       7  //right ethernet



//cycles through signaling the relays to switch on/off
void testRelays() {
  digitalWrite(RELAY1, HIGH);
  delay(1000);
  digitalWrite(RELAY2, HIGH);
  delay(1000);
  digitalWrite(RELAY3, HIGH);
  delay(1000);
  digitalWrite(LVRELAY, HIGH);
  delay(1000);
  digitalWrite(RELAY1, LOW);
  digitalWrite(RELAY2, LOW);
  digitalWrite(RELAY3, LOW);
  digitalWrite(LVRELAY, LOW);
  delay(1000);
}

//cycles through the LEDs
void testLEDs() {
  digitalWrite(LED1, HIGH);
  delay(1000);
  digitalWrite(LED2, HIGH);
  delay(1000);
  digitalWrite(LEDFAIL, HIGH);
  delay(1000);
  digitalWrite(LED1, LOW);
  digitalWrite(LED2, LOW);
  digitalWrite(LEDFAIL, LOW);
  delay(1000);
}

//cycles through outputs
void testIO() {
  digitalWrite(IO1, HIGH);
  delay(1000);
  digitalWrite(IO2, HIGH);
  delay(1000);
  digitalWrite(IO3, HIGH);
  delay(1000);
  digitalWrite(IO4, HIGH);
  delay(1000);
  digitalWrite(IO5, HIGH);
  delay(1000);
  digitalWrite(IO6, HIGH);
  delay(1000);
  digitalWrite(IO7, HIGH);
  delay(1000);
  digitalWrite(IO8, HIGH);
  delay(1000);
  digitalWrite(IO1, LOW);
  digitalWrite(IO2, LOW);
  digitalWrite(IO3, LOW);
  digitalWrite(IO4, LOW);
  digitalWrite(IO5, LOW);
  digitalWrite(IO6, LOW);
  digitalWrite(IO7, LOW);
  digitalWrite(IO8, LOW);
  delay(1000);
}

//reads voltage from first voltage source
int readV1() {
  int voltage = analogRead(V1);
  return voltage * (270 / 11); // 2.7M / 110K
}

//reads voltage from second voltage source
int readV2() {
  int voltage = analogRead(V2);
  return voltage * (270 / 11); // 2.7M / 110K
}

//reads current from first hall effect sensor
int readC1() {
  int current = analogRead(C1);
  int gnd = analogRead(CGND);
  //return (constant * (C1 - CGND))
  return 0;
}

//reads current from second hall effect sensor
int readC2() {
  int current = analogRead(C2);
  int gnd = analogRead(CGND);
  //return (constant * (C2 - CGND))
  return 0;
}

//set output pins
void setup() {
  pinMode(BUZZER, OUTPUT);
  digitalWrite(BUZZER, LOW);
  pinMode(RELAY1, OUTPUT);
  pinMode(RELAY2, OUTPUT);
  pinMode(RELAY3, OUTPUT);
  pinMode(LVRELAY, OUTPUT);
  pinMode(LEDFAIL, OUTPUT);
  pinMode(LED1, OUTPUT);
  pinMode(LED2, OUTPUT);
  pinMode(IO1, OUTPUT);
  pinMode(IO2, OUTPUT);
  pinMode(IO3, OUTPUT);
  pinMode(IO4, OUTPUT);
  pinMode(IO5, OUTPUT);
  pinMode(IO6, OUTPUT);
  pinMode(IO7, OUTPUT);
  pinMode(IO8, OUTPUT);
  //playBadRomance();
}

//loop through tests
void loop() {
  //testRelays();
  //testLEDs();
  //testIO();
  //playMusic("tetris");
  //delay(10);
  //playMusic("badromance");
  //digitalWrite(RELAY1, HIGH);
  //delay(1000);
  //digitalWrite(RELAY2, HIGH);
  //delay(1000);
  //digitalWrite(RELAY3, HIGH);
  //delay(1000);
  //digitalWrite(LVRELAY, HIGH);
  //delay(1000);
  testRelays();
}




