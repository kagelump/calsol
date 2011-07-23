/* CalSol - UC Berkeley Solar Vehicle Team 
 * display.pde - Dashboard Module
 * Author(s): Michael Chang, Lily Lin
 * Date: July 17th 2011
 */

const int FONT_5x7 = 0x00;
const int FONT_8x8 = 0x01;
const int FONT_8x12 = 0x02;
const int FONT_12x16 = 0x03;

const int white = 0xffff;
const int red = 0xf800;
const int yellow = 0xffe0;
const int green = 0x07e0;
const int blue = 0x001F;
const int black = 0x0000;

const int defaultFont = FONT_12x16;  // default font byte
const int defaultFontWidth = 1;
const int defaultFontHeight = 1;

const int DISPLAY_INITIALIZE_DELAY = 500;  /// Time between putting the LCD out of reset and sending commands

const int DISPLAY_CMD_TIMEOUT = 100;  /// Time in ms before commands are retransmitted
const int DISPLAY_RESP_DELAY = 1;  /// Time in ms beetween checks for responses

const int TOUCHENABLE = 0x00;
const int TOUCHDISABLE = 0x01;
const int TOUCHRESET = 0x02;

const uint8_t DISPLAY_RESP_ACK = 0x06;
const uint8_t DISPLAY_RESP_NACK = 0x15;

const uint8_t DISPLAY_CMD_AUTOBAUD = 0x55;
const uint8_t DISPLAY_CMD_CONTROL = 0x59;
const uint8_t DISPLAY_MODE_ORIENTATION = 0x04;
const uint8_t DISPLAY_ORIENTATION_LANDSCAPE = 0x01;
const uint8_t DISPLAY_CMD_CLEAR = 0x45;

const int MAIN = 0x01;
const int HEART = 0x02;
const int BATTERY = 0x03;
const int SOLAR = 0x04;
const int MOTOR = 0x05;
const int CUTOFF = 0x06;
const int SYS = 0x07;
const int TEMP = 0x08;

const int ONLINE = 0x01;
const int OFFLINE = 0x00;
const int NOTSET = 0x02;


/* Define CAN message IDs */
#define CAN_MAININPUT_EMERGENCY 0x024
#define CAN_MAININPUT_HEARTBEAT 0x044
#define CAN_TRITIUM_MOTOR_DRIVE 0x501
#define CAN_TRITIUM_BUS         0x402
#define CAN_TRITIUM_VELOCITY    0x403
#define MPPT_5                  0x774
#define BATTERY_MOD_0_0         0x100
#define BATTERY_EXT_0           0x10C
#define CUTOFF_VOLTAGE          0x055
#define CUTOFF_CURRENT          0x524

/* Pin definitions here */
#define ANALOGIN_ACCEL 2
#define ANALOGIN_BRAKE 3
#define DIGITALOUT_ERROR 15

/* Non constant definitions*/
int screen = MAIN;
int startAngle = -40;
int endAngle = 220;
int rad = 30;

float measured_speed;
volatile long last_received = 0;
volatile long last_time = 0;
// max values from CAN
long max_bus_voltage = 100;
long max_bus_current = 100;
long max_motor_speed = 100;
long max_tritium_speed = 100;
long max_solar_voltage = 100;
long max_solar_current = 100;
long max_battery_volt0 = 100;
long max_battery_temp0 = 100;
long max_battery_voltage = 150;
long max_battery_temp = 50;
// values from CAN
volatile long bus_voltage = 0;
volatile long bus_current = 0;
volatile long tritium_last_received = 0;
volatile long solar_last_received = 0;
volatile long battery_last_received = 0;
volatile long motor_speed = 0;
volatile long tritium_speed = 0;
volatile long solar_voltage = 0;
volatile long solar_current = 0;
volatile long battery_volt0 = 0;
volatile long battery_temp0 = 0;

volatile long battery_voltage = 0;

volatile long cutoff_volt = 0;

volatile int time = millis();
volatile int batt = 0;
volatile int solar = 0;
volatile int motor = 0;
volatile int battdif = 0;
volatile int solardif = 0;
volatile int motordif = 0;
volatile int cutoff = 0;
volatile int sys = 0;
volatile int temp = 0;

volatile int batteryok = NOTSET;
volatile int solarok = NOTSET;
volatile int motorok = NOTSET;
volatile int cutoffok = NOTSET;
volatile int systemok = NOTSET;
volatile int tempok = NOTSET;
char* OK = "OK";

char* INITIALSTAT = "Not Set";
int   INITSTATCOL = blue;

typedef union {
  char c[8];
  float f[2];
} two_floats;


//const double PI = 3.14159;

uint8_t display_readAck() {
  int i = 0;
  while (i < DISPLAY_CMD_TIMEOUT) {
    if (Serial1.available() > 0) {
      uint8_t resp = Serial1.read();
      return resp;
    }
    i += DISPLAY_RESP_DELAY;
    delay(DISPLAY_RESP_DELAY);
  }
  return 0x00;
}

void drawBlueBackground(){
  Serial1.write(0x42); //send command to change background color
  Serial1.write((unsigned char)0x0); //zero red, zero green, unsigned char cast needed for zero  because of dumb compiler issues
  Serial1.write(0x1f); //max blue value
  
  display_readAck();
}

void drawLine(int xStartPos, int yStartPos, int xEndPos, int yEndPos, int color){
  Serial1.write(0x4c); //send command
  
  Serial1.write((unsigned char)(xStartPos >>8)&0xff); //send off xStartPos
  Serial1.write((unsigned char)xStartPos&0xff);
  
  Serial1.write((unsigned char)(yStartPos >>8)&0xff); //send off xStartPos
  Serial1.write((unsigned char)yStartPos&0xff);
  
  Serial1.write((unsigned char)(xEndPos >>8)&0xff); //send off xStartPos
  Serial1.write((unsigned char)xEndPos&0xff);
  
  Serial1.write((unsigned char)(yEndPos >>8)&0xff); //send off xStartPos
  Serial1.write((unsigned char)yEndPos&0xff);
  
  Serial1.write((unsigned char)(color>>8)&0xff);
  Serial1.write((unsigned char)color&0xff);

  display_readAck();
}

void drawCircle(int xCoor, int yCoor, int radius, int color){
  Serial1.write(0x43);
  
  Serial1.write((unsigned char)(xCoor>>8)&0xff);
  Serial1.write((unsigned char)xCoor&0xff);
  
  Serial1.write((unsigned char)(yCoor>>8)&0xff);
  Serial1.write((unsigned char)yCoor&0xff);
  
  Serial1.write((unsigned char)(radius>>8)&0xff);
  Serial1.write((unsigned char)radius&0xff);
  
  Serial1.write((unsigned char)(color>>8)&0xff);
  Serial1.write((unsigned char)color&0xff);

  display_readAck();
}

void drawTriangle(int x1, int y1, int x2, int y2, int x3, int y3, int color){
  Serial1.write(0x47);
  
  Serial1.write((unsigned char)(x1>>8)&0xff);
  Serial1.write((unsigned char)(x1&0xff));
  
  Serial1.write((unsigned char)(y1>>8)&0xff);
  Serial1.write((unsigned char)(y1&0xff));
  
  Serial1.write((unsigned char)(x2>>8)&0xff);
  Serial1.write((unsigned char)(x2&0xff));
  
  Serial1.write((unsigned char)(y2>>8)&0xff);
  Serial1.write((unsigned char)(y2&0xff));
  
  Serial1.write((unsigned char)(x3>>8)&0xff);
  Serial1.write((unsigned char)(x3&0xff));
  
  Serial1.write((unsigned char)(y3>>8)&0xff);
  Serial1.write((unsigned char)(y3&0xff));
  
  Serial1.write((unsigned char)(color>>8)&0xff);
  Serial1.write((unsigned char)color&0xff);
  
  display_readAck();
}

void drawRect(int x1, int y1, int x2, int y2, int color){
  Serial1.write(0x72);
  
  Serial1.write((unsigned char)(x1>>8)&0xff);
  Serial1.write((unsigned char)x1&0xff);
  
  Serial1.write((unsigned char)(y1>>8)&0xff);
  Serial1.write((unsigned char)y1&0xff);
  
  Serial1.write((unsigned char)(x2>>8)&0xff);
  Serial1.write((unsigned char)x2&0xff);
  
  Serial1.write((unsigned char)(y2>>8)&0xff);
  Serial1.write((unsigned char)y2&0xff);
  
  Serial1.write((unsigned char)(color>>8)&0xff);
  Serial1.write((unsigned char)color&0xff);

  display_readAck();
}

void drawEllipse(int x1, int y1, int xmaj, int ymin, int color){
  Serial1.write(0x72);
  
  Serial1.write((unsigned char)(x1>>8)&0xff);
  Serial1.write((unsigned char)x1&0xff);
  
  Serial1.write((unsigned char)(y1>>8)&0xff);
  Serial1.write((unsigned char)y1&0xff);
  
  Serial1.write((unsigned char)(xmaj>>8)&0xff);
  Serial1.write((unsigned char)xmaj&0xff);
  
  Serial1.write((unsigned char)(ymin>>8)&0xff);
  Serial1.write((unsigned char)ymin&0xff);
  
  Serial1.write((unsigned char)(color>>8)&0xff);
  Serial1.write((unsigned char)color&0xff);

  display_readAck();
}


void drawASCII(int symb, int xCoor, int yCoor, int symbColor, int width, int height){
  Serial1.write(0x74);
  
  Serial1.write((unsigned char)symb);
  
  Serial1.write((unsigned char)(xCoor>>8)&0xff);
  Serial1.write((unsigned char)(xCoor&0xff));
  
  Serial1.write((unsigned char)(yCoor>>8)&0xff);
  Serial1.write((unsigned char)(yCoor&0xff));
  
  Serial1.write((unsigned char)(symbColor>>8)&0xff);
  Serial1.write((unsigned char)(symbColor&0xff));
  
  Serial1.write(width);
  Serial1.write(height);
  
  display_readAck();
}

void drawString(int xCoor, int yCoor, int font, int stringColor, int width, int height, char* string) {
  Serial1.write(0x53);
  
  Serial1.write((unsigned char)(xCoor>>8)&0xff);
  Serial1.write((unsigned char)(xCoor&0xff));
  
  Serial1.write((unsigned char)(yCoor>>8)&0xff);
  Serial1.write((unsigned char)(yCoor&0xff));
  
  Serial1.write((unsigned char)font);
  
  Serial1.write((unsigned char)(stringColor>>8)&0xff);
  Serial1.write((unsigned char)(stringColor&0xff));
  
  Serial1.write((unsigned char)width);
  Serial1.write((unsigned char)height);

  while (*string != 0) {
    Serial1.write((unsigned char)*string);
    string++;
  }
  Serial1.write((unsigned char)0x00);  // send terminator byte
  
  display_readAck();
}

void drawInteger(int xCoor, int yCoor, int font, int stringColor, int width, int height, int value) {
  Serial1.write(0x53);
  
  Serial1.write((unsigned char)(xCoor>>8)&0xff);
  Serial1.write((unsigned char)(xCoor&0xff));
  
  Serial1.write((unsigned char)(yCoor>>8)&0xff);
  Serial1.write((unsigned char)(yCoor&0xff));
  
  Serial1.write((unsigned char)font);
  
  Serial1.write((unsigned char)(stringColor>>8)&0xff);
  Serial1.write((unsigned char)(stringColor&0xff));
  
  Serial1.write((unsigned char)width);
  Serial1.write((unsigned char)height);

  // assumes that the maximum integer passed will be in the hundreds
  int number;
  number = value;
  int hundreds = (number%1000)/100;
  int tens = (number%100)/10;
  int ones = number%10;
  if (hundreds != 0) {
    Serial1.write((unsigned char)(hundreds+48));
  }
  Serial1.write((unsigned char)(tens+48));
  Serial1.write((unsigned char)(ones+48));  

  Serial1.write((unsigned char)0x00);  // send terminator byte
  
  display_readAck();
}

/**
 * Sends the Control(mode, value) command to the LCD.
 * @param[in] mode Mode byte.
 * @param[in] value Value to set Mode to.s
 */

void display_control(uint8_t mode, uint8_t value) {
  Serial1.write(DISPLAY_CMD_CONTROL);
  Serial1.write(mode);
  Serial1.write(value);
  
  display_readAck();
}

/**
 * Sends the Clear() command to the LCD.
 */
void display_clear() {
  Serial1.write(DISPLAY_CMD_CLEAR);
  
  display_readAck();
}

void display_initialize() {
  int cnt = 0;
  while (1) {
    Serial1.write(DISPLAY_CMD_AUTOBAUD);
    if (display_readAck() == DISPLAY_RESP_ACK) {
      return;
    }
  }
}



void drawGaugeNeedle(int centerX, int centerY, int rad, int pct, int color) {
  int angle = endAngle - startAngle;
  angle *= pct;
  angle /= 100;
  angle += startAngle;
  
  double angleRad = angle;
  angleRad *= PI/180;
  
  int endX = centerX - (int)(rad * cos(angleRad));
  int endY = centerY - (int)(rad * sin(angleRad));
  
  drawLine(centerX, centerY, endX, endY, color);
  if (display_readAck() == DISPLAY_RESP_ACK) {
    return;
  }
}

void clearGauge(int centerX, int centerY, int rad, int color){
  drawCircle(centerX, centerY, rad, color);
}

void updateGaugeNeedle(int x, int y, int rad, int pct, int color, int bg) {
  int centerX = 50 + 100*x;
  int centerY = 50 + 100*y;
  
  clearGauge(centerX, centerY, rad, bg);
  drawGaugeNeedle(centerX, centerY, rad, pct, color);
  if (display_readAck() == DISPLAY_RESP_ACK) {
    return;
  }
}



void updateGaugeText(int x, int y, int bottom, long value) {
  drawInteger(40 + 100*x, 60 + 100*y, FONT_5x7, white, 2, 2, value);
  if (display_readAck() == DISPLAY_RESP_ACK) {
    return;
  }
}

void updateTritium(int bus, int velocity) {
  if (bus) {
    if (screen == MAIN) {
      updateGaugeNeedle(2, 0, rad, 100*bus_voltage/max_bus_voltage, white, black);
      updateGaugeNeedle(1, 0, rad, 100*bus_current/max_bus_current, white, black);

      updateGaugeText(2, 0, 0, bus_voltage);
      updateGaugeText(1, 0, 0, bus_current);
    }
  }
  if (display_readAck() == DISPLAY_RESP_ACK) {
    return;
  }
}

void updateSolar(int mod1, int mod2, int mod3, int mod4, int mod5) {
  if (mod5) {
    if (screen == MAIN) {
      updateGaugeNeedle(2, 1, rad, 100*solar_voltage/max_solar_voltage, white, black);
      updateGaugeNeedle(1, 1, rad, 100*solar_current/max_solar_current, white, black);
      updateGaugeText(2, 1, 0, solar_voltage);
      updateGaugeText(1, 1, 0, solar_current);
    }
  } 
  if (display_readAck() == DISPLAY_RESP_ACK) {
    return;
  }
}

void updateBatteryVoltage(int bps) {
  if (bps) {
    if (screen == MAIN) {
      updateGaugeNeedle(0, 0, rad, 100*battery_voltage/max_battery_voltage, white, black);   
      updateGaugeText(0, 0, 0, battery_voltage);
    }
  }
  if (display_readAck() == DISPLAY_RESP_ACK) {
    return;
  }
}

void updateBatteryTemp(int e01, int e02, int i0, int e11, int e12, int i1, int e21, int e22, int i2) {
  if (e01) {
    if (screen == MAIN) {
      updateGaugeNeedle(0, 1, rad, 100*battery_temp0/max_battery_temp0, white, black);
      updateGaugeText(0, 1, 0, battery_temp0);
    }
  } 
  if (display_readAck() == DISPLAY_RESP_ACK) {
    return;
  }
}



/**
 * Draws a circular gauge frame
 */
void drawGaugeFrame(int centerX, int centerY, int radInner, int radOuter,
  int startAngle, int endAngle, int incrAngle,
  int ylwAngle, int grnAngle, int redAngle) {
  double currRad = startAngle;
  double incrRad = incrAngle;
  int color = red;
  int lineColor = white;
  
  currRad *= PI/180;
  incrRad *= PI/180;

  int startX = 0;
  int startY = 0;

  int nextStartX = centerX - (int)(radInner * cos(currRad));
  int nextStartY = centerY - (int)(radInner * sin(currRad));
    
  for (int i=startAngle;i<=endAngle;i+=incrAngle) {
    int endX = centerX - (int)(radOuter * cos(currRad));
    int endY = centerY - (int)(radOuter * sin(currRad));
    
    currRad += incrRad;
    
    startX = nextStartX;
    startY = nextStartY;
    nextStartX = centerX - (int)(radInner * cos(currRad));
    nextStartY = centerY - (int)(radInner * sin(currRad));

    if (i + incrAngle > redAngle) {
      color = red;
      drawLine(startX, startY, endX, endY, red);
    } else if (i + incrAngle > grnAngle) {
      lineColor = yellow;
      drawLine(startX, startY, endX, endY, lineColor);
      drawLine(startX, startY, nextStartX, nextStartY, lineColor);
    } else if (i + incrAngle > ylwAngle) {
      lineColor = green;
      drawLine(startX, startY, endX, endY, lineColor);
      drawLine(startX, startY, nextStartX, nextStartY, lineColor);
    } else {
      drawLine(startX, startY, endX, endY, blue);
    }
  }  
  if (display_readAck() == DISPLAY_RESP_ACK) {
    return;
  }
}


void setupGauge(int x, int y, char* string) {
  
  drawString(10 + 100*x, 90+100*y,
    FONT_5x7, white, defaultFontWidth, defaultFontHeight,
    string);
  drawGaugeFrame(50 + 100*x, 50 + 100*y, 35, 45, -40, 220, 20,
    80, 120, 180);

  if (display_readAck() == DISPLAY_RESP_ACK) {
    return;
  }
}

void clearText(int x, int y) {
  int startX = 0;
  int startY = 0;
  startX = 50 + 100*x;
  startY = 210 + 10*y;
  drawRect(startX, startY, startX + 50, startY + 9, black);

  if (display_readAck() == DISPLAY_RESP_ACK) {
    return;
  }
}

void writeStatusLine(int x, int y, int stat) {
  int startX = 0;
  int startY = 0;
  startX = 50 + 100*x;
  startY = 210 + 10*y;
  if (stat == ONLINE) {
    drawString(startX, startY,
    FONT_5x7, green, defaultFontWidth, defaultFontHeight,
    "Online");
  }
  else {
    drawString(startX, startY,
    FONT_5x7, red, defaultFontWidth, defaultFontHeight,
    "Offline");  
  }  
  if (display_readAck() == DISPLAY_RESP_ACK) {
    return;
  }
}

void checkSystemStatus() {
  time = millis();
  battdif = time - battery_last_received;
  solardif = time - solar_last_received;
  motordif = time - tritium_last_received;
  

  batteryok = OFFLINE;
  solarok = ONLINE;

//  if (battdif >  500 & batteryok == ONLINE) {
//    batteryok = OFFLINE;
//    batt = 1;
//  }
//  if (battdif < 500 & batteryok == OFFLINE) {
//    batteryok = ONLINE;
//    batt = 1;
//  }
//  if (solardif >  500 & solarok == ONLINE) {
//    solarok = OFFLINE;
//    solar = 1;
//  }
//  if (solardif < 500 & solarok == OFFLINE) {
//    solarok = ONLINE;
//    solar = 1;
//  }
//  if (motordif >  500 & motorok == ONLINE) {
//    motorok = OFFLINE;
//    motor = 1;
//  }
//  if (motordif < 500 & motorok == OFFLINE) {
//    motorok = ONLINE;
//    motor = 1;
//  }
//  
  if (screen == MAIN) {
    if (batt) {
      clearText(0, 0);
      writeStatusLine(0, 0, batteryok);
      batt = 0;
    }
    if (motor) {
      clearText(1, 0);
      writeStatusLine(1, 0, motorok);
      motor = 0;
    }
    if(solar) {
      clearText(1, 1);
      writeStatusLine(1, 1, solarok);
      solar = 0;
    }
  } 
  if (display_readAck() == DISPLAY_RESP_ACK) {
    return;
  }
}


// process_packet code, handle cases here
/* Declare your state variables here */

void process_packet(CanMessage &msg) {
  switch(msg.id) {
    /* Add cases for each CAN message ID to be received*/
    case CAN_TRITIUM_BUS:
      bus_voltage = ((two_floats*)msg.data)->f[0];
      bus_current = ((two_floats*)msg.data)->f[1];
      tritium_last_received = millis();
      last_received = millis();
      updateTritium(1, 0);
      clearText(0, 2);
      writeStatusLine(0, 2, ONLINE);
      break;
    case CAN_TRITIUM_VELOCITY:
      motor_speed = ((two_floats*)msg.data)->f[0];
      measured_speed = ((two_floats*)msg.data)->f[1];
      tritium_last_received = millis();
      last_received = millis();
      clearText(0, 2);
      writeStatusLine(0, 2, ONLINE);
    // NOTE implement running average for MPPT data, for now using module 5
    case MPPT_5:
      solar_voltage = ((two_floats*)msg.data)->f[3];
      solar_current = ((two_floats*)msg.data)->f[2];
      solar_last_received = millis();
      last_received = millis();
      updateSolar(0, 0, 0, 0, 1);
      clearText(0, 2);
      writeStatusLine(0, 2, ONLINE);
    case BATTERY_MOD_0_0:
      battery_volt0 = ((two_floats*)msg.data)->f[0];
      last_received = millis();
      battery_last_received = millis();
      clearText(0, 2);
      writeStatusLine(0, 2, ONLINE);
    case BATTERY_EXT_0:
      battery_temp0 = ((two_floats*)msg.data)->f[0];
      last_received = millis();
      battery_last_received = millis();
      clearText(0, 2);
      writeStatusLine(0, 2, ONLINE);
//    case CUTOFF_VOLTAGE:
//      battery_voltage = ((two_floats*)msg.data)->f[1];
//      last_received = millis();
//      updateBatteryVoltage(1);
//      clearText(0, 2);
//      writeStatusLine(0, 2, ONLINE);
    default:
      break;
  }
}

      
    
// BEGIN setup and running code    
void setup(){
  pinMode(12,OUTPUT);
  digitalWrite(12,HIGH);
  
  /* Can Initialization w/o filters */
//  Can.attach(&process_packet);    
//  Can.begin(1000, false);
  Can.begin(1000);
  CanBufferInit();
  Serial.begin(115200);
  Serial1.begin(9600);

  display_initialize();

  delay(1000);

  display_initialize();  
  display_control(DISPLAY_MODE_ORIENTATION, DISPLAY_ORIENTATION_LANDSCAPE);

  display_clear();
  
  
  bus_voltage = 50.0;
  bus_current = 50.0;
  battery_voltage = 50.0;
  battery_temp0 = 50.0;
  solar_current = 50.0;
  solar_voltage = 50.0;

  // NOTE: not fully implemented!!
  // top left gauge
  setupGauge(0, 0, "Battery Voltage");
  // gauge is voltage stored
  
  // top middle gauge
  setupGauge(1, 0, "MC Current");
  
  // top right
  setupGauge(2, 0, "MC Voltage");
  
  // bottom left
  setupGauge(0, 1, "Battery Temp");
  
  // bottom middle
  setupGauge(1, 1, "Solar Current");
  
  // bottom right
  setupGauge(2, 1, "Solar Voltage");
  
  
  
 
 // not useful right now... change later!!!
 // LOOKATME!!!
 // creates system status at bottom 
  drawString(10, 210,
    FONT_5x7, white, defaultFontWidth, defaultFontHeight,
    "Batt:");
  drawString(10, 220,
    FONT_5x7, white, defaultFontWidth, defaultFontHeight,
    "Solar:");
  drawString(10, 230,
    FONT_5x7, white, defaultFontWidth, defaultFontHeight,
    "LstMsg:");
  drawString(50, 210,
    FONT_5x7, INITSTATCOL, defaultFontWidth, defaultFontHeight,
    INITIALSTAT);
  drawString(50, 220,
    FONT_5x7, INITSTATCOL, defaultFontWidth, defaultFontHeight,
    INITIALSTAT);
  drawString(50, 230,
    FONT_5x7, INITSTATCOL, defaultFontWidth, defaultFontHeight,
    INITIALSTAT);
    
  drawString(110, 210,
    FONT_5x7, white, defaultFontWidth, defaultFontHeight,
    "Motor:");  
  drawString(110, 220,
    FONT_5x7, white, defaultFontWidth, defaultFontHeight,
    "Cutoff:");  
  drawString(150, 210,
    FONT_5x7, INITSTATCOL, defaultFontWidth, defaultFontHeight,
    INITIALSTAT);
  drawString(150, 220,
    FONT_5x7, INITSTATCOL, defaultFontWidth, defaultFontHeight,
    INITIALSTAT);
    
  drawString(210, 210,
    FONT_5x7, white, defaultFontWidth, defaultFontHeight,
    "Sys:");  
  drawString(210, 220,
    FONT_5x7, white, defaultFontWidth, defaultFontHeight,
    "Temp:");  
  drawString(250, 210,
    FONT_5x7, INITSTATCOL, defaultFontWidth, defaultFontHeight,
    INITIALSTAT);
  drawString(250, 220,
    FONT_5x7, INITSTATCOL, defaultFontWidth, defaultFontHeight,
    INITIALSTAT);

}



// code in loops is currently a test
int status = 1;
  
void loop() {
  // remove all code in loop when test with CAN
    updateTritium(status, status);
    updateSolar(status, status, status, status, status);
  
    updateBatteryVoltage(status);
    updateBatteryTemp(status, status, status, status, status, status, status, status, status);

 // check system status portion not fully implemented, can be left in
 // not set up in Can.attach yet
    checkSystemStatus();
    
  if (CanBufferSize()) {
    CanMessage msg = CanBufferRead();
    Serial.println(msg.id);
    clearText(0, 2);
    writeStatusLine(0, 2, OFFLINE);
    switch(msg.id) {
    /* Add cases for each CAN message ID to be received*/
    case CAN_TRITIUM_BUS:
      bus_voltage = ((two_floats*)msg.data)->f[0];
      bus_current = ((two_floats*)msg.data)->f[1];
      tritium_last_received = millis();
      last_received = millis();
      updateTritium(1, 0);
      clearText(0, 2);
      writeStatusLine(0, 2, ONLINE);
      break;
    case CAN_TRITIUM_VELOCITY:
      motor_speed = ((two_floats*)msg.data)->f[0];
      measured_speed = ((two_floats*)msg.data)->f[1];
      tritium_last_received = millis();
      last_received = millis();
      clearText(0, 2);
      writeStatusLine(0, 2, ONLINE);
    // NOTE implement running average for MPPT data, for now using module 5
    case MPPT_5:
      solar_voltage = ((two_floats*)msg.data)->f[3];
      solar_current = ((two_floats*)msg.data)->f[2];
      solar_last_received = millis();
      last_received = millis();
      updateSolar(0, 0, 0, 0, 1);
      clearText(0, 2);
      writeStatusLine(0, 2, ONLINE);
    case BATTERY_MOD_0_0:
      battery_volt0 = ((two_floats*)msg.data)->f[0];
      last_received = millis();
      battery_last_received = millis();
      clearText(0, 2);
      writeStatusLine(0, 2, ONLINE);
    case BATTERY_EXT_0:
      battery_temp0 = ((two_floats*)msg.data)->f[0];
      last_received = millis();
      battery_last_received = millis();
      clearText(0, 2);
      writeStatusLine(0, 2, ONLINE);
//    case CUTOFF_VOLTAGE:
//      battery_voltage = ((two_floats*)msg.data)->f[1];
//      last_received = millis();
//      updateBatteryVoltage(1);
//      clearText(0, 2);
//      writeStatusLine(0, 2, ONLINE);
    default:
      break;
  }
  }
    
  
    status = 0;
  
}