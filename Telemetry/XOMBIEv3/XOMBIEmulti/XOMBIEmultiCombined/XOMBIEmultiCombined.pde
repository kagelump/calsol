#include <XBee.h>
#include "constants.h"
#include "pack.h"

uint8_t encodeFirstByte(uint32_t a) {
  uint32_t* p_a = &a;
  uint8_t* p_b = (uint8_t*) p_a;
  return *p_b;
}

void decodeFirstByte(uint8_t* src, uint32_t* p32_dest) {
  uint8_t* p8_dest = (uint8_t*) p32_dest;
  *p8_dest = *src;
}

uint8_t encodeSecondByte(uint32_t a) {
  uint32_t* p_a = &a;
  uint8_t* p_b = (uint8_t*) p_a;
  return *(p_b + 1);
}

void decodeSecondByte(uint8_t* src, uint32_t* p32_dest) {
  uint8_t* p8_dest = (uint8_t*) p32_dest;
  *(p8_dest + 1) = *(src + 1);
}

uint8_t encodeThirdByte(uint32_t a) {
  uint32_t* p_a = &a;
  uint8_t* p_b = (uint8_t*) p_a;
  return *(p_b + 2);
}

void decodeThirdByte(uint8_t* src, uint32_t* p32_dest) {
  uint8_t* p8_dest = (uint8_t*) p32_dest;
  *(p8_dest + 2) = *(src + 2);
}

uint8_t encodeFourthByte(uint32_t a) {
  uint32_t* p_a = &a;
  uint8_t* p_b = (uint8_t*) p_a;
  return *(p_b + 3);
}

void decodeFourthByte(uint8_t* src, uint32_t* p32_dest) {
  uint8_t* p8_dest = (uint8_t*) p32_dest;
  *(p8_dest + 3) = *(src + 3);
}

void encodePreamble(XBeeMsg *m, uint16_t id, uint8_t len) {
  uint16_t preamble = (id << 4) | len;
  m->data[0] = (uint8_t)(preamble);
  m->data[1] = (uint8_t)(preamble >> 8);
  m->len = len + 6;
}

void encodeTime(XBeeMsg *m, long currentTime) {
  encode((uint32_t) currentTime, m->data + 2);
}

void encodeCanData(XBeeMsg *m, const uint8_t *data) {
  for (int iii = 0; iii < m->len - 6; iii++) {
    m->data[iii + 6] = data[iii];
  }
}

void initXBeeMsg(XBeeMsg *m, CanMessage *msg) {
  encodePreamble(m, msg->id, msg->len);
  encodeTime(m, millis());
  encodeCanData(m, (uint8_t *) msg->data);
}

uint8_t sendXBeeMsgs(XBee *x, XBeeAddress64 chaseCarXBEEaddr, XBeeMsg **m, uint32_t num) {
  uint32_t totalLenOfMessage = 0;
  for (int index = 0; index < num; index++)
    totalLenOfMessage += (*(m + index))->len;
  uint8_t data[totalLenOfMessage];
  int dataIndex = 0;
  for (int index = 0; index < num; index++) {
    int msgDataIndex;
    for (msgDataIndex = 0; msgDataIndex < (*(m + index))->len; msgDataIndex++) {
      data[dataIndex + msgDataIndex] = (*(m + index))->data[msgDataIndex];
    }
    dataIndex += msgDataIndex;
  }
  Tx64Request tx = Tx64Request(chaseCarXBEEaddr, data, totalLenOfMessage);
  x->send(tx);
  return tx.getFrameId();
}

void encode(uint32_t src, uint8_t* dest) {
  dest[0] = encodeFirstByte(src);
  dest[1] = encodeSecondByte(src);
  dest[2] = encodeThirdByte(src);
  dest[3] = encodeFourthByte(src);
}

void decode(uint8_t* src, uint32_t* dest) {
  decodeFirstByte(src, dest);
  decodeSecondByte(src, dest);
  decodeThirdByte(src, dest);
  decodeFourthByte(src, dest);
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

boolean debuggingFlag = 0;
boolean countingFlag = 0;
unsigned long baseTime = 0;
unsigned long previousTime = 0;

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

    digitalWrite(DTR_PIN, HIGH);
    digitalWrite(RTS_PIN, LOW);
    digitalWrite(RESET_PIN, HIGH);
    digitalWrite(OE_PIN, HIGH);

    xbee.setSerial(Serial1);
    xbee.begin(115200);
    Serial.begin(115200);
    //Serial.println("Starting serial");
    Can.begin(500);
    CanBufferInit();
    //Serial.println("Starting CAN");
}

void stateChange(int new_state, const char *reason) {
    Serial.print("SWITCHED from ");
    print_state(state);
    Serial.print(" to ");
    print_state(new_state);
    Serial.print(":");
    Serial.println(reason);
    state = new_state;
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
void handleHeartBeat() {
  //Serial.println("Heartbeat check FROM chase car");
  uint8_t hs5[] = {heartShake5};
  Tx64Request tx = Tx64Request(chaseCarXBEE, hs5, sizeof(hs5));
  xbee.send(tx);
  //Serial.println("Heartbeat check FROM car completed");
}
  
void Listening(XBeeResponse* p_resp, uint8_t* data) {
  if (p_resp != NULL) {
    Serial.println("Got a message in Listening!");
    if (data[0] == handShake1) {
      //Serial.println("Handshake 1 received, sending handshake 2");
      long time = millis();
      uint8_t hs2[5];
      hs2[0] = handShake2;
      encode((uint32_t) time, (uint8_t*) (hs2 + 1));
      Tx64Request tx = Tx64Request(chaseCarXBEE, hs2, sizeof(hs2));
      xbee.send(tx);
      //Serial.println("Handshake 2 sent, entering transition mode");
      transitionStart = millis();
      stateChange(TRANSITION, "Sent handshake 2");
    }
  }
}

void Transition(XBeeResponse* p_resp, uint8_t* data) {
  if (p_resp != NULL) {
    Serial.println("Got a message in Transition!");
    if (data[0] == handShake3) {
      //Serial.println("Handshake 3 received, entering sending mode");
      stateChange(SENDING, "Got handshake 3");
      return;
    }
  }
  
  long dt = millis() - transitionStart;
  if (dt > transitionLimit) {
    //Serial.println("Transition limit exceeded, entering listening mode");
    stateChange(LISTENING, "transition time exceeded");
  }
}

void Sending(XBeeResponse* p_resp, uint8_t* data) {
  if (p_resp != NULL) {
    Serial.println("Got a message in Sending!");
    if (data[0] == heartShake4) {
      handleHeartBeat();
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
      stateChange(LISTENING, "saw a handshake 1");
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
      stateChange(LISTENING, "heartbeat timed out");
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
  
  if (CanBufferSize() > numPerPack-1) {
    //Serial.println("CAN message obtained");
    //Serial.print("CAN Buffer: ");
    //Serial.println(CanBufferSize());
    XBeeMsg* package[numPerPack];
    for (int i = 0; i < numPerPack; i++) {
      XBeeMsg *m;
      initXBeeMsg(m, &CanBufferRead());
      package[i] = m;
    }
    sendXBeeMsgs(&xbee, chaseCarXBEE, package, numPerPack);
    
    //Serial.println("CAN message sent");
    if (waiting == 0) {
      beatCount++;
    }
  }
}

void Debugging(XBeeResponse* p_resp, uint8_t* data,
               CanMessage *msg, long time) {
  if ((millis() - debuggingStart) > debuggingTime) {
    debuggingStart = 0;
    countingFlag = 0;
    previousTime = 0;
    stateChange(SENDING, "completed debugging query");
    return;
  }
  
  if (p_resp != NULL) {
    if (data[0] == heartShake4) {
      handleHeartBeat();
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
  
void SignalTest(XBeeResponse* p_resp, uint8_t* data) {
  if ((millis() - signalStart) > signalTime) {
    stateChange(SENDING, "done signaltest");
    return;
  }
  
  if (p_resp != NULL) {
    if (data[0] == heartShake4) {
      handleHeartBeat();
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
  CanMessage *msg = NULL;
  if ((state != SENDING) && (CanBufferSize())) {
    msg = &CanBufferRead();
  }
  XBeeResponse  response;
  XBeeResponse* p_resp = NULL;
  Rx64Response  command;
  uint8_t*      msg_data = NULL;
  if (xbee.readPacket(1)) {
    response = xbee.getResponse();
    Serial.print("Got api message w/id=");
    Serial.println((short)(response.getApiId()));
    if (response.getApiId() == RX_64_RESPONSE) {
      response.getRx64Response(command);
      XBeeAddress64 sender = command.getRemoteAddress64();
      if ((sender.getMsb() == chaseCarXBEE.getMsb()) &&
          (sender.getLsb() == chaseCarXBEE.getLsb())) {
        p_resp = &response;
        msg_data = command.getData();
      }
    }
  }
  
  long time = millis();
  
  switch (state) {
    case LISTENING:
      Listening(p_resp, msg_data);
      break;
    
    case TRANSITION:
      Transition(p_resp, msg_data);
      break;
    
    case SENDING:
      Sending(p_resp, msg_data);
      break;
      
    case DEBUGGING:
      Debugging(p_resp, msg_data, msg, time);
      break;
      
    case SIGNALTEST:
      SignalTest(p_resp, msg_data);
      break;
  }
}
