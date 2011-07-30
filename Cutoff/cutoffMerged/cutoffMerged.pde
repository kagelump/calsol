/* CalSol - UC Berkeley Solar Vehicle Team 
 * CutoffBasic.pde - Cutoff Module
 * Author(s): Ryan Tseng. Brian Duffy
 * Date: Jun 18th 2011
 */

//#define DEBUG_CAN
#define DEBUG_MEASUREMENTS
#define DEBUG

#include <EEPROM.h>
#include "cutoffHelper.h"
#include "cutoffCanID.h"
#include "cutoffPindef.h"




int numHeartbeats = 0;

void process_packet(CanMessage &msg) {
  last_can = millis();
  switch(msg.id) {     
    /* Add cases for each CAN message ID to be received*/
    
    /* Heartbeats */
    /* to optimize execution time, ordered in frequency they are likely to occur */
    case CAN_HEART_BPS:
      last_heart_bps = millis();
      numHeartbeats++;
      bps_code = msg.data[0];     
      if (msg.data[0] == 0x01) {
        /* BPS Warning flag */
        warning = 1;   
      } else if (msg.data[0] == 0x02) {
        /* BPS Error */
        warning = 2;
      } else if (msg.data[0] == 0x04) {
        /* BPS Critical error flag */
        shutdownReason=BPS_ERROR;
        emergency = 1;
      }
      break;
    case CAN_HEART_DRIVER_IO:
      last_heart_driver_io = millis();
      break;
    case CAN_HEART_DRIVER_CTL:
      last_heart_driver_ctl = millis();
      break;
    case CAN_HEART_TELEMETRY:
      last_heart_telemetry = millis();
      break;
    case CAN_HEART_DATALOGGER:
      last_heart_datalogger = millis();
      break;
    
    
    /* Emergencies */
    case CAN_EMER_BPS:
      bps_code = msg.data[0];
      emergency = 1;      
      shutdownReason=BPS_EMERGENCY_OTHER;  //will shut down, then specify type of BPS ERRO     
      break; 
    case CAN_EMER_DRIVER_IO:
      emergency = 1;
      shutdownReason=IO_EMERGENCY;
      break;
    case CAN_EMER_DRIVER_CTL:
      emergency = 1;
      shutdownReason=CONTROLS_EMERGENCY;
      break;  
    case CAN_EMER_TELEMETRY:
      emergency = 1;
      shutdownReason=TELEMETRY_EMERGENCY;
      break;      
    case CAN_EMER_OTHER1:
      emergency = 1;
      shutdownReason=OTHER1_EMERGENCY;
      break;
    case CAN_EMER_OTHER2:
      emergency = 1;
      shutdownReason=OTHER2_EMERGENCY;
      break;
    case CAN_EMER_OTHER3:
      emergency = 1;
      shutdownReason=OTHER3_EMERGENCY;
      break;      
    
    default:
      break;
  }
}

void initialize(){
  initPins();
  initVariables();
  lastShutdownReason(); //print out reason for last shutdown
  /* Precharge */
  lastState=TURNOFF;//initialize in off state if key is off.
  if (checkOffSwitch()){
    state=TURNOFF;
  }
  else{
    state = PRECHARGE; //boot up the car
  }
}

void setup() {
  /* General init */
  Serial.begin(115200);
  initialize(); //initialize pins and variables to begin precharge state.  
  initCAN();
}

void loop() {
  // Perform state fuctions and update state
    switch (state) {
      case PRECHARGE:
        do_precharge();
        break;
      case NORMAL:
        do_normal();        
        break;
      case TURNOFF:
        do_turnoff();
        break;
      case ERROR:
        do_error();
        break;
      default:
        #ifdef DEBUG
          Serial.println("Defaulted to error state.   There must be a coding issue.");
        #endif
        do_error();
        break;
    }
    
  /*This code cannot change the state */
  if (millis() - last_heart_cutoff > 200) {  //Send out the cutoff heartbeat to anyone listening.  
    last_heart_cutoff = millis();
    sendHeartbeat();
  }
  if (millis() - last_readings > 103){  // Send out system voltage and current measurements
                                        //chose a weird number so it wouldn't always match up with the heartbeat timing    
    last_readings = millis();
    sendReadings();
  }
  #ifdef DEBUG_CAN
      //Serial.print("last_heart_bps: ");
      //Serial.println(last_heart_bps);   
  
  
  if (millis()-last_printout > 1000){
    Serial.print("Last Heartbeat:");
    Serial.println(numHeartbeats);
    numHeartbeats=0;
    last_printout=millis();
  }
  #endif
  if(Serial.available()){
    char letter= Serial.read();
    if(letter=='l'){
      shutdownLog();
    }
  }
}

