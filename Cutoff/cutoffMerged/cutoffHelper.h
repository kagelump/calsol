/* CalSol - UC Berkeley Solar Vehicle Team 
 * cutoffHelper.h - Cutoff Module
 * Purpose: Helper functions for the cutoff module
 * Author(s): Ryan Tseng. Brian Duffy
 * Date: Jun 18th 2011
 */

#ifndef _CUTOFF_HELPER_H_
#define _CUTOFF_HELPER_H_ 
#include <WProgram.h>
#include "pitches.h"
#include "cutoffCanID.h"
#include "cutoffPindef.h"

/* State variables */

unsigned long startTime = 0;

volatile unsigned long last_readings = 0;
volatile unsigned long last_heart_bps = 0;
volatile unsigned long last_heart_driver_io = 0;
volatile unsigned long last_heart_driver_ctl = 0;
volatile unsigned long last_heart_telemetry = 0;
volatile unsigned long last_heart_datalogger = 0;
volatile unsigned long last_heart_cutoff = 0;
volatile unsigned long last_can = 0;
volatile unsigned long last_printout = 0;
volatile int emergency = 0;
volatile int warning = 0;
volatile int bps_code = 0;

enum STATES {
  PRECHARGE,
  NORMAL,
  TURNOFF,
  ERROR
} state;

enum SHUTDOWNREASONS {
  POWER_LOSS,
  KEY_OFF,
  BPS_HEARTBEAT,
  S_UNDERVOLT,
  S_OVERVOLT,
  S_OVERCURRENT,
  BPS_UNDERVOLT,
  BPS_OVERVOLT,
  BPS_OVERTEMP,  
  BPS_EMERGENCY_OTHER, //redundant?
  IO_EMERGENCY,
  CONTROLS_EMERGENCY,
  TELEMETRY_EMERGENCY,
  OTHER1_EMERGENCY,
  OTHER2_EMERGENCY,
  OTHER3_EMERGENCY,
  BPS_ERROR //redundant?  
} shutdownReason;

void printShutdownReason(int shutdownReason){
  Serial.print("Shutdown Reason: ");
  switch (shutdownReason){
    case POWER_LOSS:
      Serial.println("Loss of power to cutoff.  Possibly due to bomb switch.");
      break; 
    case KEY_OFF:
      Serial.println("Normal Shutdown.  Key in off position.");
      break; 
    case BPS_HEARTBEAT:
      Serial.println("Missing BPS heartbeat.");
      break; 
    case S_UNDERVOLT:
      Serial.println("High voltage line undervoltage.");
      break; 
    case S_OVERVOLT:
      Serial.println("High voltage line overvoltage.");
      break; 
    case S_OVERCURRENT:
      Serial.println("High voltage line overcurrent.");
      break; 
    case BPS_EMERGENCY_OTHER:
      Serial.println("Battery Protection System Emergency: Other");
      break; 
    case BPS_UNDERVOLT:
      Serial.println("BPS Emergency: Battery Undervoltage");
      break; 
    case BPS_OVERVOLT:
      Serial.println("BPS Emergency: Battery Overvoltage");
      break; 
    case BPS_OVERTEMP:
      Serial.println("BPS Emergency: Batteries Overtemperature");
      break; 
    case IO_EMERGENCY:
      Serial.println("Input Output Boards Emergency.");
      break;   
    case CONTROLS_EMERGENCY:
      Serial.println("Controls Boards Emergency.");
      break;
    case TELEMETRY_EMERGENCY:
      Serial.println("Telemetry Board Emergency.");
      break;
    case OTHER1_EMERGENCY:
      Serial.println("Other Board 1 Emergency.");
      break;
    case OTHER2_EMERGENCY:
      Serial.println("Other Board 2 Emergency.");
      break;
    case OTHER3_EMERGENCY:
      Serial.println("Other Board 3 Emergency.");
      break;
    case BPS_ERROR:
      Serial.println("Battery Protection System Error.");
      break; //redundant?
    default:
      Serial.println("Unknown Shutdown Reason.");
      break;
  }  
}



/*Buzzer and Music */
unsigned long warningTime = 0; //play buzzer/keep LED on until this time is reached
int shortWarning = 200; //play buzzer for a short duration
int longWarning = 600; //play buzzer for slightly longer duration

boolean playingSong = false;
int* duration;
int* notes;
int songSize;
int currentNote=0;
long endOfNote=0;

void process_packet(CanMessage &msg);

void initialize();

void initCAN(){
   /* Can Initialization w/ filters */
  Can.reset();
  Can.filterOn();
  Can.setFilter(1, 0x020, 1);
  Can.setFilter(1, 0x040, 2);
  Can.setMask(1, 0x7F0);
  Can.setMask(2, 0x000);
  Can.attach(&process_packet);
  Can.begin(1000, false);
  CanBufferInit(); 
}

void tone(uint8_t _pin, unsigned int frequency, unsigned long duration);

void playSongs(){
//shut off buzzer/LED if no longer sending warning
        if ((millis() > (warningTime - 100)) && !playingSong) {
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
          if (currentNote >= songSize) {
            playingSong = false;
            digitalWrite(BUZZER, LOW);
          }
        }
}

//play tetris
void loadTetris(){     
      if (!playingSong) {
        playingSong = true;
        duration = tetrisDuration;
        notes = tetrisNotes;
        songSize = tetrisSize;
        currentNote = 0;
      } 
}

//play BadRomance
void loadBadRomance(){
      //play bad romance
      if (!playingSong) {
        playingSong = true;
        duration = badRomanceDuration;
        notes = badRomanceNotes;
        songSize = badRomanceSize;
        currentNote = 0;
      }
}


//reads voltage from first voltage source (millivolts)
long readV1() {
  long reading = analogRead(V1);
  long voltage = reading * 5 * 1000 / 1023 ;  
  // 2.7M+110K +470K/ 110K Because a fuse kept blowing We also added
  // in another resistor to limit the current (470K).
  voltage = voltage * (270+10.8) / 10.8; // 2.7M+110K / 110K   voltage divider
  return voltage ;
}

//reads voltage from second voltage source (milliVolts)
long readV2() {
  long reading = analogRead(V2);
  long voltage = reading * 5 *1000 / 1023 ;  
  // 2.7M+110K +470K/ 110K Because a fuse kept blowing We also added
  // in another resistor to limit the current (470K).
  voltage = voltage * (270+10.8) / 10.8; // 2.7M+110K / 110K   voltage divider
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
  long current = 40 * (c1 - cGND); //Scaled over 25 ohm resistor. multiplied by 1000 V -> mV conversion
  return current;
}

//reads current from second hall effect sensor (milliAmps)
long readC2() {
  long cRead = analogRead(C2);
  long gndRead = analogRead(CGND);
  long c1 = cRead * 5 * 1000 / 1023;
  long cGND = gndRead * 5 * 1000 / 1023;
  long current = 40 * (c1 - cGND); //Scaled over 25 ohm resistor. multiplied by 1000 V -> mV conversion
  return current;
}


/* Turn of car if Off Switch is triggered */
char checkOffSwitch(){
      //normal shutdown initiated
      if (digitalRead(IO_T1) == HIGH) {
        if (state!=TURNOFF){ 
          Serial.print("key detected in off position\n");
          delay(50); //
        }
        if (digitalRead(IO_T1) == HIGH) { //double check.  
            //Had issues before when releasing key from precharge
            state = TURNOFF;            
            shutdownReason=KEY_OFF;
            //Serial.print("Normal Shutdown\n");
            return 1;
        }
      }
      return 0;
}

void checkReadings() {
  CanMessage msg = CanMessage();
  long batteryV = readV1();
  long motorV = readV2();
  long batteryC = readC1();
  long otherC = readC2();
  long undervoltage = 90000;  //90,000 mV
  long overvoltage = 140000; //140,000 mV
  long overcurrent1 = 60000; //60,000 mA
  long overcurrent2 = 15000; //15,000 mA
  if (batteryV <= undervoltage) {
    shutdownReason=S_UNDERVOLT;
    state = ERROR;
    msg.id = CAN_EMER_CUTOFF;
    msg.len = 1;
    msg.data[0] = 0x02;
    Can.send(msg);
  }
  else if (batteryV >= overvoltage || motorV >= overvoltage) {
    shutdownReason=S_OVERVOLT;
    state = ERROR;
    msg.id = CAN_EMER_CUTOFF;
    msg.len = 1;
    msg.data[0] = 0x01;
    Can.send(msg);
  }
/*  else if (batteryC >= overcurrent1 || otherC >= overcurrent2) {
    shutdownReason=S_OVERCURRENT;
    state = ERROR;
    msg.id = CAN_EMER_CUTOFF;
    msg.len = 1;
    msg.data[0] = 0x04;
    Can.send(msg);
  }*/ //disabled until current sensors reliable
}

void floatEncoder(CanMessage &msg,float f1, float f2) {
  float *floats = (float*)(msg.data);
  floats[0] = f1;
  floats[1] = f2;
  /*
  msg.data[0] = *((char *)&f1);
  msg.data[1] = *(((char *)&f1)+1);
  msg.data[2] = *(((char *)&f1)+2);
  msg.data[3] = *(((char *)&f1)+3);
  msg.data[4] = *((char *)&f2);
  msg.data[5] = *(((char *)&f2)+1);
  msg.data[6] = *(((char *)&f2)+2);
  msg.data[7] = *(((char *)&f2)+3);
  */
}

void sendVoltages(){
  CanMessage msg = CanMessage();
  long v1 = readV1();
  long v2 = readV2();
  
  float volt1 = v1;
  float volt2 = v2;
  
  #ifdef DEBUG_MEASUREMENTS
      Serial.print(" V1: ");
      Serial.print(v1);
      Serial.print("mV V2: ");
      Serial.print(v2);     
  #endif
  
  msg.id = CAN_CUTOFF_VOLT;
  msg.len = 8;
  floatEncoder(msg, volt1, volt2);
  /*
  msg.data[0] = volt1 & 0x00FF;
  msg.data[1] = (volt1 >>8 ) & 0x00FF;
  msg.data[2] = (volt1 >>16) & 0x00FF;
  msg.data[3] = (volt1 >>24) & 0x00FF;
  msg.data[4] = volt2 & 0x00FF;
  msg.data[5] = (volt2 >>8 ) & 0x00FF;
  msg.data[6] = (volt2 >>16) & 0x00FF;
  msg.data[7] = (volt2 >>24) & 0x00FF;
  */
  Can.send(msg);
  
}

void sendCurrents(){
  CanMessage msg = CanMessage();
  long c1 = readC1();
  long c2 = readC2();
  
  float curr1 = c1;
  float curr2 = c2;
  
  #ifdef DEBUG_MEASUREMENTS
      Serial.print("mV C1: ");
      Serial.print(C1);
      Serial.print(" C2: ");
      Serial.println(C2); 
  #endif
  
  msg.id = CAN_CUTOFF_CURR;
  msg.len = 8;
  floatEncoder(msg, curr1, curr2);
  /*
  msg.data[0] = curr1 & 0x00FF;
  msg.data[1] = (curr1 >>8 ) & 0x00FF;
  msg.data[2] = (curr1 >>16) & 0x00FF;
  msg.data[3] = (curr1 >>24) & 0x00FF;
  msg.data[4] = curr2 & 0x00FF;
  msg.data[5] = (curr2 >>8 ) & 0x00FF;
  msg.data[6] = (curr2 >>16) & 0x00FF;
  msg.data[7] = (curr2 >>24) & 0x00FF;
  */
  Can.send(msg);
}


/* Send system voltage/current over CAN */
void sendReadings() {
  sendVoltages();
  sendCurrents();  
}

void sendHeartbeat() {
  CanMessage msg;
  msg.id = CAN_HEART_CUTOFF;
  msg.len = 1;
  msg.data[0] = 0x00;
  Can.send(msg);
}

void initVariables(){
  last_readings = 0;
  last_heart_bps = 0;
  last_heart_driver_io = 0;
  last_heart_driver_ctl = 0;
  last_heart_telemetry = 0;
  last_heart_datalogger = 0;
  last_heart_cutoff = 0;
  last_can = 0;
  emergency = 0;
  warning = 0;
  bps_code = 0;
  
  
  startTime=millis();
}

/* Does the precharge routine: Wait for motor voltage to reach a threshold,
 * then turns the car to the on state by switching on both relays */
void do_precharge() {
  digitalWrite(LED1, HIGH);
  last_heart_bps = 0; //reset heartbeat tracking
  long prechargeV = (readV1() / 1000.0); //milliVolts -> Volts
  long batteryV = (readV2() / 1000.0); //milliVolts -> Volts
  int prechargeTarget = 100; //~100V ?
  int voltageDiff= abs(prechargeV-batteryV);
  
  if ( checkOffSwitch() ) {
    /* Off switch engaged, Transition to off */
    state = TURNOFF; //actually redundant
    return;
  }
  else if ((prechargeV < prechargeTarget)  || (voltageDiff>3) 
      || (millis()-startTime < 1000)) { //wait for precharge to bring motor voltage up to battery voltage  
    /* Precharge incomplete */
    #ifdef DEBUG
      Serial.print("Precharge State -- Motor Voltage: ");
      Serial.print(prechargeV, DEC);
      Serial.print("V  Battery Voltage: ");
      Serial.print(batteryV, DEC);
      Serial.print("V\n");
      delay(100);
    #endif
    state = PRECHARGE;
  }
  else {
    /* Precharge complete */
    #ifdef DEBUG
      Serial.print("Precharge Voltage Reached: ");
      Serial.print(prechargeV);
      Serial.println("V");
    #endif
    /* Turn on relays, delay put in place to avoid relay current spike */
    digitalWrite(RELAY1, HIGH);
    delay(100);
    digitalWrite(RELAY2, HIGH);
    delay(100);
    digitalWrite(LVRELAY, HIGH);
    
    // Hack to wait until the BPS turns on
    while(!last_heart_bps) {
      #ifdef DEBUG_CAN
        Serial.print("Last can: ");
        Serial.println(last_can);
      #endif
      delay(50);
    
  }
    
    /* Sound buzzer */
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
    
    /* State Transition */
    state = NORMAL;
  }
}

/* Car running state, check for errors, otherwise continue operation */
void do_normal() {
  CanMessage msg = CanMessage();
  if ( emergency ) {
    state = ERROR;
    //msg.id = CAN_EMER_CUTOFF;
    //msg.len = 1;
    //msg.data[0] = 0x08;
    //Can.send(msg);
  } else if ( checkOffSwitch() ) {
    #ifdef DEBUG
      Serial.println("Switch off. Normal -> Turnoff");
    #endif
    /* Check if switch is on "On" position */
    state = TURNOFF;
  } else if ( millis() - last_heart_bps > 1000 ) {
    /* Did not receive heartbeat from BPS for 1 second */
    msg.id = CAN_EMER_CUTOFF;
    msg.len = 1;
    msg.data[0] = 0x10;
    Can.send(msg);
    shutdownReason = BPS_HEARTBEAT;
    state = ERROR;
  }
}

void lastShutdownReason(){
  int memoryIndex = EEPROM.read(0);  
  int lastReason = EEPROM.read(memoryIndex);
  printShutdownReason(lastReason);
}

void shutdownLog(){
  int memoryIndex = EEPROM.read(0);  
  for(int i=1;i<50; i++){ 
    int lastReason = EEPROM.read(memoryIndex);
    printShutdownReason(lastReason);
    memoryIndex++;
    if (memoryIndex>50){
      memoryIndex=1;
    }
  }
}

void recordShutdownReason(){
  int memoryIndex = EEPROM.read(0); 
  if (memoryIndex >= 50){ memoryIndex =0;}
  EEPROM.write(0, memoryIndex+1);
  EEPROM.write(memoryIndex+1, shutdownReason);
}

/* Turn the car off normally */
void do_turnoff() {
  Can.send(CanMessage(CAN_CUTOFF_NORMAL_SHUTDOWN));
  /* Will infinite loop in "off" state as long as key switch is off */
  
  recordShutdownReason();
  printShutdownReason(shutdownReason);
  
  while (1) {
    digitalWrite(RELAY1, LOW);
    digitalWrite(RELAY2, LOW);
    digitalWrite(RELAY3, LOW);
    digitalWrite(LVRELAY, LOW);
    //if key is no longer in the off position allow for car to restart
    if ( !checkOffSwitch() ) { 
      //allow to restart car if powered by USB
      initialize();
      //state = PRECHARGE;  //included in initialize function
      break;
    }    
  }
}

/* Something bad has happened, we must beep loudly and turn the car off */
void do_error() {
  //turn off relays first
  digitalWrite(RELAY1, LOW);
  digitalWrite(RELAY2, LOW);
  digitalWrite(RELAY3, LOW);
  digitalWrite(LVRELAY, LOW);
  digitalWrite(LEDFAIL, HIGH);
  digitalWrite(BUZZER, HIGH); //If you simply do this, the buzzer will not shut off.
  
  if (shutdownReason==BPS_EMERGENCY_OTHER){  
  #ifdef DEBUG
     Serial.print("\tBPS Code: ");  
     Serial.println(bps_code & 0xFF, HEX); //print identifier of BPS error
  #endif
      if (bps_code == 0x01)
        shutdownReason=BPS_OVERVOLT;
      else if (bps_code == 0x02)
        shutdownReason=BPS_UNDERVOLT;
      else if (bps_code == 0x04)
        shutdownReason=BPS_OVERTEMP;
      else
        shutdownReason=BPS_EMERGENCY_OTHER;
  }  
  
  if (shutdownReason==BPS_HEARTBEAT){
    loadBadRomance();
  }
  else{
    loadTetris(); 
  }
  recordShutdownReason();
  printShutdownReason(shutdownReason);
  /* Trap the code execution here on error */
  while (1) {
    digitalWrite(RELAY1, LOW);
    digitalWrite(RELAY2, LOW);
    digitalWrite(RELAY3, LOW);
    digitalWrite(LVRELAY, LOW);
    digitalWrite(LEDFAIL, HIGH); 
    playSongs();
  }
}

#endif
