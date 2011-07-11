/* CalSol - UC Berkeley Solar Vehicle Team 
 * CutoffBasic.pde - Cutoff Module
 * Author(s): Ryan Tseng. Brian Duffy
 * Date: Jun 18th 2011
 */

#define DEBUG_CAN
#define DEBUG_MEASUREMENTS
#define DEBUG
#include "cutoffHelper.h"
#include "cutoffCanID.h"
#include "cutoffPindef.h"


void process_packet(CanMessage &msg) {
  last_can = millis();
  switch(msg.id) {     
    /* Add cases for each CAN message ID to be received*/
    
    /* Emergencies */
    case CAN_EMER_BPS:
      bps_code = msg.data[0];
      emergency = 1;
      break; 
    case CAN_EMER_DRIVER_IO:
      emergency = 1;
      break;
    case CAN_EMER_DRIVER_CTL:
      emergency = 1;
      break;  
    case CAN_EMER_TELEMETRY:
      emergency = 1;
      break;      
    case CAN_EMER_OTHER1:
      emergency = 1;
      break;
    case CAN_EMER_OTHER2:
      emergency = 1;
      break;
    case CAN_EMER_OTHER3:
      emergency = 1;
      break;
      
    /* Heartbeats */
    case CAN_HEART_BPS:
      last_heart_bps = millis();
      bps_code = msg.data[0];
      if (msg.data[0] == 0x01) {
        /* Warning flag */
        warning = 1;
      } else if (msg.data[0] == 0x02) {
        warning = 2;
      } else if (msg.data[0] == 0x04) {
        /* Critical error flag */
        emergency = 2;
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
    default:
      break;
  }
}

void setup() {
  /* General init */
  initPins();
  Serial.begin(115200);
  initCAN();  
  /* Precharge */
  state = PRECHARGE;
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
  if (millis() - last_heart_cutoff > 200) {  //Send out the cutoff heartbeat to anyone listening.  
    last_heart_cutoff = millis();
    sendHeartbeat();
  }
  if (millis()-last_readings > 103){  // Send out system voltage and current measurements
                                      //chose a weird number so it wouldn't always match up with the heartbeat timing    
    last_readings = millis();
    sendReadings();
  }
  #ifdef DEBUG_CAN
      Serial.print("last_heart_bps: ");
      Serial.println(last_heart_bps);   
  #endif
    
}

