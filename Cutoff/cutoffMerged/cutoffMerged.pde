/* CalSol - UC Berkeley Solar Vehicle Team 
 * CutoffBasic.pde - Cutoff Module
 * Author(s): Jimmy Hack, Ryan Tseng, Brian Duffy
 * Date: Aug 3rd 2011
 */

#define DEBUG_CAN
#define DEBUG_MEASUREMENTS
#define DEBUG
//#define DEBUG_STATES

#include <EEPROM.h>
#include "cutoffHelper.h"
#include "cutoffCanID.h"
#include "cutoffPindef.h"
  
/*  This function is called via interrupt whenever a CAN message is received. */
/*  It identifies the CAN message by ID and processes it to take the appropriate action */
void process_packet(CanMessage &msg) {
  last_can = millis(); //calls to timers while in an interrupt function are not recommended, and can give some funny results.
  switch(msg.id) {     
    /* Add cases for each CAN message ID to be received*/
    
    /* Heartbeats */
    /* to optimize execution time, ordered in frequency they are likely to occur */
    case CAN_HEART_BPS:
      last_heart_bps = last_can;
      numHeartbeats++;
      bps_code = msg.data[0];     
      switch( bps_code){
        case 0x00:
          /* normal operation */
          break;
        case 0x01:
          /* BPS Undervolt Warning flag */
          warning = 1; 
          break;  
        case 0x02:
          /* BPS Overvoltage Error */
          warning = 2;
          break;
        case 0x03:
          /* BPS Temperature Error */
          warning = 3;
          break;
        case 0x04:
          /* BPS Critical error flag */
          shutdownReason=BPS_ERROR;
          emergency = 1;
          break;
        default:
          break;
      }
      break;
    case CAN_HEART_DRIVER_IO:
      last_heart_driver_io = last_can;
      break;
    case CAN_HEART_DRIVER_CTL:
      last_heart_driver_ctl = last_can;
      break;
    case CAN_HEART_TELEMETRY:
      last_heart_telemetry = last_can;
      break;
    case CAN_HEART_DATALOGGER:
      last_heart_datalogger = last_can;
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

/* This is the startup function that is called whenever the car resets */
/* It handles reinitializing all variables and pins*/
void initialize(){
  Serial.println("Initializing");
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

/* The default setup function called by Arduino at startup 
/* This performs one-time setup of our communication protocols
/* and calls another function initialize()
/* to setup pins and variables */
void setup() {
  /* General init */
  Serial.begin(115200);
  Serial.println("Powering Up");  
  initialize(); //initialize pins and variables to begin precharge state.  
  initCAN();
}


/* The default looping function called by Arduino after setup()
/* This program will loop continuously while the code is in execution.
/* We use a state machine to handle all of the different modes of operation */
void loop() {
  /* Perform state fuctions and update state */
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
  sendCutoffCAN();  //send out heartbeats and measurements at the appropriate intervals 
  processSerial();  //accept serial inputs

}




