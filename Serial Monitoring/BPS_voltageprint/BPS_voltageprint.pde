/* CalSol - UC Berkeley Solar Vehicle Team 
 * [NAME OF FILE] - [INTENDED MODULE]
 * Author: [YOUR NAME]
 * Date: [TODAY'S DATE]
 */

/* Define CAN message IDs */
// TODO: Define CAN IDs

/* Declare your state variables here */
// TODO: Declare state variables

long last_time = 0;

float voltage[3][12];
float temp[3][12];

char newpacket =0;

typedef union {
  char c[8];
  float f[1];
} two_floats;



void process_packet(CanMessage &msg) {
  if (msg.id >= 0x100 && msg.id < 0x200 ) {
    int module_id = (msg.id & 0x030) >> 4;
    int cell_id = (msg.id & 0x00F);
    two_floats data;
    if (cell_id <= 0xB){
      for (int i = 0; i < 8; i++) data.c[i] = msg.data[i];
      voltage[module_id][cell_id] = data.f[0];
      newpacket=1;
    }
  }
}

void setup() {
  /* Can Initialization w/o filters */
  Can.attach(&process_packet);
  Can.begin(1000);
  CanBufferInit();
  Serial.begin(115200);
  Serial.println("BPS Monitoring Board Online: Awaiting CAN messages");
}

void loop() {
  if (((millis() - last_time) > 100) && newpacket) {
    newpacket=0;    
    last_time=millis();
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 12; j++) {
        if (!((i==2)&&(j>=9))){
          Serial.print(i+1);
          Serial.print(".");
          Serial.print(j+1);
          Serial.print(": ");
          Serial.print(voltage[i][j]);
          Serial.println("V\t");
        }
      }
    }
  }
}
