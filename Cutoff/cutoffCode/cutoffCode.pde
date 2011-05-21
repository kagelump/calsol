#include "pitches.h"
#include "HardwareCan.h"

/* PINOUTS */
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
#define CANINT    3
//readings
#define CGND     5 //we cannot just write digital pin 26!  Need to use the Analog Pin numbers for analog reads.  These are different than the digital pin numbers
#define C1       3 //digital 28
#define C2       4 //digital 27
#define V1       1 //digital 30
#define V2       2 //digital 29
//input/output
//bottom port
#define IO_B1     7
#define IO_B2     6
#define IO_B3     5
#define IO_B4     7
//top port
#define IO_T1     2   //OFF SWITCH
#define IO_T2     1   //SONG 1 (Tetris)
#define IO_T3     0   //SONG 2 (Bad Romance)
#define IO_T4    31   //Analog 0

CanMessage msg;
int state; //0=startup 1=normal 2=turnoff 3=error
long cycleTime; //used for operation cycle in normal state
long warningTime; //play buzzer/keep LED on until this time is reached
int shortWarning = 100; //play buzzer for a short duration
int longWarning = 500; //play buzzer for slightly longer duration
//music stuff
boolean playingSong = false;
int* duration;
int* notes;
int size;
int currentNote;
long endOfNote;

boolean boardFail = false;
//heartbeat checks
boolean batteryHB = false;
//boolean motorHB = false;
//boolean mpptHB = false;
//boolean telemetryHB = false;
//boolean ioHB = false;
//boolean controlsHB = false;
//boolean dataloggerHB = false;

//reads voltage from first voltage source (millivolts)
long readV1() {
  long reading = analogRead(V1);
  long voltage = reading * 5 * 1000 / 1023 ;  
  voltage = voltage * (270+11) / 11; // 2.7M+110K / 110K
  return voltage ;
}

//reads voltage from second voltage source (milliVolts)
long readV2() {
  long reading = analogRead(V2);
  long voltage = reading * 5 * 1000 / 1023 ;  
  voltage = voltage * (270+11) / 11; // 2.7M / 110K
  return voltage; 
}

//reads current from first hall effect sensor (milliAmps)
long readC1() {
  long cRead = analogRead(C1);
  long gndRead = analogRead(CGND);
  long c1 = cRead * 5 * 1000 / 1023;
  long cGND = gndRead * 5 * 1000 / 1023;
  long current = 40 * (c1 - cGND);
  return current;
}

//reads current from second hall effect sensor (milliAmps)
long readC2() {
  long cRead = analogRead(C2);
  long gndRead = analogRead(CGND);
  long c1 = cRead * 5 * 1000 / 1023;
  long cGND = gndRead * 5 * 1000 / 1023;
  long current = 40 * (c1 - cGND);
  return current;
}

void checkReadings() {
  msg = CanMessage();
  long batteryV = readV1();
  int motorV = readV2();
  int batteryC = readC1();
  int otherC = readC2();
  delay(1000);
  int undervoltage = 90000;  //90,000 mV
  int overvoltage = 140000; //140,000 mV
  int overcurrent1 = 60000; //60,000 mA
  int overcurrent2 = 15000; //15,000 mA
  if (batteryV <= undervoltage) {
    state = 3;
    msg.id = 0x022;
    msg.len = 1;
    msg.data[0] = 0x02;
    Can.send(msg);
  }
  else if (batteryV >= overvoltage || motorV >= overvoltage) {
    state = 3;
    msg.id = 0x022;
    msg.len = 1;
    msg.data[0] = 0x01;
    Can.send(msg);
  }
  else if (batteryC >= overcurrent1 || otherC >= overcurrent2) {
    state = 3;
    msg.id = 0x022;
    msg.len = 1;
    msg.data[0] = 0x04;
    Can.send(msg);
  }
}

//Redundant check of voltage/temperature measurements from BPS
void checkBPS(CanMessage message) {
  
}

//Send personal readings of system voltage/current over CAN
void sendReadings() {
  msg = CanMessage();
  long v1 = readV1();
  int v2 = readV2();
  int c1 = readC1();
  int c2 = readC2();
  msg.id = 0x523;
  msg.len = 8;
  msg.data[0] = v1 & 0x00FF;
  msg.data[1] = (v1 & 0xFF00) >> 8;
  msg.data[2] = v2 & 0x0FF;
  msg.data[3] = (v2 & 0xFF00) >> 8;
  msg.data[4] = c1 & 0x00FF;
  msg.data[5] = (c1 & 0xFF00) >> 8;
  msg.data[6] = c2 & 0x00FF;
  msg.data[7] = (c2 & 0xFF00) >> 8;
  Can.send(msg);
}

//read and act on CAN messages
void recieveCAN() {
  if (CanBufferSize() == 0) {
    return;
  }
  msg = CanBufferRead();
  switch (msg.id) {
    
    //Emergencies
    case 0x021: //battery emergency
      //Serial.print("BPS Emergency Message");
      state = 3;
      msg = CanMessage();
      msg.id = 0x022;
      msg.len = 1;
      msg.data[0] = 0x08;
      Can.send(msg);
      break;
    case 0x023: //driver IO emergency
      //Serial.print("DriverIO emergency message");
    case 0x024: //driver controls emergency
      //Serial.print("Driver Control emergency message");
      digitalWrite(BUZZER, HIGH);
      digitalWrite(LEDFAIL, HIGH);
      warningTime = millis() + longWarning;
      break;
    case 0x025: //telemetry emergency
      //Serial.print("Telemetry emergency message");
    case 0x026: case 0x027: case 0x028: //other emergency
      //Serial.print("Other emergency message");
      digitalWrite(BUZZER, HIGH);
      digitalWrite(LEDFAIL, HIGH);
      warningTime = millis() + shortWarning;
      break;
      
    //Heartbeats
    case 0x041: //bps heartbeat
      batteryHB = true;
      //warning flag
      if (msg.data[0] == 0x01) {
        //Serial.print("BPS Warning\n");
        digitalWrite(BUZZER, HIGH);
        digitalWrite(LEDFAIL, HIGH);
        warningTime = millis() + shortWarning;
      }
      //error flag
      if (msg.data[0] == 0x02) {
        //Serial.print("BPS Board Error\n");
        digitalWrite(BUZZER, HIGH);
        digitalWrite(LEDFAIL, HIGH);
        warningTime = millis() + longWarning;
      }
      //critical error flag
      if (msg.data[0] == 0x04) {
        //Serial.print("BPS Critical Board Error\n");
        state = 3;
        msg = CanMessage();
        msg.id = 0x022;
        msg.len = 1;
        msg.data[0] = 0x08;
        Can.send(msg);
      }
      break;
    case 0x043: //driver IO heartbeat
      ioHB = true;
      //error flag
      if (msg.data[0] == 0x02) {
        //Serial.print("Driver IO Board Error\n");
        digitalWrite(BUZZER, HIGH);
        digitalWrite(LEDFAIL, HIGH);
        warningTime = millis() + shortWarning;
      }
      //critical error flag
      if (msg.data[0] == 0x04) {
        //Serial.print("Driver IO Critical Board Error\n");
        digitalWrite(BUZZER, HIGH);
        digitalWrite(LEDFAIL, HIGH);
        warningTime = millis() + longWarning;
      }
      break;
    case 0x044: //driver controls heartbeat
      controlsHB = true;
      //error flag
      if (msg.data[0] == 0x02) {
        //Serial.print("Driver Controls Board Error\n");
        digitalWrite(BUZZER, HIGH);
        digitalWrite(LEDFAIL, HIGH);
        warningTime = millis() + shortWarning;
      }
      //critical error flag
      if (msg.data[0] == 0x04) {
        //Serial.print("Driver Controls Critical Board Error\n");
        digitalWrite(BUZZER, HIGH);
        digitalWrite(LEDFAIL, HIGH);
        warningTime = millis() + longWarning;
      }
      break;
    case 0x045: //telemetry heartbeat
      telemetryHB = true;
      //no action needed for warning/error
      break;
    case 0x046: //data logger heartbeat
      dataloggerHB = true;
      //no action needed for warning/error
      break;
  }
  //Redundant check of BPS readings
  if (msg.id & 0x100 == 0x100) {
    checkBPS(msg);
  }
}

//play music on the buzzer
void playMusic(int song) {
  int* duration;
  int* notes;
  int size = 0;
  long endOfNote;
  //choose song
  if (song == 1) {
    duration = tetrisDuration;
    notes = tetrisNotes;
    size = tetrisSize;
  }
  else if (song == 2) {
    duration = badRomanceDuration;
    notes = badRomanceNotes;
    size = badRomanceSize;
  }
  //play chosen song
  playingSong = true;
  for (int thisNote = 0; thisNote < size; thisNote++) {
    int noteDuration = 1000/duration[thisNote];
    //tone(BUZZER, notes[thisNote], noteDuration);
    int pause = noteDuration * 1.30;
    delay(pause); 
  }
  playingSong = false;
  digitalWrite(BUZZER, LOW);
}

/* ---------------------------------------------------------- */

//set output pins
void setup() {
  //initialize pinouts
  pinMode(BUZZER, OUTPUT);
  digitalWrite(BUZZER, LOW);
  pinMode(RELAY1, OUTPUT);
  pinMode(RELAY2, OUTPUT);
  pinMode(RELAY3, OUTPUT);
  pinMode(LVRELAY, OUTPUT);
  pinMode(LEDFAIL, OUTPUT);
  pinMode(LED1, OUTPUT);
  pinMode(LED2, OUTPUT);
  pinMode(IO_T1, INPUT); //OFF SWITCH
  digitalWrite(IO_T1, HIGH);
  pinMode(IO_T2, INPUT); //Song 1
  digitalWrite(IO_T2, HIGH);
  pinMode(IO_T3, INPUT); //Song 
  digitalWrite(IO_T3, HIGH);
  pinMode(IO_T4, OUTPUT);
  pinMode(IO_B1, OUTPUT);
  pinMode(IO_B2, OUTPUT);
  pinMode(IO_B3, OUTPUT);
  pinMode(IO_B4, OUTPUT);
  
  pinMode(V1, INPUT);
  digitalWrite(V1, HIGH);
  pinMode(V2, INPUT);
  digitalWrite(V2, HIGH);
  //start in precharge state
  state = 0;
  Serial.begin(9600);
}

//loop through operations
void loop() {
  //perform different operations depending on state of the car
  switch (state) {  
    //startup state
    case 0: {
      checkReadings();
      if (state == 3) {
        break;
      }
      long prechargeV = (readV1() / 1000.0); //milliVolts -> Volts
      int prechargeTarget = 80; //~100V ?
      if (prechargeV < prechargeTarget) {
        delay(50); //wait for precharge
      }
      else {
        Serial.print("Precharge Voltage Reached\n");
        //advance to next state
        state = 1;
        //turn on relays
        //DO NOT TURN ALL RELAYS ON AT ONCE
        //ADD A DELAY TO AVOID MASSIVE CURRENT SPIKE
        digitalWrite(RELAY1, HIGH);
        delay(50);
        digitalWrite(RELAY2, HIGH);
        delay(50);
        //digitalWrite(RELAY3, HIGH);
        //delay(50);
        digitalWrite(LVRELAY, HIGH);
        //play happy buzzer noise
        digitalWrite(BUZZER, HIGH);
        delay(100);
        digitalWrite(BUZZER, LOW);
        delay(50);
        digitalWrite(BUZZER, HIGH);
        delay(100);
        digitalWrite(BUZZER, LOW);
        delay(50);
        digitalWrite(BUZZER, HIGH);
        delay(100);
        digitalWrite(BUZZER, LOW);
        //begin looking for CAN messages
        Can.begin(500);
        CanBufferInit();
        cycleTime = millis();
      }
    }
    break;
      
    //normal operation state
    case 1: {
      //recieve CAN messages for 1/2 second
      while ((millis() - cycleTime) <= 500) {
        //recieve CAN messages (heartbeats/error messages)
        recieveCAN();
        //error detected
        if (state == 3) {
          break;
        }
        //normal shutdown initiated
        if (digitalRead(IO_T1) == HIGH) {
          state = 2;
          break;
        }
        //play tetris
        if (digitalRead(IO_T2) == HIGH && !playingSong) {
          playingSong = true;
          duration = tetrisDuration;
          notes = tetrisNotes;
          size = tetrisSize;
          currentNote = 0;
        }
        //play bad romance
        else if (digitalRead(IO_T3) == HIGH && !playingSong) {
          playingSong = true;
          duration = badRomanceDuration;
          notes = badRomanceNotes;
          size = badRomanceSize;
          currentNote = 0;
        }
        //shut off buzzer/LED if no longer sending warning
        if (millis() > warningTime && !playingSong) {
          digitalWrite(LEDFAIL, LOW);
          digitalWrite(BUZZER, LOW);
        }
        //play some tunes
        if (playingSong && endOfNote < millis()) {
          int noteDuration = 1000/duration[currentNote];
          tone(BUZZER, notes[currentNote], noteDuration);
          int pause = noteDuration * 1.30;
          endOfNote = millis() + pause;
          currentNote++;
          if (currentNote >= size) {
            playingSong = false;
            digitalWrite(BUZZER, LOW);
          }
        }
      }
      if (state == 3) {
        break;
      }
      checkReadings();
      sendReadings();
      //check critical board heartbeats
      if (!(batteryHB && motorHB && mpptHB)) {
        //Serial.print("Critical Heartbeat Undetected\n");
        state = 3;
        msg.id = 0x022;
        msg.len = 1;
        msg.data[0] = 0x10;
        Can.send(msg);
        break;
      }
      //check non-critical board heartbeat
      if (!(ioHB && controlsHB)) {
        //Serial.print("Non-critical Heartbeat Undetected\n");
        digitalWrite(LEDFAIL, HIGH);
        digitalWrite(BUZZER, HIGH);
        warningTime = millis() + longWarning;
      }
      //set new time
      cycleTime = millis();
      //reset heartbeat values
      batteryHB = false;
      ioHB = false;
      controlsHB = false;
      telemetryHB = false;
      dataloggerHB = false;
      motorHB = false;
      mpptHB = false;
      //send cutoff heartbeat
      //Serial.print("Sending Heartbeat\n");
      msg.id = 0x042;
      msg.len = 1;
      msg.data[0] = 0x00;
      Can.send(msg);
    }
    break;
      
    //normal state -> shutdown
    case 2: {
      //Serial.println("Normal Shutdown");
      msg = CanMessage();
      msg.id = 0x521;
      msg.len = 0;
      Can.send(msg);
      //turn off relays
      digitalWrite(RELAY1, LOW);
      digitalWrite(RELAY2, LOW);
      digitalWrite(RELAY3, LOW);
      digitalWrite(LVRELAY, LOW);
    }
    break; 
      
    //error state -> shutdown
    case 3: {
      //Serial.println("Emergency Shutdown");
      digitalWrite(LEDFAIL, HIGH);
      digitalWrite(BUZZER, HIGH);
      //turn off relays
      digitalWrite(RELAY1, LOW);
      digitalWrite(RELAY2, LOW);
      digitalWrite(RELAY3, LOW);
      digitalWrite(LVRELAY, LOW);
    }
    break;
  }
}
