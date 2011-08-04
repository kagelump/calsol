#define DTR_PIN 16
#define RTS_PIN 13
#define CTS_PIN 14
#define SLEEP_PIN 15
#define DI01_PIN 12
#define RESET_PIN 17
#define OE_PIN 18

#define ASSOC_LED 0
#define DEBUG_LED1 19
#define DEBUG_LED2 20

#define LISTENING 0
#define TRANSITION 1
#define SENDING 2
#define DEBUGGING 3
#define SIGNALTEST 4

unsigned long transitionLimit = 5000;
unsigned long waitLimit = 5000;

int handShake1 = 0x81;
int handShake2 = 0x82;
int handShake3 = 0x83;
int heartShake4 = 0x84;
int heartShake5 = 0x85;

int heartBeat = 100;
int maxFailedBeats = 3;

int numPerPack = 4;

int debuggingMode = 0xC1;
unsigned long debuggingTime = 10000;

long interval = 5;
int packetHistogram = 0xC2;

int signalTest = 0xE1;
int dummyPacket = 0xE2;
unsigned long signalTime = 10000;
