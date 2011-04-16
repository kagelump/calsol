#include <XBee.h>
#include "constants.h"
#include "pack.h"

uint8_t sendXBeeMsgs(XBee *x, XBeeAddress64 chaseCarXBEEaddr, XBeeMsg m[], uint32_t num) {
  uint32_t totalLenOfMessage = 0;
  for (int index = 0; index < num; index++)
    totalLenOfMessage += m[index].len;
  uint8_t data[totalLenOfMessage];
  int dataIndex = 0;
  for (int index = 0; index < num; index++) {
    int msgDataIndex;
    for (msgDataIndex = 0; msgDataIndex < m[index].len; msgDataIndex++) {
      data[dataIndex + msgDataIndex] = m[index].data[msgDataIndex];
    }
    dataIndex += msgDataIndex;
  }
  Tx64Request tx = Tx64Request(chaseCarXBEEaddr, data, totalLenOfMessage);
  x->send(tx);
  return tx.getFrameId();
}



XBee xbee = XBee();
XBeeAddress64 chaseCarXBEE = XBeeAddress64(0x13A200, 0x405D032A);

XBeeMsg NULL_MESSAGE = {0,0};

int state = LISTENING;
unsigned long transitionStart = 0;
int beatCount = 0;

boolean waiting = 0;
unsigned long waitStart = 0;

unsigned long debuggingStart = 0;

boolean countingFlag = 0;
unsigned long baseTime = 0;
unsigned long previousTime = 0;

unsigned long packet_acks = 0;
unsigned long packet_nacks = 0;

uint8_t histogram[91];


unsigned long signalStart = 0;

void setup() {
    pinMode(DTR_PIN, OUTPUT);
    pinMode(RTS_PIN, OUTPUT);
    pinMode(CTS_PIN, INPUT);
    pinMode(SLEEP_PIN, INPUT);
    pinMode(DI01_PIN, INPUT);
    pinMode(RESET_PIN, OUTPUT);
    pinMode(OE_PIN, OUTPUT);
    
    pinMode(ASSOC_LED, OUTPUT);
    pinMode(DEBUG_LED1, OUTPUT);
    pinMode(DEBUG_LED2, OUTPUT);

    digitalWrite(DTR_PIN, HIGH);
    digitalWrite(RTS_PIN, LOW);
    digitalWrite(RESET_PIN, HIGH);
    digitalWrite(OE_PIN, HIGH);
    
    digitalWrite(ASSOC_LED, LOW);
    digitalWrite(DEBUG_LED1, LOW);
    digitalWrite(DEBUG_LED2, LOW);

    xbee.setSerial(Serial1);
    xbee.begin(115200);
    Serial.begin(115200);
    //Serial.println("Starting serial");
    //Can.begin(1000);
    CanBufferInit();
    Serial.println("Starting up");
    Serial.print("RX_64_RESPONSE = ");
    Serial.println((short)RX_64_RESPONSE);
    Serial.print("TX_STATUS_RESPONSE = ");
    Serial.println((short)TX_STATUS_RESPONSE);
}

void stateChange(int new_state, const char *reason) {
    Serial.print("SWITCHED from ");
    print_state(state);
    Serial.print(" to ");
    print_state(new_state);
    Serial.print(":");
    Serial.println(reason);
    state = new_state;
    if (state > TRANSITION)
        digitalWrite(ASSOC_LED, HIGH);
    else
        digitalWrite(ASSOC_LED, LOW);
}

void print_state(int state) {
  if (state == 0)
      Serial.print("LISTENING");
  else if (state == 1)
      Serial.print("TRANSITION");
  else if (state == 2)
      Serial.print("SENDING");
  else if (state == 3)
      Serial.print("DEBUGGING");
  else if (state == 4)
      Serial.print("SIGNALTEST");
}

//Responds to the heartbeat check from the chasecar
void emitHeartbeat() {
  //Serial.println("Heartbeat check FROM chase car");
  uint8_t hs5[] = {heartShake5};
  Tx64Request tx = Tx64Request(chaseCarXBEE, hs5, sizeof(hs5));
  xbee.send(tx);
  //Serial.println("Heartbeat check FROM car completed");
}
  
void Listening(uint8_t* data) {
  if (data != NULL) {
    if (data[0] == handShake1) {
      unsigned long time = millis();
      uint8_t hs2[5];
      hs2[0] = handShake2;
      encode((uint32_t) time, (uint8_t*) (hs2 + 1));
      Tx64Request tx = Tx64Request(chaseCarXBEE, hs2, sizeof(hs2));
      xbee.send(tx);
      Serial.println("Handshake 2 sent, entering transition mode");
      transitionStart = millis();
      stateChange(TRANSITION, "Got HS1, sent HS2");
    }
  }
}

void Transition(uint8_t* data) {
  if (data != NULL) {
    if (data[0] == handShake3) {
      //Serial.println("Handshake 3 received, entering sending mode");
      stateChange(SENDING, "Got handshake 3 - Associated.");
      return;
    }
  }
  
  long dt = millis() - transitionStart;
  if (dt > transitionLimit) {
    //Serial.println("Transition limit exceeded, entering listening mode");
    stateChange(LISTENING, "transition time exceeded");
  }
}

void Sending(uint8_t* data) {
  if (data != NULL) {
    if (data[0] == heartShake4) {
      emitHeartbeat();
    } else if (data[0] == heartShake5) {
      //Serial.println("Heartbeat check TO chase car complete");
      waiting = 0;
    } else if (data[0] == debuggingMode) {
      debuggingStart = millis();
      stateChange(DEBUGGING, "got debugging request");
      return;
    } else if (data[0] == handShake1) {
      waiting = 0;
      beatCount = 0;
      stateChange(LISTENING, "saw HS1, resetting");
      return;
    } else if (data[0] == signalTest) {
      signalStart = millis();
      stateChange(SIGNALTEST, "got signal test request");
      return;
    }
  }
  
  if (waiting == 1) {
    if ((millis() - waitStart) > waitLimit) {
      //Serial.println("Heartbeat check TO chase car timed out, entering listening mode");
      waiting = 0;
      stateChange(LISTENING, "HB Failed - Disassociated");
      return;
    }
  } else {
    if (beatCount > heartBeat) {
      beatCount = 0;
      uint8_t hs4[] = {heartShake4};
      Tx64Request tx = Tx64Request(chaseCarXBEE, hs4, sizeof(hs4));
      xbee.send(tx);
      waitStart = millis();
      //Serial.println("Heartbeat check TO chase car sent");
      waiting = 1;
    }
  }
  
  if (CanBufferSize() >= numPerPack) {
    Serial.println("Sending stuff");
    //Serial.println("CAN message obtained");
    //Serial.print("CAN Buffer: ");
    //Serial.println(CanBufferSize());
    XBeeMsg package[numPerPack];
    CanMessage can_msg;
    for (int i = 0; i < numPerPack; i++) {
      can_msg = CanBufferRead();
      initXBeeMsg(package + i, &can_msg);

    }
    sendXBeeMsgs(&xbee, chaseCarXBEE, package, numPerPack);
    Serial.println("Packet sent");
    
    //Serial.println("CAN message sent");
    if (waiting == 0) {
      beatCount++;
    }
  }
}

void Debugging(uint8_t* data, CanMessage *msg, long time) {
  if ((millis() - debuggingStart) > debuggingTime) {
    debuggingStart = 0;
    countingFlag = 0;
    previousTime = 0;
    stateChange(SENDING, "completed debugging query");
    return;
  }
  
  if (data != NULL) {
    if (data[0] == heartShake4) {
      emitHeartbeat();
    } else if (data[0] == heartShake5) {
      //Serial.println("Heartbeat check TO chase car complete");
      waiting = 0;
    } else if (data[0] == debuggingMode) {
      debuggingStart = millis();
    } else if (data[0] == handShake1) {
      waiting = 0;
      countingFlag = 0;
      previousTime = 0;
      stateChange(LISTENING, "saw handshake 1");
      return;
    }
  }

  if (waiting == 1) {
    if ((millis() - waitStart) > waitLimit) {
      //Serial.println("Heartbeat check TO chase car timed out, entering listening mode");
      waiting = 0;
      countingFlag = 0;
      previousTime = 0;
      stateChange(LISTENING, "heartbeat timed out");
      return;
    }
  } else {
    if (beatCount > heartBeat) {
      beatCount = 0;
      uint8_t hs4[] = {heartShake4};
      Tx64Request tx = Tx64Request(chaseCarXBEE, hs4, sizeof(hs4));
      xbee.send(tx);
      //Serial.println("Heartbeat check TO chase car sent");
      waiting = 1;
    }
  }
  
  if (msg != NULL) {
    if (countingFlag) {
      if ((time - baseTime) > (90*interval)) {
        histogram[0] = packetHistogram;
        Tx64Request tx = Tx64Request(chaseCarXBEE, histogram, 91);
        xbee.send(tx);
        countingFlag = 0;
        baseTime = 0;
        previousTime = 0;
        if (waiting == 0) {
          beatCount++;
        }
        return;
      }
      long timeDiff = time - previousTime;
      uint8_t index = timeDiff/interval;
      if (index < 90) {
        histogram[index+1] = histogram[index+1] + 1;
        previousTime = time;
      }
    } else {
      baseTime = time;
      countingFlag = 1;
      for (int i = 1; i < 91; i++) {
        histogram[i] = 0;
      }
    }
  }
}
  
void SignalTest(uint8_t* data) {
  if ((millis() - signalStart) > signalTime) {
    stateChange(SENDING, "done signaltest");
    return;
  }
  
  if (data != NULL) {
    if (data[0] == heartShake4) {
      emitHeartbeat();
    } else if (data[0] == heartShake5) {
      //Serial.println("Heartbeat check TO chase car complete");
      waiting = 0;
    } else if (data[0] == signalTest) {
      signalStart = millis();
    } else if (data[0] == handShake1) {
      waiting = 0;
      stateChange(LISTENING, "saw handshake 1");
      return;
    }
  }
  
  char *dummy_message = "\342Friday! Friday! Gotta get down on Friday!";
  uint8_t* dummy = (uint8_t*)dummy_message;
  Tx64Request tx = Tx64Request(chaseCarXBEE, dummy, 42);
  xbee.send(tx);
}
  

void loop() {
  //Serial.println("Entering loop");
  //Serial.print("CAN Buffer: ");
  //Serial.println(CanBufferSize());
  CanMessage msg;
  if ((state != SENDING) && (CanBufferSize())) {
    msg = CanBufferRead();
  }
  uint8_t*        msg_data = NULL;
  Rx64Response    data_resp;
  TxStatusResponse status_resp;
  if (xbee.readPacket(1)) {
    XBeeResponse& response = xbee.getResponse();
    Serial.print("Got api message w/id=");
    Serial.print((short)(response.getApiId()));
    Serial.print(" @t=");
    Serial.println(millis());
    if (response.getApiId() == RX_64_RESPONSE) {
      response.getRx64Response(data_resp);
      XBeeAddress64 sender = data_resp.getRemoteAddress64();
      //if ((sender.getMsb() == chaseCarXBEE.getMsb()) &&
      //    (sender.getLsb() == chaseCarXBEE.getLsb())) {
        msg_data = data_resp.getData();
      //}
    } else if (response.getApiId() == TX_STATUS_RESPONSE) {
      response.getTxStatusResponse(status_resp);
      if (status_resp.isSuccess()) {
        Serial.println("Packet sent successfully");
        packet_acks++;
      } else {
        Serial.println("Packet didn't get through");
        packet_nacks++;
      }
    }
  }
  
  long time = millis();
  
  switch (state) {
    case LISTENING:
      Listening(msg_data);
      break;
    
    case TRANSITION:
      Transition(msg_data);
      break;
    
    case SENDING:
      Sending(msg_data);
      break;
      
    case DEBUGGING:
      Debugging(msg_data, &msg, time);
      break;
      
    case SIGNALTEST:
      SignalTest(msg_data);
      break;
  }
}
