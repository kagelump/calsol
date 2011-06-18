/* CalSol - UC Berkeley Solar Vehicle Team 
 * CutoffBasic.pde - Cutoff Module
 * Author(s): Ryan Tseng. Brian Duffy
 * Date: Jun 18th 2011
 */

#define DEBUG_CAN
#define DEBUG
#include "cutoffHelper.h"
#include "cutoffCanID.h"
#include "cutoffPindef.h"

long last_time = 0;

void process_packet(CanMessage &msg) {
  last_can = millis();
  switch(msg.id) {
    /* Add cases for each CAN message ID to be received*/
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
    case CAN_EMER_BPS:
      bps_code = msg.data[0];;
      emergency = 1;
    default:
      break;
  }
}

void setup() {
  /* General init */
  initPins();
  Serial.begin(115200);
  
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
  
  /* Precharge */
  state = PRECHARGE;
}

void loop() {
  if (millis() - last_time > 100) {
    // Perform state fuctions and update state
    last_time = millis();
    switch (state) {
      case PRECHARGE:
        do_precharge();
        break;
      case NORMAL:
        do_normal();
        sendReadings();  // Send system voltage and current readings
        break;
      case TURNOFF:
        do_turnoff();
        break;
      case ERROR:
        do_error();
        break;
      default:
        #ifdef DEBUG
          Serial.println("Defaulted to error state");
        #endif
        do_error();
        break;
    }
    #ifdef DEBUG_CAN
      Serial.print("last_heart_bps: ");
      Serial.println(last_heart_bps);
    #endif
    sendHeartbeat();
  }
}
