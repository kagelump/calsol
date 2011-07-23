#include "constants.h"
//#define DEBUG

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

    Serial1.begin(57600);
    Serial.begin(115200);
    //Serial.println("Starting serial");
    Can.begin(1000);
    CanBufferInit();
    Serial.println("Starting up");
}
const uint8_t START_CHAR = 0xE7;
const uint8_t ESCAPE_CHAR = 0x75;

uint8_t isSpecialChar(uint8_t data) {
    return (data == START_CHAR) || (data == ESCAPE_CHAR);
}

/**
 * Takes in a ptr to a string to encode into, and a data byte
 * to encode. Returns a pointer to the next spot in the string.
 */
char* encode(char* ptr, uint8_t data) {
    if (isSpecialChar(data)) {
        *ptr++ = ESCAPE_CHAR;
        *ptr++ = ESCAPE_CHAR ^ data;
    } else {
        *ptr++ = data;
    }
    return ptr;
}


uint16_t createPreamble(uint16_t id, uint8_t len) {
    return id << 4 | len;
}

/**
 * Copies len amount of characters of src to dst. If len is -1,
 * copies src as a string.
 */
void strcpy(char* dst, char* src, uint32_t len) {
    if (len == -1) {
        while(src)
            *dst++ = *src++;
        *dst = 0;
    } else {
        for (int i = 0; i < len; i++) {
            dst[i] = src[i];
        }
    }
}

/**
 * Takes in the id and len of the raw message and puts it in msg.
 */
void initMsg(char* msg, uint16_t id, uint8_t len, uint8_t* data) {
    uint16_t preamble = createPreamble(id, len);
    msg[0] = (uint8_t) preamble;
    msg[1] = (uint8_t) (preamble >> 8);
    strcpy(msg+2, (char*)data, len);
}

/**
 * Creates in dst the message contained in src with proper start symbol
 * and escape sequences. Return the len of the new message.
 */
uint32_t createEscapedMessage(char* dst, char* src, uint32_t len) {
    char* start = dst;
    *dst++ = START_CHAR;
    for (uint32_t i = 0; i < len; i++) {
        dst = encode(dst, src[i]);
    }
    return dst - start;
}

typedef struct {
  uint16_t id;
  uint8_t len;
  uint8_t data[16];
} fakeCanMsg;

fakeCanMsg m1 = (fakeCanMsg) {0x100, 4, "foob"};

uint8_t messageAvailable() {
  // debug:
#ifdef DEBUG
  return 1;
#endif
  // Actual:
#ifndef DEBUG
  return CanBufferSize() > 0;
#endif
}

void loop() {
    char msg[32], buf[64], *ptr = buf;
    if (messageAvailable()) {
        // Debug test 1:
//        uint16_t can_id = 0;
//        uint8_t* data = (uint8_t*) "Jimmy's moment.";
//        uint8_t data_len = 15;
        // Debug test 2:
#ifdef DEBUG
        uint16_t can_id = m1.id;
        uint8_t* data = m1.data;
        uint8_t data_len = m1.len;
#endif
        // Actual test -- don't forget to change messageAvailable!
#ifndef DEBUG
        CanMessage can_msg = CanBufferRead();
        uint16_t can_id = can_msg.id;
        uint8_t* data = (uint8_t*) can_msg.data;
        uint8_t data_len = can_msg.len;
#endif
        initMsg(msg, can_id, data_len, data);
        uint32_t buf_len = createEscapedMessage(buf, msg, data_len + 2);
        for (int i = 0; i < buf_len; i++) {
            Serial1.write(buf[i]);
        }
    }
}
