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

volatile long last_readings = 0;
volatile long last_heart_bps = 0;
volatile long last_heart_driver_io = 0;
volatile long last_heart_driver_ctl = 0;
volatile long last_heart_telemetry = 0;
volatile long last_heart_datalogger = 0;
volatile long last_heart_cutoff = 0;
volatile long last_can = 0;
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
  KEY_OFF,
  BPS_HEARTBEAT,
  S_UNDERVOLT,
  S_OVERVOLT,
  S_OVERCURRENT,
  BPS_EMERGENCY, //redundant?
  IO_EMERGENCY,
  CONTROLS_EMERGENCY,
  TELEMETRY_EMERGENCY,
  OTHER_EMERGENCY,
  BPS_ERROR //redundant?  
} shutdownReason;


/*Buzzer and Music */
unsigned long warningTime = 0; //play buzzer/keep LED on until this time is reached
int shortWarning = 100; //play buzzer for a short duration
int longWarning = 500; //play buzzer for slightly longer duration

boolean playingSong = false;
int* duration;
int* notes;
int songSize;
int currentNote=0;
long endOfNote=0;

void process_packet(CanMessage &msg);

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
  long voltage = reading * 5 * 1000 / 1023 ;  
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


/* Turn of car if Off Switch is triggered */
char checkOffSwitch(){      
      if (digitalRead(IO_T1) == HIGH) {//normal shutdown initiated
        state = TURNOFF;
        shutdownReason=KEY_OFF;
        return 1;
      }
      return 0;
}

/* Send system voltage/current over CAN */
void sendReadings() {
  CanMessage msg = CanMessage();
  long v1 = readV1();
  long v2 = readV2();
  long c1 = readC1();
  long c2 = readC2();
  
  #ifdef DEBUG_MEASUREMENTS
      Serial.print(" V1: ");
      Serial.print(v1);
      Serial.print(" V2: ");
      Serial.print(v2);
      Serial.print(" C1: ");
      Serial.print(C1);
      Serial.print(" C2: ");
      Serial.println(C2);      
  #endif
  
  msg.id = CAN_CUTOFF_VOLT_CURR;
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

void sendHeartbeat() {
  CanMessage msg;
  msg.id = CAN_HEART_CUTOFF;
  msg.len = 1;
  msg.data[0] = 0x00;
  Can.send(msg);
}

/* Does the precharge routine: Wait for motor voltage to reach a threshold,
 * then turns the car to the on state by switching on both relays */
void do_precharge() {
  last_heart_bps = 0; //reset heartbeat tracking
  long prechargeV = (readV1() / 1000.0); //milliVolts -> Volts
  long batteryV = (readV2() / 1000.0); //milliVolts -> Volts
  int prechargeTarget = 100; //~100V ?
  int voltageDiff= abs(prechargeV-batteryV);
  
  if ( digitalRead(IO_T1) ) {
    /* Off switch engaged, Transition to off */
    state = TURNOFF;
  }
  else if ( prechargeV < prechargeTarget ) { //should replace with voltageDiff (compare battery and motor voltage)
    /* Precharge incomplete */
    #ifdef DEBUG
      Serial.print("Precharge State -- Motor Voltage: ");
      Serial.print(prechargeV, DEC);
      Serial.print("V  Battery Voltage: ");
      Serial.print(batteryV, DEC);
      Serial.print("V\n");
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
    /* We received an critical error packet, set car to ERROR state */
    //#ifdef DEBUG
    //  Serial.print("Emergency packet received: ");
    //  Serial.print(emergency);
    //  Serial.print("\tBPS Code: ");
    //  if (bps_code == 0x01)
    //    Serial.println("Overvolt Error");
    //  else if (bps_code == 0x02)
    //    Serial.println("Undervolt Error");
    //  else if (bps_code == 0x04)
    //    Serial.println("Overtemp Error");
    //  else
    //    Serial.println(bps_code & 0xFF, HEX);
    //#endif
    state = ERROR;
    //msg.id = CAN_EMER_CUTOFF;
    //msg.len = 1;
    //msg.data[0] = 0x08;
    //Can.send(msg);
  } else if ( digitalRead(IO_T1) ) {
    #ifdef DEBUG
      Serial.println("Switch off. Normal -> Turnoff");
    #endif
    /* Check if switch is on "On" position */
    state = TURNOFF;
  } else if ( millis() - last_heart_bps > 1000 ) {
    /* Did not receive heartbeat from BPS for 1 second */
    #ifdef DEBUG
      Serial.println("Did not receive heartbeat from BPS for 1 sec. ERROR");
    #endif
    msg.id = CAN_EMER_CUTOFF;
    msg.len = 1;
    msg.data[0] = 0x10;
    Can.send(msg);
    state = ERROR;
  }
}

/* Turn the car off normally */
void do_turnoff() {
  Can.send(CanMessage(CAN_CUTOFF_NORMAL_SHUTDOWN));
  /* Will infinite loop in "off" state as long as key switch is off */
  while (1) {
    digitalWrite(RELAY1, LOW);
    digitalWrite(RELAY2, LOW);
    digitalWrite(RELAY3, LOW);
    digitalWrite(LVRELAY, LOW);
    //if key is no longer in the off position allow for car to restart
    if ( !digitalRead(IO_T1) ) { 
      //allow to restart car if powered by USB
      state = PRECHARGE;  
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
  
  
  if (shutdownReason==BPS_HEARTBEAT){
    loadBadRomance();
  }
  else{
    loadTetris(); 
  }
  
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
