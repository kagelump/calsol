// Targetted for the Main Input Board
// Only basic functionality present (pedals).
// Written by: Ryan Tseng

// Pin declarations
#define ACCEL_ANALOGIN 27
#define BRAKE_ANALOGIN 28

// Global Variables
long last_time;

// Global Typedefs
typedef union {
  char c[8];
  float f[2];
} two_floats;

void setup() {
  // Communication
  Can.begin(1000);
  Serial.begin(115200);
  
  // Global Initilization
  last_time = millis();
  
  // Send Reset commmand to Tritium
  Can.send(CanMessage(0x403));
  delay(100);
  
  // Send Motor power command to Tritium
  two_floats packet;
  packet.f[1] = 1.0;  // 100% of bus power
  Can.send(CanMessage(0x402, packet.c));
}

void loop() {
  if (millis() - last_time > 100) {
    last_time = millis();
    // Get pedal position (0 - 1023).  fAccel is 0.0 - 1.0
    int accel = analogRead(ACCEL_ANALOGIN);
    float fAccel = (float) accel / 1023.0;
    
    // Prepare and send Can Message. 0 is velocity, 1 is power.
    Serial.println(fAccel);
    two_floats packet;
    packet.f[0] = 100.0;  // Velocity in meter/sec
    packet.f[1] = fAccel;  // Power in percentage
    CanMessage msg = CanMessage(0x401, packet.c);
    Can.send(msg);
  }
}


