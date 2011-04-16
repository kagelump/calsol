typedef struct {
  uint8_t data[14];
  uint8_t len;
} XBeeMsg;

#include <stdint.h>

uint8_t encodeFirstByte(uint32_t a);
void decodeFirstByte(uint8_t* src, uint32_t* p32_dest);
uint8_t encodeSecondByte(uint32_t a);
void decodeSecondByte(uint8_t* src, uint32_t* p32_dest);
uint8_t encodeThirdByte(uint32_t a);
void decodeThirdByte(uint8_t* src, uint32_t* p32_dest);
uint8_t encodeFourthByte(uint32_t a);
void decodeFourthByte(uint8_t* src, uint32_t* p32_dest);

void encode(uint32_t src, uint8_t* dest);
void decode(uint8_t* src, uint32_t* dest);

void encodePreamble(XBeeMsg *m, uint16_t id, uint8_t len);
void encodeTime(XBeeMsg *m, long currentTime);
void encodeCanData(XBeeMsg *m, const uint8_t *data);
void initXBeeMsg(XBeeMsg *xbee_msg, CanMessage *can_msg);

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

void initXBeeMsg(XBeeMsg* xbee_msg, CanMessage* can_msg) {
  encodePreamble(xbee_msg, can_msg->id, can_msg->len);
  encodeTime(xbee_msg, millis());
  encodeCanData(xbee_msg, (uint8_t *)(can_msg->data));
}
