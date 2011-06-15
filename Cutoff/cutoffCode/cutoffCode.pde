#include "pitches.h"
#include <string.h>

char shutdownReason[50];

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


/*CAN*/
CanMessage msg;
int BufferSize = 0;
int maxBuffer =0;

enum cutoffState {STARTUP, NORMAL, TURNOFF, ERROR};
cutoffState state; //0=startup 1=normal 2=turnoff 3=error

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
boolean motorHB = false;
boolean mpptHB = false;
boolean telemetryHB = false;
boolean ioHB = false;
boolean controlsHB = false;
boolean dataloggerHB = false;
boolean initial = true; //Initial state

void tone(uint8_t _pin, unsigned int frequency, unsigned long duration);

void CANReport(){
  if (maxBuffer>0){
    Serial.print("Max CAN buffer size (30Max): ");
    Serial.print(maxBuffer);
    Serial.print(" current CAN buffer size (30Max): ");
    Serial.print(BufferSize);
    Serial.print("\n");
  }
  else{
   Serial.println("No CAN messages recieved"); 
  }
}

//reads voltage from first voltage source (millivolts)
long readV1() {
  long reading = analogRead(V1);
  long voltage = reading * 5 * 1000 / 1023 ;  
  voltage = voltage * (270+10.8+47) / 10.8; // 2.7M+110K / 110K   voltage divider
                                        // 2.7M+110K +470K/ 110K Because a fuse kept blowing We also added in another resistor to limit the current (470K).
  return voltage ;
}

//reads voltage from second voltage source (milliVolts)
long readV2() {
  long reading = analogRead(V2);
  long voltage = reading * 5 * 1000 / 1023 ;  
  voltage = voltage * (270+10.8+47) / 10.8; // 2.7M+110K / 110K   voltage divider
                                        // 2.7M+110K +470K/ 110K Because a fuse kept blowing We also added in another resistor to limit the current (470K).
  return voltage; 
}

//reads current from first hall effect sensor (milliAmps)
long readC1() {
  long cRead = analogRead(C1);
  //Serial.println(cRead);
  long gndRead = analogRead(CGND);
  //Serial.println(gndRead);
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
  //Serial.print("C2: ");
  //Serial.print(current, DEC);
  //Serial.print("mA\n");
  return current;
}

void checkReadings() {
  msg = CanMessage();
  long batteryV = readV1();
  long motorV = readV2();
  long batteryC = readC1();
  long otherC = readC2();
  long undervoltage = 90000;  //90,000 mV
  long overvoltage = 140000; //140,000 mV
  long overcurrent1 = 60000; //60,000 mA
  long overcurrent2 = 15000; //15,000 mA
  if (batteryV <= undervoltage) {
    strcpy(shutdownReason ,"undervoltage");
    state = ERROR;
    msg.id = 0x022;
    msg.len = 1;
    msg.data[0] = 0x02;
    Can.send(msg);
  }
  else if (batteryV >= overvoltage || motorV >= overvoltage) {
    strcpy(shutdownReason , "overvoltage");
    state = ERROR;
    msg.id = 0x022;
    msg.len = 1;
    msg.data[0] = 0x01;
    Can.send(msg);
  }
  else if (batteryC >= overcurrent1 || otherC >= overcurrent2) {
    strcpy(shutdownReason , "overcurrent");
    state = ERROR;
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
  long v2 = readV2();
  long c1 = readC1();
  long c2 = readC2();
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
  BufferSize = CanBufferSize();  //see how many messages are in our CAN mailbox
  
  if (BufferSize > maxBuffer){ //check to see if this is our record number of messages.
     maxBuffer=BufferSize; 
  }
  //Serial.println(BufferSize);
  if (BufferSize == 0) {
    //Serial.println("Empty CAN");
    return;
  }
  msg = CanBufferRead();
  //Serial.print("0x");
  //Serial.println(msg.id,HEX);
  //if((msg.id & 0x0F0)==0x040) {
  //  Serial.println("-------------------");
  //  Serial.print("0x");
  //  Serial.println(msg.data[0],HEX);
  //  Serial.println("-------------------");
  //}
  switch (msg.id) {
    
    //Emergencies
    case 0x021: //battery emergency
      //Serial.print("BPS Emergency Message");
      strcpy(shutdownReason , "BPSEmergency");
      state = ERROR;
      msg = CanMessage();
      msg.id = 0x022;
      msg.len = 1;
      msg.data[0] = 0x08;
      Can.send(msg);
      break;
    case 0x023: //driver IO emergency
        strcpy(shutdownReason ,"DriverIO emergency message");
        state = ERROR;
      //Serial.print("DriverIO emergency message");
      break;
    case 0x024: //driver controls emergency
      //Serial.print("Driver Control emergency message");
        strcpy(shutdownReason ,"Driver Controls emergency message");
        state = ERROR;
        break;
    case 0x025: //telemetry emergency
      //Serial.print("Telemetry emergency message");
        strcpy(shutdownReason ,"Telemetry emergency message");
        state = ERROR;
      break;
    case 0x026: case 0x027: case 0x028: //other emergency
      //Serial.print("Other emergency message");
        strcpy(shutdownReason ,"Other emergency message");
        state = ERROR;
      break;
      
    //Heartbeats
    case 0x041: //bps heartbeat
      batteryHB = true;
      if (msg.data[0] == 0x01) {
        //Serial.print("BPS Warning\n");
        digitalWrite(BUZZER, HIGH);
        digitalWrite(LEDFAIL, HIGH);
        warningTime = millis() + shortWarning;
      }
      //critical error flag
      if (msg.data[0] == 0x02) {
        //Serial.print("BPS Board Error\n");
        digitalWrite(BUZZER, HIGH);
        digitalWrite(LEDFAIL, HIGH);
        warningTime = millis() + longWarning;
      }
      //car shutdown necessary
      if (msg.data[0] == 0x04) {
        //Serial.print("BPS Critical Board Error\n");
        strcpy(shutdownReason , "BPS Critical Board Error");
        state = ERROR;
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
  state = STARTUP;
  Serial.begin(115200);
}

char checkOffSwitch(){
      //normal shutdown initiated
      if (digitalRead(IO_T1) == HIGH) {
        state = TURNOFF;
        //Serial.print("Normal Shutdown\n");
        return 1;
      }
      return 0;
}

void playSongs(){
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

void loadTetris(){
       //play tetris
      if (!playingSong) {
        playingSong = true;
        duration = tetrisDuration;
        notes = tetrisNotes;
        size = tetrisSize;
        currentNote = 0;
      } 
}

void loadBadRomance(){
      //play bad romance
      if (!playingSong) {
        playingSong = true;
        duration = badRomanceDuration;
        notes = badRomanceNotes;
        size = badRomanceSize;
        currentNote = 0;
      }
}

//loop through operations
void loop() {
  //perform different operations depending on state of the car
  switch (state) {
    
    //startup state
    case STARTUP: {
      //checkReadings();
      if (checkOffSwitch()){
        break;
      }
      if (state == ERROR) {
        break;
      }
      long prechargeV = (readV1() / 1000.0); //milliVolts -> Volts
      long batteryV = (readV2() / 1000.0); //milliVolts -> Volts
      int prechargeTarget = 100; //~100V ?
      int voltageDiff= abs(prechargeV-batteryV);
      
      if ((prechargeV < prechargeTarget)  ) { //wait for precharge to bring motor voltage up to battery voltage  
                                                //  || (voltageDiff>3)
        prechargeV = readV1() / 1000.0;
        Serial.print("Precharge State -- Motor Voltage: ");
        Serial.print(prechargeV, DEC);
        Serial.print("V  Battery Voltage: ");
        Serial.print(batteryV, DEC);
        Serial.print("V\n");
        delay(50);
      }
      else {
        
        Serial.print("Precharge Voltage Reached: ");
        Serial.print(prechargeV);
        Serial.println("V");
        //advance to next state
        state = NORMAL;
        //turn on relays
        //DO NOT TURN ALL RELAYS ON AT ONCE
        //ADD A DELAY TO AVOID MASSIVE CURRENT SPIKE
        digitalWrite(RELAY1, HIGH);
        delay(100);
        digitalWrite(RELAY2, HIGH);
        delay(100);
        //digitalWrite(RELAY3, HIGH);
        //delay(1000);
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
        Can.reset();
        Can.filterOn();
        Can.setFilter(1, 0x020, 1);
        Can.setFilter(1, 0x040, 2);
        Can.setMask(1, 0x7F0);
        Can.setMask(2, 0x000);
        Can.begin(1000, false);
        CanBufferInit();
        cycleTime = millis();
      }
      checkOffSwitch();
    }
    break;
      
    //normal operation state
    case NORMAL: {
      //Serial.println("Normal state");
      int timelapse;
      //recieve CAN messages for 1 second
      if(initial) { //on startup allow a leeway of 10 seconds to recieve heartbeats from other boards
        timelapse = 10000;
        initial = false;
      } else {
        timelapse = 1000; //otherwise, require a heartbeat each second
      }
      
      /*----Fast Loop of Main operation  */
      while ((millis() - cycleTime) <= timelapse) { //main mode of operation.   Monitor CAN messages       
        checkOffSwitch();
        //recieve CAN messages (heartbeats/error messages)
        //Serial.println("Is this working");
        recieveCAN();
        //error detected
        if (state == ERROR) {
          break;
        }
        if (state == TURNOFF) {
          break;
        }
        playSongs(); //updates buzzer sounds
      }
      /*End of Fast Loop */
      
      if (state == ERROR) {
        //Serial.print("Emergency Shutdown\n");
        break;
      }
      if (state==TURNOFF){ //continue normal shutdown
        break;
      }

      if(digitalRead(IO_T2) == LOW){ 
        loadTetris();
      }
      if(digitalRead(IO_T3) == LOW){ 
        loadBadRomance();
      }
      

      //checkReadings();
      sendReadings();
      //check critical board heartbeats
      if (!(batteryHB)) { // && motorHB && mpptHB)) {
        //Serial.print("Critical Heartbeat Undetected\n");
        strcpy(shutdownReason , "Missing Critical Heartbeat");
        state = ERROR;
        msg.id = 0x022;
        msg.len = 1;
        msg.data[0] = 0x10;
        Can.send(msg);
        break;
      }
      //check non-critical board heartbeat
      
      /*
      if (!ioHB) {
        Serial.println("Missing IO Heartbeat");
        digitalWrite(LEDFAIL, HIGH);
        digitalWrite(BUZZER, HIGH);
        warningTime = millis() + longWarning;
      }
      
      if (!controlsHB){
        Serial.println("Missing Controls Heartbeat");
        digitalWrite(LEDFAIL, HIGH);
        digitalWrite(BUZZER, HIGH);
        warningTime = millis() + longWarning;
      }
      */
      
      //set new time
      cycleTime = millis();
      //reset heartbeat values
      batteryHB = false;
      motorHB = false;
      mpptHB = false;
      ioHB = false;
      controlsHB = false;
      telemetryHB = false;
      dataloggerHB = false;
      //send cutoff heartbeat
      //Serial.print("Sending Heartbeat\n");
      msg.id = 0x042;
      msg.len = 1;
      msg.data[0] = 0x00;
      Can.send(msg);
    }
    break;
      
    //normal state -> shutdown
    case TURNOFF: {
      Serial.println("Off State- powering down");
      msg = CanMessage();
      msg.id = 0x521;
      msg.len = 0;
      Can.send(msg);
      CANReport();
      //turn off relays
      while (1){
        //Serial.println("off state");
        digitalWrite(RELAY1, LOW);
        digitalWrite(RELAY2, LOW);
        digitalWrite(RELAY3, LOW);
        digitalWrite(LVRELAY, LOW);
        if (checkOffSwitch()==0){ //if key is no longer in the off position allow for car to restart
          state=STARTUP;  //allow to restart car if powered by USB
          break;
        }
      }
    }
    break; 
      
    //error state -> shutdown
    case ERROR: {
      //turn off relays first
      digitalWrite(RELAY1, LOW);
      digitalWrite(RELAY2, LOW);
      digitalWrite(RELAY3, LOW);
      digitalWrite(LVRELAY, LOW);
      digitalWrite(LEDFAIL, HIGH);
      digitalWrite(BUZZER, HIGH);
      Serial.println("Error state- powering down");
      Serial.println(shutdownReason);
      CANReport();      
      
      playingSong = true;
      duration = badRomanceDuration;
      notes = badRomanceNotes;
      size = badRomanceSize;
      currentNote = 0;
      
      while (1){ //if a critical error occurs, the car cannot be reset without restarting the BRAIN
            //turn off relays
        digitalWrite(RELAY1, LOW);
        digitalWrite(RELAY2, LOW);
        digitalWrite(RELAY3, LOW);
        digitalWrite(LVRELAY, LOW);
        digitalWrite(LEDFAIL, HIGH); 
        playSongs();
      }
      
    }
    break;
  }
}
