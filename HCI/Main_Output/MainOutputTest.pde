// Port definitions
#define OUT_RIGHT_TURN  15
#define OUT_LEFT_TURN   16
#define OUT_STROBE      17
#define OUT_HORN        18
#define OUT_BRAKE       19
#define OUT_REVERSE     20
#define OUT_HEARTBEAT   22

// Can IDs
#define BUTTONS_ID        0x481
#define HEARTBEAT_ID     0x43

// Debug
#define DEBUG

//0:RTurn 1:LTurn 2:Strobe 3:Horn 4:brake 5:reverse
enum SignalIds {
  SIGNAL_RIGHT_TURN,
  SIGNAL_LEFT_TURN,
  SIGNAL_STROBE,
  SIGNAL_HORN,
  SIGNAL_BRAKE,
  SIGNAL_REVERSE
};

// State variables
char signal_states[6];
long lastSignalMillis = 0;

void setup() {
  init_pins();
  Can.begin(1000);     // Turn CAN on at 500 kbits/Sec
  Serial.begin(115200); // Turn on Serial communication
  CanBufferInit();    // Initialize the buffer, turn on interrupts.
}

void loop(){
  // Receive Messages
  if (CanBufferSize()) {
    CanMessage msg = CanBufferRead();
    if (msg.id == BUTTONS_ID) {
      update_state(msg.data);
      #ifdef DEBUG
        Serial.println("We got message from main input board ");
        Serial.print(msg.data[0] & 0xFF, HEX);
        Serial.println(msg.data[1] & 0xFF, HEX);
        Serial.println(msg.data[2] & 0xFF, HEX);
        Serial.println(msg.data[3] & 0xFF, HEX);
        Serial.println(msg.data[4] & 0xFF, HEX);
        Serial.println(msg.data[5] & 0xFF, HEX);
        Serial.println(msg.data[6] & 0xFF, HEX);
        Serial.println(msg.data[7] & 0xFF, HEX);
      #endif
    }
  }
  // 3.937 hz function
  if (millis() - lastSignalMillis >= 254) {
    // Send out a heartbeat signal, to signal we're still alive
    heartbeat();
    // Toggle signal lights, if they're set to on
    if (signal_states[SIGNAL_RIGHT_TURN])
      digitalWrite(OUT_RIGHT_TURN, !digitalRead(OUT_RIGHT_TURN));
    else if (signal_states[SIGNAL_LEFT_TURN])
      digitalWrite(OUT_LEFT_TURN, !digitalRead(OUT_LEFT_TURN));
    lastSignalMillis = millis();
  }
}

void init_pins() {
  pinMode(OUT_RIGHT_TURN, OUTPUT);
  pinMode(OUT_LEFT_TURN,  OUTPUT);
  pinMode(OUT_STROBE,     OUTPUT);
  pinMode(OUT_HORN,       OUTPUT);
  pinMode(OUT_BRAKE,      OUTPUT);
  pinMode(OUT_REVERSE,    OUTPUT);
  pinMode(OUT_HEARTBEAT,  OUTPUT);
}

// Gets called whenever we receive a CAN message, to change the internal state
void update_state(char * data) {
  for (int i = 0; i < 6; i++) {
    if (data[i] != signal_states[i]) {
      update_state(data[i], i);
    }
  }
}

// Helper function, changes internal state
void update_state(char new_state, int index) {
  switch (index) {
    case SIGNAL_RIGHT_TURN:                 // Right Turn Signal
      if (!new_state)                       // If we're turning the light off
        digitalWrite(OUT_RIGHT_TURN, LOW);
      else
        lastSignalMillis = millis() + 255;  // This will activate toggling
      signal_states[SIGNAL_LEFT_TURN] = 0;  // Turning off opposite signal regardless
      break;
    case SIGNAL_LEFT_TURN:                  // Left Turn Signal
      if (!new_state)                       // If we're turning the light off
        digitalWrite(OUT_LEFT_TURN, LOW);
      else
        lastSignalMillis = millis() + 255;  // This will activate toggling
      signal_states[SIGNAL_RIGHT_TURN] = 0;  // Turning off opposite signal regardless
      break;
    case SIGNAL_STROBE:                     // Strobe Signal (TODO: MAKE BLINK)
      digitalWrite(OUT_STROBE, new_state);
      break;
    case SIGNAL_BRAKE:                      // Brake Light
      digitalWrite(OUT_BRAKE, new_state);
      break;
    case SIGNAL_REVERSE:                    // Reverse Light (DNE YET)
      digitalWrite(OUT_REVERSE, new_state);
      break;
    default:
      break;
  }
  signal_states[index] = new_state;
}

// Sends out a heartbeat signal
void heartbeat() {
  CanMessage msg = CanMessage();
  msg.id = HEARTBEAT_ID;
  msg.data[0] = 0;
  msg.len = 1;
  Can.send(msg);
  digitalWrite(OUT_HEARTBEAT, !digitalRead(OUT_HEARTBEAT));
}
