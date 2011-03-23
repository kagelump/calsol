#include <XBee.h>

#define DTR_PIN 16
#define RTS_PIN 13
#define CTS_PIN 14
#define SLEEP_PIN 15
#define DI01_PIN 12
#define RESET_PIN 17
#define OE_PIN 18

#define LISTENING 0
#define TRANSITION 1
#define SENDING 2

XBee xbee = XBee();
XBeeAddress64 chaseCarXBEEaddr = XBeeAddress64(0x13A200, 0x405D032A);
XBeeAddress64 brainXBEE = XBeeAddress64(0x0013A2, 0x0040621D3B);

int state = LISTENING;
int count = 0;
int transitionLimit = 5;
int dataLimit = 10;
int heartBeat = 20;
int beatCount = 0;

int handShake1 = 0x81;
int handShake2 = 0x82;
int handShake3 = 0x83;

int heartShake4 = 0x84;
int heartShake5 = 0x85;

boolean unhandledBeat = 0;

/**
 *  Modifies the dest array to encode the int src
 *  @param src   - The data to be encoded. Assumes 32-bit ints
 *  @param dest - The array to store the encoded data. 
 *                Expects room for at least 4 bytes.
 */ 
void encode(uint32_t src, uint8_t* dest) {
  dest[0] = encodeFirstByte(src);
  dest[1] = encodeSecondByte(src);
  dest[2] = encodeThirdByte(src);
  dest[3] = encodeFourthByte(src);
}

/**
 *  Modifiers the dest pointer to decode the dest array
 *  @param src   - The pointer to the data to decode. Must have
 *                 at least 4 bytes of data.
 *  @param dest  - A pointer to the memory location that will
 *                 contain the decoded message
 */
void decode(uint8_t* src, uint32_t* dest) {
  decodeFirstByte(src, dest);
  decodeSecondByte(src, dest);
  decodeThirdByte(src, dest);
  decodeFourthByte(src, dest);
}

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
	xbee.begin(57600);
        Serial.begin(57600);
        Serial.println("Starting serial");
        Can.begin(1000);
        CanBufferInit();
        Serial.println("Starting CAN");
}

void loop() {
  Serial.println("Entering loop");
  switch (state)
  {
    case LISTENING:
    {
    Serial.println("Listening mode");

    if (xbee.readPacket(5000)) {
      XBeeResponse response = xbee.getResponse();
      Serial.print("Packet read of type: ");
      short id = response.getApiId();
      Serial.println(id);
      if (response.getApiId() == RX_64_RESPONSE) {
        Rx64Response command;
        response.getRx64Response(command);
        uint8_t* data = command.getData();
        XBeeAddress64 sender = command.getRemoteAddress64();
        Serial.print("Sender Address: ");
        Serial.print(sender.getMsb());
        Serial.println(sender.getLsb());
        Serial.print("Data: ");
        short dat1 = data[0];
        Serial.println(dat1);
        if ((sender.getMsb() == chaseCarXBEEaddr.getMsb()) && (sender.getLsb() == chaseCarXBEEaddr.getLsb()) && (data[0] == handShake1)) {
          Serial.println("Handshake 1 complete, sending handshake 2");
          //Handshake 1 received, request handshake 2
          long time = millis();
          uint8_t hs2[5];
          hs2[0] = handShake2;
          encode(time, (hs2 + 1));
          Tx64Request tx = Tx64Request(chaseCarXBEEaddr, hs2, sizeof(hs2));
          TxStatusResponse txStatus = TxStatusResponse();
          xbee.send(tx);
          if (xbee.readPacket(5000)) {
            if (xbee.getResponse().getApiId() == TX_STATUS_RESPONSE) {
              xbee.getResponse().getTxStatusResponse(txStatus);
              if (txStatus.isSuccess()) {
                //Handshake 2 sending success, switch to transition mode
                Serial.println("Entering transition mode");
                state = TRANSITION;
              }
            }
          }
        }
      }
    }
    break;
    }
    
    case TRANSITION:
    {
    Serial.println("Transition mode");
    if (xbee.readPacket(5000)) {
      XBeeResponse response = xbee.getResponse();
      Serial.print("Packet read of type: ");
      short id = response.getApiId();
      Serial.println(id);
      if (response.getApiId() == RX_64_RESPONSE) {
        Rx64Response command;
        response.getRx64Response(command);
        uint8_t* data = command.getData();
        XBeeAddress64 sender = command.getRemoteAddress64();
        Serial.print("Sender Address: ");
        Serial.print(sender.getMsb());
        Serial.println(sender.getLsb());
        Serial.print("Data: ");
        short dat2 = data[0];
        Serial.println(dat2);
        if ((sender.getMsb() == chaseCarXBEEaddr.getMsb()) && (sender.getLsb() == chaseCarXBEEaddr.getLsb()) && (data[0] == handShake3)) {
          Serial.println("Handshake 3 complete, entering sending mode");
          //Handshake 3 received, switch to sending mode
          count = 0;
          state = SENDING;
          break;
        }
      }
    }
    //If anything above failed, increment the failure counter
    count++;
    if (count > transitionLimit) {
      //If failure counter exceeded, revert to listening state
      Serial.println("Transition limit exceeded, entering listening mode");
      count = 0;
      state = LISTENING;
    }
    break;
    }
    
    case SENDING:
    {
    Serial.println("Sending mode");

    //Heartbeat check FROM car
    if (unhandledBeat || xbee.readPacket(0)) {
      unhandledBeat = 0;
      Serial.println("Message FROM chase car");
      XBeeResponse response = xbee.getResponse();
      if (response.getApiId() == RX_64_RESPONSE) {
        Rx64Response command;
        response.getRx64Response(command);
        uint8_t* data = command.getData();
        XBeeAddress64 sender = command.getRemoteAddress64();
        if ((sender.getMsb() == chaseCarXBEEaddr.getMsb()) && (sender.getLsb() == chaseCarXBEEaddr.getLsb()) && (data[0] == heartShake4)) {
          Serial.println("Heartbeat check FROM chase car");
          uint8_t hs5[] = {heartShake5};
          Tx64Request tx = Tx64Request(chaseCarXBEEaddr, hs5, sizeof(hs5));
          TxStatusResponse txStatus = TxStatusResponse();
          xbee.send(tx);
          if (xbee.readPacket(5000)) {
            XBeeResponse response2 = xbee.getResponse();
            if (response2.getApiId() == TX_STATUS_RESPONSE) {
              response2.getTxStatusResponse(txStatus);
              if (txStatus.isSuccess()) {
                Serial.println("Heartbeat check FROM car completed");
                break;
              }
            }
          }
        }
      }
    }
    
    //Heartbeat check TO car
    if (beatCount > heartBeat) {
      Serial.println("Heartbeat check TO chase car");
      uint8_t hs4[] = {heartShake4};
      Tx64Request tx = Tx64Request(chaseCarXBEEaddr, hs4, sizeof(hs4));
      TxStatusResponse txStatus = TxStatusResponse();
      xbee.send(tx);
      if (xbee.readPacket(5000)) {
        XBeeResponse response = xbee.getResponse();
        
        //If packet was an unread heartbeat check
        if (response.getApiId() == RX_64_RESPONSE) {
          Rx64Response command;
          response.getRx64Response(command);
          uint8_t* data = command.getData();
          XBeeAddress64 sender = command.getRemoteAddress64();
          if ((sender.getMsb() == chaseCarXBEEaddr.getMsb()) && (sender.getLsb() == chaseCarXBEEaddr.getLsb()) && (data[0] == heartShake4)) {
            Serial.println("Interrupted by heartbeat FROM chase car");
            unhandledBeat = 1;
            break;
          }
        }
        
        if (response.getApiId() == TX_STATUS_RESPONSE) {
          response.getTxStatusResponse(txStatus);
          if (txStatus.isSuccess()) {
            Serial.println("Heartbeat check TO chase car sent");
            if (xbee.readPacket(10000)) {
              XBeeResponse response2 = xbee.getResponse();
              if (response2.getApiId() == RX_64_RESPONSE) {
                Rx64Response command;
                response2.getRx64Response(command);
                uint8_t* data = command.getData();
                XBeeAddress64 sender = command.getRemoteAddress64();
                
                if ((sender.getMsb() == chaseCarXBEEaddr.getMsb()) && (sender.getLsb() == chaseCarXBEEaddr.getLsb()) && (data[0] == heartShake4)) {
                  unhandledBeat = 1;
                  Serial.println("Interrupted by heartbeat FROM chase car");
                  break;
                }
                
                if ((sender.getMsb() == chaseCarXBEEaddr.getMsb()) && (sender.getLsb() == chaseCarXBEEaddr.getLsb()) && (data[0] == heartShake5)) {
                  Serial.println("Hearbeat check TO chase car complete");
                  beatCount = 0;
                  break;
                }
              }
            }
          }
        }
      }
      Serial.println("Heartbeat check TO chase car failed, entering listening mode");
      beatCount = 0;
      unhandledBeat = 0;
      count = 0;
      state = LISTENING;
      break;
    }
    
    //Sending CAN messages
    if (CanBufferSize()) {
      //A CAN message is ready to be sent
      CanMessage msg = CanBufferRead();
      Serial.println("CAN message obtained");
      uint8_t message[14];
      uint16_t id = msg.id;
      uint8_t len = msg.len;
      uint16_t preamble = (id << 4) | len;
      message[0] = (uint8_t)(preamble);
      message[1] = (uint8_t)(preamble >> 8);
      long now = millis();
      encode((uint32_t) now, (message + 2));
      
      for (int iii = 0; iii < msg.len; iii++) {
        message[iii + 6] = msg.data[iii];
      }
      Tx64Request tx = Tx64Request(chaseCarXBEEaddr, message, msg.len + 6);
      TxStatusResponse txStatus = TxStatusResponse();
      
      xbee.send(tx);
      if (xbee.readPacket(5000)) {
        XBeeResponse response = xbee.getResponse();
        
        //If packet was an unread heartbeat check
        if (response.getApiId() == RX_64_RESPONSE) {
          Rx64Response command;
          response.getRx64Response(command);
          uint8_t* data = command.getData();
          XBeeAddress64 sender = command.getRemoteAddress64();
          if ((sender.getMsb() == chaseCarXBEEaddr.getMsb()) && (sender.getLsb() == chaseCarXBEEaddr.getLsb()) && (data[0] == heartShake4)) {
            Serial.println("Interrupted by heartbeat FROM chase car");
            unhandledBeat = 1;
            break;
          }
        }
        
        if (response.getApiId() == TX_STATUS_RESPONSE) {
          response.getTxStatusResponse(txStatus);
          if (txStatus.isSuccess()) {
            Serial.println("CAN message delivered");
            beatCount++;
            count = 0;
            break;
          }
        }
      }
      
      //If packet sending failed, increment the failure counter
      count++;
      if (count > dataLimit) {
        //If failure counter exceeded, revert to listening state
        beatCount = 0;
        unhandledBeat = 0;
        count = 0;
        state = LISTENING;
      }
    }
    
//    if (Can.available()) {
//    uint8_t message[14];
//    uint16_t id = 0x401;
//    uint8_t len = 8;
//    uint16_t preamble = (id << 4) | len;
//    float velocity = 14.0;
//    float current = 0.80;
//    uint32_t* p_velocity = (uint32_t*) &velocity;
//    uint32_t* p_current = (uint32_t*) &current;
//    long now = millis();
//    
//    message[0] = (uint8_t)(preamble);
//    message[1] = (uint8_t)(preamble >> 8);
////    message[2] = firstByte(now);
////    message[3] = secondByte(now);
////    message[4] = thirdByte(now);
////    message[5] = fourthByte(now);
//    encode((uint32_t) now, (message + 2));
////    message[6] = firstByte(velocity);
////    message[7] = secondByte(velocity);
////    message[8] = thirdByte(velocity);
////    message[9] = fourthByte(velocity);
//    encode(*p_current, (message + 6));
////    message[10] = firstByte(current);
////    message[11] = secondByte(current);
////    message[12] = thirdByte(current);
////    message[13] = fourthByte(current);
//    encode(*p_velocity, (message + 10));
//    
//    Tx64Request tx = Tx64Request(chaseCarXBEEaddr, message, sizeof(message));
//    TxStatusResponse txStatus = TxStatusResponse();
//    xbee.send(tx);
//    if (xbee.readPacket(5000)) {
//      if (xbee.getResponse().getApiId() == TX_STATUS_RESPONSE) {
//        xbee.getResponse().getTxStatusResponse(txStatus);
//        if (txStatus.isSuccess()) {
//          Serial.println("Data sent");
//          count = 0;
//          beatCount++;
//          break;
//        }
//      }
//    }
//    
//    count++;
//    if (count > dataLimit) {
//      Serial.println("Data limit exceeded, entering listening mode");
//      count = 0;
//      state = LISTENING;
//    }
//    }
    
    break;
    }
    
    default:
    Serial.println("Error");
  }
}

