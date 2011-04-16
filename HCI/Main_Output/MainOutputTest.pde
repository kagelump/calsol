// Port definitions
#define OUT_RIGHT_TURN  15
#define OUT_LEFT_TURN   16
#define OUT_STROBE      17
#define OUT_HORN        18
#define OUT_BRAKE       19
#define OUT_REVERSE     20

// Can IDs
#define buttonsID       0x481
#define HEARTBEAT_ID 0x43

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

void setup(){
  initPins();
  Can.begin(1000);     // Turn CAN on at 500 kbits/Sec
  Serial.begin(115200); // Turn on Serial communication
  CanBufferInit();    // Initialize the buffer, turn on interrupts.
}

void loop(){
  // Receive Messages
  if (CanBufferSize()) {
    CanMessage msg = CanBufferRead();
    if (msg.id == buttonsID) {
      updateInputs(msg.data);
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
  // 3.937 hz function
  if (millis() - lastSignalMillis >= 254) {
    // Send out a heartbeat signal, to signal we're still alive
    heartbeat();
    // Toggle signal lights, if they're set to on
    if (signal_states[SIGNAL_RIGHT_TURN])
      digitalWrite(OUT_RIGHT_TURN, !digitalRead(OUT_RIGHT_TURN))
    else if (signal_states[SIGNAL_LEFT_TURN])
      digitalWrite(OUT_LEFT_TURN, !digitalRead(OUT_LEFT_TURN))
    lastSignalMillis = millis();
  }
}

void init_pins(){
  pinMode(RTURN,    OUTPUT);
  pinMode(LTURN,    OUTPUT);
  pinMode(STROBE,   OUTPUT);
  pinMode(HORN,     OUTPUT);
  pinMode(BRAKE,    OUTPUT);
  pinMode(REVERSE,  OUTPUT);
}

// Gets called whenever we receive a CAN message, to change the internal state
void update_state(char * data) {
  for (int i = 0; i < 6; i++) {
    if (data[i] != signal_state[i]) {
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
      break;
    case SIGNAL_LEFT_TURN:                  // Left Turn Signal
      if (!new_state)                       // If we're turning the light off
        digitalWrite(OUT_LEFT_TURN, LOW);
      else
        lastSignalMillis = millis() + 255;  // This will activate toggling
      break;
    case SIGNAL_STROBE:                     // Strobe Signal (TODO: MAKE BLINK)
      digitalWrite(new_state, OUT_STROBE);
      break;
    case SIGNAL_BRAKE:                      // Brake Light
      digitalWrite(new_state, OUT_BRAKE);
      break;
    case SIGNAL_REVERSE:                    // Reverse Light (DNE YET)
      digitalWrite(new_state, OUT_REVERSE);
      break;
    default:
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
}
