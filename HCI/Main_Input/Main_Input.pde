//Now called Main Input Board
//#include "can.h"


//initialization for shift register
//IC number HEF4894BP
//note digit one is on the left and digit2 is on the right
#define LATCH_PIN 2//Pin attatched to St_CP
#define CLOCK_PIN 1 //pin attatched to SH_CP 
#define DATA_PIN 0//pin attatched to DS
#define OUTPUT_PIN 31//output pin attached

//pins on ATMega
#define DIGIT1_LED 30//since there are only 6 outputs per display, I have to control the E digit since its the least used
#define DIGIT2_LED 29// from the arduino using these two

#define HAZ_SWITCH 10 //switched from STROBE_SWITCH
#define HORN_BUTTON 11
#define E_LIGHT 12
#define SHOW_ID_BUTTON 13
#define VEHICLE_COAST 14
#define LTURN_SWITCH 18
#define RTURN_SWITCH 17
#define LTURN_INDICATOR 24
#define RTURN_INDICATOR 23
#define VEHICLE_FWD 19
#define VEHICLE_STOP 20
#define VEHICLE_REV 21
#define DEBUG 22

/* 
 * Cruise control pins. Pin 15 was originally the CRUISE_SET pin, but after finding that this
 * pin connects to an LED, this was switched to pin 16, swapped conveniently with the CRUISE_IND
 * pin.
 */
#define CRUISE_SET 16 // Sets cruise on, or off.
#define CRUISE_DEC 25 // Rocker switch pushed to decrease speed.
#define CRUISE_ACC 26 // Rocker switch pushed to increase speed.
#define CRUISE_IND 15 // The light in the cruise switch to indicate state.



#define ACCEL_PEDAL 28
#define BRAKE_PEDAL 27

//User-Defined Constants
#define INTERVAL 500           // interval at which to blink (milliseconds)

byte digit[] = {0x00,0x00};
//byte digitarr[10] = {B01111110,B00110000,B01101101,B01111001,B00110011,B01011011,B01011111,B01110010,B01111111,B01110011};
byte digitarr[10] = {0x7E,0x30,0x6d,0x79,0x33,0x5b,0x5f,0x72,0x7f,0x73};
char inputMessage[8] = {0,0,0,0,0,0,0,0}; //this will transfer out inputs over
//0:RTurn 1:LTurn 2:Strobe(might NOT be used NOW) 3:Horn 4:brake 5:reverse 6:
char motorMessage[8] = {0,0,0,0,0,0,0,0};
float speed = 0.0;

void display (int x);
void turnSignals(boolean rTurnSwitchstate, boolean lTurnSwitchstate);
boolean isBitSet(byte x, unsigned char pos);
void initPins(void);

void setup() {
        Can.begin(500);
	Serial.begin(9600);           // set up Serial library at 9600 bps
	initPins();
	digitalWrite(DIGIT1_LED, HIGH);
	digitalWrite(DIGIT2_LED, HIGH);
	digitalWrite(OUTPUT_PIN, HIGH);

}

char buff[]= "0000000000";
int rval = 0;
void loop() {
		setInputs();
		sendToOthers();
                if (!digitalRead(HAZ_SWITCH)) {
                   turnSignals(true,true); } 
                else {
                      boolean rightSet = (digitalRead(RTURN_SWITCH) == LOW);                     
                      boolean leftSet = (digitalRead(LTURN_SWITCH) == LOW);
             	      turnSignals(rightSet, leftSet); 
                }
		//delay(500);
		displayNum (74);
                testButtons();
                cruiseControl();
                accel();
	
}

/*******************************
display(x)
This function will cause the LED
array to display a number between
00 and 99
********************************/
void displayNum (int x) { 
 boolean hundred = x >=100;	
  x = x % 100;
	if (x < 0)
		x = 0;
	digit[0] = digitarr[x / 10];
	digit[1] = digitarr[x % 10];
       

//for(int j = 0;j<7;j++){
//  digitalWrite(LATCH_PIN, LOW);
//   
//  for(int i = 0; i<7; i++){
//    digitalWrite(DATA_PIN, LOW);
//    
//    if(i==j){
//     if(i==2)
//        digitalWrite(DIGIT1_LED, !isBitSet(digit[0],j));
//       else
//      digitalWrite(DATA_PIN, isBitSet(digit[0],j));
//    }
//    	 if (!(i== 2)){
//    	delayMicroseconds(10);
//		  		digitalWrite(CLOCK_PIN, LOW);
//		  		delayMicroseconds(10);
//		  		digitalWrite(CLOCK_PIN, HIGH);
//    }
//  }
//    for(int i = 0; i<7; i++){
//    digitalWrite(DATA_PIN, LOW);
//    
//    if(i==j){
//      if(i==2)
//        digitalWrite(DIGIT2_LED, !isBitSet(digit[1],j));
//       else
//      digitalWrite(DATA_PIN, isBitSet(digit[1],j));
//    }
//    if (!(i== 2)){
//    	delayMicroseconds(10);
//		  		digitalWrite(CLOCK_PIN, LOW);
//		  		delayMicroseconds(10);
//		  		digitalWrite(CLOCK_PIN, HIGH);
//    }
//  }
//
//  digitalWrite(LATCH_PIN, HIGH);
//}
//Note this version is used if the refresh rate for the display is not high enough
digitalWrite(OUTPUT_PIN,HIGH);	
	digitalWrite(LATCH_PIN, LOW);
         digitalWrite(CLOCK_PIN, LOW);
    if (isBitSet( digit[0], 2))
		digitalWrite (DIGIT1_LED, LOW);      
    else 
		digitalWrite (DIGIT1_LED, HIGH);
    if (isBitSet( digit[1], 2))
		digitalWrite (DIGIT2_LED, LOW);      
    else
      digitalWrite (DIGIT2_LED, HIGH);
      	  
for(int j = 0; j < 2; j++){
for (int i = 0; i < 7 ; i++) {
			if (i != 2){
                                if(hundred){
				digitalWrite(DATA_PIN,  isBitSet(0b01100000, i));
				//  Serial.println (isBitSet(digit[j], i));
				
				}  
                                else{
                                digitalWrite(DATA_PIN,  isBitSet(0b00000000, i));
                                }
			
                                digitalWrite(CLOCK_PIN, HIGH );
                                digitalWrite(CLOCK_PIN, LOW);
                            
			}
		}}
	for (int j = 0;j < 2;j++){
		for (int i = 0; i < 7 ; i++) {
			if (i != 2){
				digitalWrite(DATA_PIN,  isBitSet(digit[j], i));
				//  Serial.println (isBitSet(digit[j], i));
				
				
			
                                digitalWrite(CLOCK_PIN, HIGH );
                                digitalWrite(CLOCK_PIN, LOW);
                            
			}
		}

}
	
  //take the latch pin high so the LEDs will light up:
	digitalWrite(LATCH_PIN, HIGH);
}
/********************************************
accel()
This function will read in the current input
note analog pin can only be read every 100 microseconds
********************************************/
void accel(){
	analogRead(ACCEL_PEDAL);
	analogRead(BRAKE_PEDAL);
}
/********************************************
readInputs()
This function will read in all the inputs into the inputMessage
*********************************************/
void readInputs(){
}


/*********************************************
cruiseMode()
This procedure reads the value of the cruise switch and sets the mode and speed accordingly.
**********************************************/
boolean cruise_active = false;	 // Is cruise on?

int minimum_cruise_speed = 20; // Speed, in miles per hour.
				   // MUST be same units as internal speed setting
				   // MUST be same units as cruise speed
int cruise_speed = 0;	// Speed desired to hold. MUST be same units as internal speed setting

long millis_since_cruise_toggle; // The time, in milliseconds, since the cruise button was pressed
long minimum_millis_change_delay = 500; // Time, in milliseconds, the user needs to wait before
					      //  changing the state of the cruise control.


void cruiseSetMode() {
  // If the speed falls below the minimum_cruise_speed, cancel cruise.
  if (cruise_active && rval < minimum_cruise_speed) { // where rval represents the speed of the car
    cruiseCancel();
  }

  // Read the state of the cruise switch and act accordingly.
  int state = digitalRead(CRUISE_SET);
  if (state == LOW && millis() - millis_since_cruise_toggle > minimum_millis_change_delay) {
    toggleCruise();
    digitalWrite(CRUISE_IND, cruise_active ? HIGH : LOW); // Change the LED
    millis_since_cruise_toggle = millis();
    
    // Do actions related to cruise_active
    if (cruise_active) {
      cruiseSet();
    } else {
      cruiseCancel();
    }
  }
}

/* This is the ONLY mehtod where cruise_active should be changed to
   where it can _possibly_ be true. */
void toggleCruise() {
   cruise_active = !cruise_active; 
}

/* Sets cruise speed. Note that this should not change the cruise to true! */
void cruiseSet() {
  cruise_speed = rval;
}

/* Cancels cruise. */
void cruiseCancel() {
  cruise_active = false;
  cruise_speed = 0;
}

/********************************************
cruiseSetSpeed()
This procedure reads the state of the cruise switch state (again) and if it’s set,
change the speed according to whether or not the rocker switch is being pressed.
**********************************************/
long millis_since_cruise_speed_change = 0; // The time, in milliseconds, since cruise speed changed.

void cruiseSetSpeed() {
   if (cruise_active) { 
     int acc = digitalRead(CRUISE_ACC);
     if (acc == LOW && millis() - millis_since_cruise_speed_change > minimum_millis_change_delay && cruise_active) {
        cruise_speed++;
        millis_since_cruise_speed_change = millis();
     }
   
     int dec = digitalRead(CRUISE_DEC);
     if (dec == LOW && millis() - millis_since_cruise_speed_change > minimum_millis_change_delay && cruise_active) {
        cruise_speed--;
        millis_since_cruise_speed_change = millis();
     }
   }
}

/********************************************
cruiseControl()
This procedure separates the cruise mode into the on/off state (cruiseSetMode) and the
increase/decrease speed (cruiseSetSpeed)
**********************************************/
void cruiseControl() {
	cruiseSetMode();
	cruiseSetSpeed();
}

/********************************************
turnSignals(rTurnSwitch,lTurnSwitch)
This function controls the turn signal lights
when given the states of their switches
********************************************/
static long previousMillis = 0; // will store last time LED was updated
	static int lightState = LOW;       // lightState used to set the LED

void turnSignals(boolean rTurnSwitchstate,boolean lTurnSwitchstate){
       
        if(rTurnSwitchstate)  {
        Serial.println("right on");
        }
        if (lTurnSwitchstate) {
        Serial.println("left on"); }
	
	if (!rTurnSwitchstate)
		digitalWrite(RTURN_INDICATOR, LOW);
	if (!lTurnSwitchstate)
		digitalWrite(LTURN_INDICATOR, LOW);
	if ((millis() - previousMillis > INTERVAL)&& ((rTurnSwitchstate||lTurnSwitchstate))) {
		// save the last time you blinked the LED 
		previousMillis = millis();   
		lightState = (lightState == LOW ? HIGH : LOW);
			// set the LED with the lightState of the variable:
		if(rTurnSwitchstate)
			digitalWrite(RTURN_INDICATOR, lightState);
		if(lTurnSwitchstate)
			digitalWrite(LTURN_INDICATOR, lightState);
	}

}

/**********************************
isBitSet(x,pos)
This function will return the value 
of the bit at the given position.
**********************************/
boolean isBitSet(byte x, unsigned char pos){
  return ((x >> pos) & B00000001);
}

/**************************************************
initPins()
This function will initialize all pins 
as inputs.  It is called in setup().

digitalWrite(PIN, HIGH) used to fix floating error
***************************************************/
void initPins(void){
	pinMode (LATCH_PIN, OUTPUT);
	pinMode (CLOCK_PIN, OUTPUT);
	pinMode (DATA_PIN, OUTPUT);
	pinMode (OUTPUT_PIN, OUTPUT);
        digitalWrite(OUTPUT_PIN,HIGH);
	pinMode (DIGIT1_LED, OUTPUT);
	pinMode (DIGIT2_LED, OUTPUT);
	pinMode (RTURN_SWITCH, INPUT);
        digitalWrite(RTURN_SWITCH, HIGH);
	pinMode (LTURN_SWITCH, INPUT);
        digitalWrite(LTURN_SWITCH, HIGH);
	pinMode(E_LIGHT, INPUT);
	pinMode(SHOW_ID_BUTTON, INPUT);
	pinMode(HAZ_SWITCH, INPUT);
        digitalWrite(HAZ_SWITCH, HIGH);
	pinMode(HORN_BUTTON, INPUT);
        digitalWrite(HORN_BUTTON, HIGH);
	//pinMode (EMERGENCY_ID_TOGGLE, INPUT);
        pinMode(LTURN_INDICATOR, OUTPUT);
        pinMode(RTURN_INDICATOR, OUTPUT);
	pinMode(CRUISE_SET, INPUT);
        digitalWrite(CRUISE_SET, HIGH);
	pinMode(CRUISE_DEC, INPUT);
        digitalWrite(CRUISE_DEC, HIGH);
	pinMode(CRUISE_ACC, INPUT);
        digitalWrite(CRUISE_ACC, HIGH);
	pinMode(CRUISE_IND, OUTPUT);
        pinMode(VEHICLE_COAST, INPUT);
        digitalWrite(VEHICLE_COAST, HIGH);
        pinMode(VEHICLE_FWD, INPUT);
        digitalWrite(VEHICLE_FWD, HIGH);
        pinMode(VEHICLE_STOP, INPUT);
        digitalWrite(VEHICLE_STOP, HIGH);
        pinMode(VEHICLE_REV, INPUT);
        digitalWrite(VEHICLE_REV, HIGH);
        
}
        
/************************************
This function will assign all digital
inputs to a single integer as well as
setting both analog inputs. Each bit 
is assigned to an index in the 
inputMessage char array.
0: Right Turn
1: Left Turn
2: Vehicle's Brake Engaged
3: Horn
4: Vehicle in Reverse
*************************************/
void setInputs() {
	inputMessage[0] = !digitalRead(RTURN_SWITCH);
	inputMessage[1] = !digitalRead(LTURN_SWITCH);
	inputMessage[2] = !digitalRead(VEHICLE_STOP);
	inputMessage[3] = !digitalRead(HORN_BUTTON);
	inputMessage[4] = !digitalRead(VEHICLE_REV);
}
	
void testButtons() {
     /*
      if(!digitalRead(VEHICLE_STOP)) {
        Serial.println("Drive State: STOP");
      }
      if(!digitalRead(VEHICLE_REV)){
        Serial.println("Drive State: REV");      
      }
      if(!digitalRead(VEHICLE_FWD)) {
        Serial.println("Drive State: FWD");
      }
      if(!digitalRead(VEHICLE_COAST)) {
        Serial.println("Drive State: COAST");
      }
      */
      if(!digitalRead(HORN_BUTTON)) {
        Serial.println("HONK HONK");
      }
      if(!digitalRead(HAZ_SWITCH)) {
        Serial.println("EMERGENCY");
      }
      if(!digitalRead(CRUISE_SET)) {
        Serial.println("Cruise on");
      }
      Serial.print("Brake = ");
      Serial.println(analogRead(BRAKE_PEDAL));
      Serial.print("Accel = ");
      Serial.println(analogRead(ACCEL_PEDAL));
      //Serial.println("Cruise Speed" + cruiseSpeed);
      
}  

//sends CAN messages 
void sendToOthers() {
	CanMessage msg = sendOutputMsg(); //Allocates space for new CanMessage
	Can.send(msg);
	//delay(225); //unsure of delay time
}


CanMessage sendOutputMsg() {
	CanMessage outputMsg = CanMessage();
	outputMsg.id = 0x481;
	outputMsg.len = 5; //unsure of what the len is exactly corresponding to this means length
	for(int i = 0; i<5;i++){
		outputMsg.data[i] = inputMessage[i];
		}
	return outputMsg;
}
