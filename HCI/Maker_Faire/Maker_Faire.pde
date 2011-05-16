//Now called Main Input Board
//changes to main input board for maker faire. Display driven
//using serial1 had to disable horn and strobe for that
//Pretty much everything else works now
//This code only requires the pedals and the motor mode to work
//properly
//needs to be debugged by electrical to see
//which switch numbers correspond to VEHICLE_STOP
//VEHICLE_FWD
//VEHICLE_REV
//second change. If neither fwd nor rev engaged. default is stop
//recent change: added !digitalRead to accel() code to read VEHICLE_FWD and VEHICLE_REV correctly
boolean debug = false;

#define LATCH_PIN   2	//Pin attatched to St_CP
#define CLOCK_PIN   1 	//pin attatched to SH_CP 
#define DATA_PIN   	0	//pin attatched to DS
#define OUTPUT_PIN 	31	//output pin attached

// pins on ATMega
#define DIGIT1_LED 	30//since there are only 6 outputs per display, I have to control the E digit since its the least used
#define DIGIT2_LED 	29// from the arduino using these two

//#define HAZ_SWITCH 10 //switched from STROBE_SWITCH
//#define HORN_BUTTON 11
#define speedUnitLED 12
#define speedUnitToggle 13 //switched from SHOW_ID_BUTTON
#define VEHICLE_COAST 14
#define LTURN_SWITCH 18
#define RTURN_SWITCH 17
#define LTURN_INDICATOR 24
#define RTURN_INDICATOR 23
#define VEHICLE_FWD 21 
#define VEHICLE_STOP 20
#define VEHICLE_REV 19 
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



#define ACCEL_PEDAL 27
#define BRAKE_PEDAL 28

#define ACCEL_THRESHOLD 10
#define BRAKE_THRESHOLD 10
//User-Defined Constants
#define INTERVAL 500           // interval at which to blink (milliseconds)
#define MAX_SPEED 100

//Our necessary CAN Ids
#define outputID 0x481
#define TritiumMotor 0x501
#define heartbeatID 0x044
byte digit[] = {0x00,0x00};
//byte digitarr[10] = {B01111110,B00110000,B01101101,B01111001,B00110011,B01011011,B01011111,B01110010,B01111111,B01110011};
//byte digitarr[10] = {0x7E,0x30,0x6d,0x79,0x33,0x5b,0x5f,0x72,0x7f,0x73};
byte digitarr[10] = {0x7E,0x30,0x6d,0x79,0x33,0x5b,0x5f,0xf0,0xff,0xfb};

char inputMessage[8] = {0,0,0,0,0,0,0,0}; //this will transfer out inputs over
//0:RTurn 1:LTurn 2:Strobe(might NOT be used NOW) 3:Horn 4:brake 5:reverse 6:
char motorMessage[8] = {0,0,0,0,0,0,0,0};
float setspeed = 0.0;
float cruiseSpeed = 0.0;
float recordedSpeed = 10.0;
float voltage = 1.0;
boolean km = true;
//cruisemode defines
boolean cruise_active = false;   // Is cruise on?
int can_count = 0;  // To count number of times can buffer is read
float minimum_cruise_speed = 3.0; // Speed, in miles per hour.
           // MUST be same units as internal speed setting
           // MUST be same units as cruise speed
float cruise_speed = 0.0;  // Speed desired to hold. MUST be same units as internal speed setting

long millis_since_cruise_toggle; // The time, in milliseconds, since the cruise button was pressed
long minimum_millis_change_delay = 500; // Time, in milliseconds, the user needs to wait before
                //  changing the state of the cruise control.
boolean brakeOn = false;


void display (int x);
void turnSignals(boolean rTurnSwitchstate, boolean lTurnSwitchstate);
boolean isBitSet(byte x, unsigned char pos);
void initPins(void);
void floatEncoder(CanMessage &msg,float spd, float v);

void setup() {
  delay(2000);
        Can.begin(1000);
  Serial.begin(115200);           // set up Serial library at 9600 bps
  initPins();
  digitalWrite(DIGIT1_LED, HIGH);
  digitalWrite(DIGIT2_LED, HIGH);
  digitalWrite(OUTPUT_PIN, HIGH);
  CanBufferInit(); 
  CanMessage init = CanMessage();
  init.id = 0x503;
  init.len = 0;
  Can.send(init);
  init = CanMessage();
  init.id = 0x502;
  init.len = 8;
  floatEncoder(init,1.0,1.0);
  Can.send(init);
  pinMode(15, OUTPUT);
}

char buff[]= "0000000000";
boolean rightSet = false;
boolean leftSet = false;
void loop() {
  //Serial.print("brake ");
  //Serial.println(brakeOn ? "true" : "false");
  receiveCAN();
  setInputs();
  accel();
  cruiseControl(); // cruise control overrides measurements made by accel
  COMToOthers();
//  if (!digitalRead(HAZ_SWITCH)) {
//     turnSignals(true,true);
//    rightSet = true;
//   leftSet = true; 
//   } 
//  else {
     rightSet = (digitalRead(RTURN_SWITCH) == LOW);                     
     leftSet = (digitalRead(LTURN_SWITCH) == LOW);
     turnSignals(rightSet, leftSet); 
//  }
  km = digitalRead(speedUnitToggle);
  if (km)
    displayNum (recordedSpeed*3.6); //currently km/hr
  else{
    displayNum(recordedSpeed*2.2369); // 1 m/s = 2.2369 mph
  }
  cruiseControl();  
   // testButtons();
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
		x = -x;
	digit[0] = digitarr[x / 10];
	digit[1] = digitarr[x % 10];
      digitalWrite(CLOCK_PIN, LOW);

   digitalWrite(LATCH_PIN,LOW);
   digitalWrite(OUTPUT_PIN,HIGH);
   
        for(int i = 0; i < 2; i++){
       //0ABCDEFG
       //int index[10] = 0x7e,
                    digitalWrite(DATA_PIN,hundred); 
                   
                   digitalWrite(CLOCK_PIN, HIGH );
                      delayMicroseconds(2);
                                digitalWrite(CLOCK_PIN, LOW);
              
     }
for(int j = 0; j < 2; j++)
     for(int i = 0; i < 7; i++){
       //0ABCDEFG
     
                    digitalWrite(DATA_PIN,isBitSet(digit[j], i%7));
                   
                   digitalWrite(CLOCK_PIN, HIGH );
                      delayMicroseconds(2);
                                digitalWrite(CLOCK_PIN, LOW);
              
     }
     digitalWrite(LATCH_PIN,HIGH);
       delayMicroseconds(2);
     digitalWrite(LATCH_PIN,LOW);
     digitalWrite(OUTPUT_PIN,LOW);
}
/********************************************
accel()
This function will read in the current input
note analog pin can only be read every 100 microseconds
********************************************/
int brakeSamples = 1;
int accelSamples = 1;

void accel(){
  int accel = analogRead(ACCEL_PEDAL);
//  Serial.print("accel pedal value is");
//  Serial.println(accel);
  int brake = analogRead(BRAKE_PEDAL);
//  Serial.print("brake pedal value is");
//  Serial.println(brake);
 
  if(!digitalRead(VEHICLE_STOP)||digitalRead(VEHICLE_REV)||digitalRead(VEHICLE_FWD)){
    cruiseCancel(1);
    brakeOn = false;
    voltage = 1.0;
    setspeed = 0.0;
    return;
  }
  if(cruise_active){
	if(brake > BRAKE_THRESHOLD) {
        //  cruiseCancel(2);  // CRUISE CANCEL
        }
        else{
          //setspeed = MAX_SPEED*accel/1023.0;
          return;
        }
  }
  if(brake > BRAKE_THRESHOLD){
    setspeed = 0.0;
    brakeOn = true;
    voltage = brake/1023.0;
    return;
    
}
 if(!digitalRead(VEHICLE_COAST)){
    cruiseCancel(3);
    setspeed = 0;
    voltage = 0.0;
    return;
  }
brakeOn = false;
if(accel < ACCEL_THRESHOLD){
  setspeed = 0.0;
  return;
}
if(!digitalRead(VEHICLE_REV)){
  cruiseCancel(4);
  setspeed = -100.0;
  voltage = accel/1023.0;
  return;
}
  
setspeed = 100.0;
voltage = accel/1023.0;
return;
    
}
/********************************************


/*********************************************
cruiseMode()
This procedure reads the value of the cruise sswitch and sets the mode and speed accordingly.
**********************************************/

boolean firstSet = true;
void cruiseSetMode() {
  /*
   * If the cruise is turned on, but the recorded speed is less than the speed
   *   maintainable by the car, or the brake is being pressed, cancel cruise.
   */
  if (cruise_active && (recordedSpeed < minimum_cruise_speed || brakeOn)) { // where rval represents the speed of the car
  //Serial.print("brake: ");
  //Serial.println(brakeOn ? "true" : "false");
    cruiseCancel(5);
  }

  // Read the state of the cruise switch
  int state = digitalRead(CRUISE_SET);
  
  /* 
   * If the button is being pressed, and enough time has elapsed since the last time we've
   *   pressed the button, then toggle the cruise mode. (This may set it to true OR false.)
   */
  if (state == LOW && millis() - millis_since_cruise_toggle > minimum_millis_change_delay) {
    toggleCruise();
  
    // voltage to 1, set speed to whatever you want
    
    // Update the number of milliseconds since we've pressed the button.
    millis_since_cruise_toggle = millis();
    
    // Act based on the status of cruise when we push the button
    if (cruise_active) {
      cruiseSet();
    } else {
      // If the cruise was actually turned off, then cancel here.
      cruiseCancel(6);
    }
  }
  
  if (cruise_active) {
    maintainSpeed(); 
  }
}

/* 
 * This is the ONLY mehtod where cruise_active should be changed to
 *   where it can _possibly_ be true. 
 */
void toggleCruise() {
//  Serial.println("cruise activated");
   cruise_active = !cruise_active; 
}

/* 
 * Sets cruise speed. Note that this should not change the cruise to true! 
 */
void cruiseSet() {
  cruise_speed = recordedSpeed;
  //Serial.println(cruise_speed);
}

/* 
 * Maintain the speed for the cruise control.
 */
void maintainSpeed(){
  setspeed = cruise_speed;
  voltage = 1.0;
  
}
/* Cancels cruise. This also resets the firstSet variable. */
void cruiseCancel(int i) {
  //Serial.print("received cruise cancel signature from: ");
  //Serial.println(i);
  cruiseCancel(); 
}

void cruiseCancel() {
  firstSet = true;
  //Serial.println("cruise cancelled");
  cruise_active = false;
  cruise_speed = 0;
}

/********************************************
cruiseSetSpeed()
This procedure reads the state of the cruise switch state (again) and if it’s set,
change the speed according to whether or not the rocker switch is being pressed.
**********************************************/
long millis_since_cruise_speed_change = 0; // The time, in milliseconds, since cruise speed changed.
float cruise_speed_increment_unit = 0.2;

void cruiseSetSpeed() {
   if (cruise_active) { 
     int acc = digitalRead(CRUISE_ACC);
     if (acc == LOW && millis() - millis_since_cruise_speed_change > minimum_millis_change_delay && cruise_active) {
        cruise_speed += cruise_speed_increment_unit;
        millis_since_cruise_speed_change = millis();
     }
   
     int dec = digitalRead(CRUISE_DEC);
     if (dec == LOW && millis() - millis_since_cruise_speed_change > minimum_millis_change_delay && cruise_active) {
        cruise_speed -= cruise_speed_increment_unit;
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
  digitalWrite (CRUISE_IND, cruise_active);
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
       // Serial.println("right on");
        }
        if (lTurnSwitchstate) {
       // Serial.println("left on");
      }
  
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
  pinMode(speedUnitLED, OUTPUT);
  pinMode(speedUnitToggle, INPUT);
         digitalWrite(speedUnitToggle,HIGH);
  //pinMode(HAZ_SWITCH, INPUT);
    //    digitalWrite(HAZ_SWITCH, HIGH);
  //pinMode(HORN_BUTTON, INPUT);
    //    digitalWrite(HORN_BUTTON, HIGH);

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
  inputMessage[0] = rightSet;
  inputMessage[1] = leftSet;
  inputMessage[2] = brakeOn;
 // inputMessage[3] = !digitalRead(HORN_BUTTON);
  
}
  
void testButtons() {
     
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
      if(!digitalRead(LTURN_SWITCH)) {
        Serial.println("LTURN");
      }
      if(!digitalRead(RTURN_SWITCH)) {
        Serial.println("RTURN");
      }
//      if(!digitalRead(HORN_BUTTON)) {
//        Serial.println("HONK HONK");
//      }
//      if(!digitalRead(HAZ_SWITCH)) {
//        Serial.println("EMERGENCY");
//      }
      //if(!digitalRead(CRUISE_SET)) {
      //  Serial.println("Cruise on");
      //}
      //Serial.print("Brake = ");
      //Serial.println(analogRead(BRAKE_PEDAL));
      //Serial.print("Accel = ");
      //Serial.println(analogRead(ACCEL_PEDAL));
   //   Serial.println("Cruise Speed" + cruiseSpeed);
      
}  
int state = 0;
long previousMillisOutput = 0; 
long previousMillisHeart = 0;
long previousMillisDrive = 0;
//sends CAN messages 
void COMToOthers() {
  if(state > 2)
    state = 0;
  CanMessage msg ;
  if (state == 0){  
    if((millis() - previousMillisOutput > 100)) {
      msg = sendOutputMsg(); //Allocates space for new CanMessage
      Can.send(msg);
      previousMillisOutput = millis();
     // Serial.print(CanBufferSize());
    //  Serial.print("\t");
     // Serial.println(can_count);
      can_count = 0;
    }
  }
   if(state == 1){
     if(millis() - previousMillisDrive > 100){
      msg = sendMotorControl(); //Allocates space for new CanMessage
      Can.send(msg);
      previousMillisDrive = millis();
    }
  }  
  if(state == 2){
    if(millis() - previousMillisHeart > 200){
      msg = sendHeartbeat();
      Can.send(msg);
      previousMillisHeart = millis();
    }
  }
  state ++;
}


CanMessage sendOutputMsg() {
  CanMessage outputMsg = CanMessage();
  outputMsg.id = outputID;
  outputMsg.len = 5; 
  for(int i = 0; i<5;i++){
    outputMsg.data[i] = inputMessage[i];
    }
  return outputMsg;
}

CanMessage sendHeartbeat(){
  CanMessage outputMsg = CanMessage();
  outputMsg.id = heartbeatID;
  outputMsg.len = 1;
  outputMsg.data[0] = 0;
  return outputMsg;
}

CanMessage sendMotorControl(){
      CanMessage outputMsg = CanMessage();
      outputMsg.id = TritiumMotor;
      outputMsg.len = 8;
      floatEncoder(outputMsg,setspeed,voltage);
      Serial.print("speed =");
     Serial.println(setspeed);
      Serial.print("voltage =");
      Serial.println(voltage);
      return outputMsg;
}
void floatEncoder(CanMessage &msg,float spd, float v){

    msg.data[0] = *((char *)&spd);
  msg.data[1] = *(((char *)&spd)+1);
  msg.data[2] = *(((char *)&spd)+2);
  msg.data[3] = *(((char *)&spd)+3);
  msg.data[4] = *((char *)&v);
  msg.data[5] = *(((char *)&v)+1);
  msg.data[6] = *(((char *)&v)+2);
  msg.data[7] = *(((char *)&v)+3);
}
void receiveCAN() {
    if (CanBufferSize()) {               // If there is more than 1 packet in the CAN Buffer
    CanMessage msg = CanBufferRead();  // Local CanMessage object to receive data into
                   // Switch based on CAN ID
    if (msg.id ==  0x403){
      recordedSpeed = floatDecode(msg);
      if (debug){
          Serial.print("received speed:");
          Serial.println(recordedSpeed);
      }
    } else {
      if (debug){
        Serial.print("We got an unknown packet with ID: ");
        Serial.println(msg.id & 0x7FF, HEX);
      }
    }
    can_count++;
  }
}
float floatDecode(CanMessage msg){
  float v;
  v = *((float*)&msg.data[4]);
  return v;
}
