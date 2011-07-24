
char inputMessage[8]; //this will transfer out inputs over
//0:RTurn 1:LTurn 2:Strobe 3:Horn 4:brake 5:reverse 6:
#define RTURN 15
#define LTURN 16
#define CAMERA 17
#define HORN 18
#define BRAKE 19
#define REVERSE 20
#define buttonsID 0x481
boolean state = false;
//User-Defined Constants
#define INTERVAL 500           // interval at which to blink (milliseconds)
boolean debug = true;
#define heartbeatID 0x43
#define heartbeatInterval 1000

void setup(){
 Can.begin(1000);     // Turn CAN on at 500 kbits/Sec
 Serial.begin(115200); // Turn on Serial communication
   CanBufferInit();    // Initialize the buffer, turn on interrupts.

initPins();
digitalWrite(CAMERA, HIGH);
}

void loop(){
  
  heartbeat();
	if (CanBufferSize()) {               // If there is more than 1 packet in the CAN Buffer
    CanMessage msg = CanBufferRead();  // Local CanMessage object to receive data into
    switch (msg.id) {                  // Switch based on CAN ID
      case buttonsID:
        updateInputs(msg);
        if (debug){
        Serial.println("We got message from main input board ");
        Serial.print(msg.data[0] & 0xFF, HEX);
        Serial.println(msg.data[1] & 0xFF, HEX);
        Serial.println(msg.data[2] & 0xFF, HEX);
        Serial.println(msg.data[3] & 0xFF, HEX);
        Serial.println(msg.data[4] & 0xFF, HEX);
        Serial.println(msg.data[5] & 0xFF, HEX);
        Serial.println(msg.data[6] & 0xFF, HEX);
        Serial.println(msg.data[7] & 0xFF, HEX);
        }
        break;
      default:
      if (debug){
        Serial.print("We got an unknown packet with ID: ");
        Serial.println(msg.id & 0x7FF, HEX);
      }
        break;
    }
  }
  
update();
}


void initPins(){
pinMode(RTURN, OUTPUT);
pinMode(LTURN, OUTPUT);
pinMode(CAMERA, OUTPUT);
pinMode(HORN, OUTPUT);
pinMode(BRAKE, OUTPUT);
pinMode(REVERSE, OUTPUT);
}

void updateInputs(CanMessage msg) {
	inputMessage[0] = msg.data[0];
	inputMessage[1] = msg.data[1];
	inputMessage[2] = msg.data[2];
	inputMessage[3] = msg.data[3];
	inputMessage[4] = msg.data[4];
	inputMessage[5] = msg.data[5];
}
void update() {
	turnSignals(inputMessage[0], inputMessage[1]);
 
	brakeLight(inputMessage[2]); 
	horn(inputMessage[3]);
//	revLight(VehicleReverse); //strobe and reverse not added because WSC does not need it
}


/********************************************
turnSignals(rTurnSwitch,lTurnSwitch)
This function controls the turn signal lights
when given the states of their switches
********************************************/
boolean rTurnSwitchState = false;
boolean lTurnSwitchState = false;
void turnSignals(boolean rTurnSwitch,boolean lTurnSwitch){
	static long previousMillis = 0; // will store last time LED was updated
	if (!rTurnSwitch)
		rTurnSwitchState = LOW;
	if (!lTurnSwitch)
		lTurnSwitchState = LOW;
	if ((millis() - previousMillis > INTERVAL)&&(rTurnSwitch||lTurnSwitch)) {
		// save the last time you blinked the LED 
		previousMillis = millis();   
			// set the LED with the lightState of the variable:
		
	if(rTurnSwitch)		
	rTurnSwitchState = !rTurnSwitchState;
        if(lTurnSwitch)
        lTurnSwitchState = !lTurnSwitchState;
	}
digitalWrite(LTURN, lTurnSwitchState);
digitalWrite(RTURN, rTurnSwitchState);
}

void heartbeat()
{
   static long previousMillis = 0;
   if(millis() - previousMillis > heartbeatInterval)
     {
       CanMessage msg = CanMessage();
       msg.id = heartbeatID;
       msg.data[0] = 0;
       msg.len = 1;
     }
}
   
/*****************************************
strobe(strobeState) 
This function controls the strobe light 
when given its state
*****************************************/
//void strobe(boolean strobeState) {
//	static long previousMillis = 0;
//	if(!strobeState) {
//		digitalWrite(STROBE, LOW);
//	}
//	else {
//		if (millis() - previousMillis > INTERVAL)
//			previousMillis = millis();
//			digitalWrite(STROBE, HIGH);
//	}
//}

/****************************************
brakeLight(brakeState) 
This function keeps brake light on as long
as brake is being pressed
****************************************/
void brakeLight(boolean brakeState) {
	if(brakeState) {
		digitalWrite(BRAKE, HIGH);
	} 
	else {
		digitalWrite(BRAKE, LOW);
	}
}

/****************************************
horn(hornState) 
This function triggers the horn while the
soft button if being pressed
****************************************/
void horn(boolean hornState) {
	if(hornState) {
		digitalWrite(HORN, HIGH);
	}
	else {
		digitalWrite(HORN, LOW);
	}
}

/****************************************
revLight(revState)
This function controls reverse lights
when drive state is in reverse
****************************************/
//revLight(boolean revState) {
//	if(revState) {
//		digitalWrite(REVERSE_LIGHT, HIGH);
//	}
//	else {
//		digitalWrite(REVERSE_LIGHT, LOW);
//	}
//}
