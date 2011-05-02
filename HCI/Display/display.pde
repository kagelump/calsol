const int FONT_5x7 = 0x00;
const int FONT_8x8 = 0x01;
const int FONT_8x12 = 0x02;
const int FONT_12x16 = 0x03;

const int white = 0xffff;
const int red = 0xf800;
const int yellow = 0xffe0;
const int green = 0x07e0;
const int black = 0x0000;

const int defaultFont = FONT_12x16;  // default font byte
const int defaultFontWidth = 1;
const int defaultFontHeight = 1;

const int DISPLAY_INITIALIZE_DELAY = 500;  /// Time between putting the LCD out of reset and sending commands

const int DISPLAY_CMD_TIMEOUT = 100;  /// Time in ms before commands are retransmitted
const int DISPLAY_RESP_DELAY = 1;  /// Time in ms beetween checks for responses

const uint8_t DISPLAY_RESP_ACK = 0x06;
const uint8_t DISPLAY_RESP_NACK = 0x15;

const uint8_t DISPLAY_CMD_AUTOBAUD = 0x55;
const uint8_t DISPLAY_CMD_CONTROL = 0x59;
const uint8_t DISPLAY_MODE_ORIENTATION = 0x04;
const uint8_t DISPLAY_ORIENTATION_LANDSCAPE = 0x01;
const uint8_t DISPLAY_CMD_CLEAR = 0x45;

//const double PI = 3.14159;

uint8_t display_readAck() {
  int i = 0;
  while (i < DISPLAY_CMD_TIMEOUT) {
    if (Serial.available() > 0) {
      uint8_t resp = Serial.read();
      return resp;
    }
    i += DISPLAY_RESP_DELAY;
    delay(DISPLAY_RESP_DELAY);
  }
  return 0x00;
}

void drawBlueBackground(){
  Serial.write(0x42); //send command to change background color
  Serial.write((unsigned char)0x0); //zero red, zero green, unsigned char cast needed for zero  because of dumb compiler issues
  Serial.write(0x1f); //max blue value
}

void drawLine(int xStartPos, int yStartPos, int xEndPos, int yEndPos, int color){
  Serial.write(0x4c); //send command
  
  Serial.write((unsigned char)(xStartPos >>8)&0xff); //send off xStartPos
  Serial.write((unsigned char)xStartPos&0xff);
  
  Serial.write((unsigned char)(yStartPos >>8)&0xff); //send off xStartPos
  Serial.write((unsigned char)yStartPos&0xff);
  
  Serial.write((unsigned char)(xEndPos >>8)&0xff); //send off xStartPos
  Serial.write((unsigned char)xEndPos&0xff);
  
  Serial.write((unsigned char)(yEndPos >>8)&0xff); //send off xStartPos
  Serial.write((unsigned char)yEndPos&0xff);
  
  Serial.write((unsigned char)(color>>8)&0xff);
  Serial.write((unsigned char)color&0xff);

  display_readAck();
}

void drawCircle(int xCoor, int yCoor, int radius, int color){
  Serial.write(0x43);
  
  Serial.write((unsigned char)(xCoor>>8)&0xff);
  Serial.write((unsigned char)xCoor&0xff);
  
  Serial.write((unsigned char)(yCoor>>8)&0xff);
  Serial.write((unsigned char)yCoor&0xff);
  
  Serial.write((unsigned char)(radius>>8)&0xff);
  Serial.write((unsigned char)radius&0xff);
  
  Serial.write((unsigned char)(color>>8)&0xff);
  Serial.write((unsigned char)color&0xff);

  display_readAck();
}

void drawTriangle(int x1, int y1, int x2, int y2, int x3, int y3, int color){
  Serial.write(0x47);
  
  Serial.write((unsigned char)(x1>>8)&0xff);
  Serial.write((unsigned char)(x1&0xff));
  
  Serial.write((unsigned char)(y1>>8)&0xff);
  Serial.write((unsigned char)(y1&0xff));
  
  Serial.write((unsigned char)(x2>>8)&0xff);
  Serial.write((unsigned char)(x2&0xff));
  
  Serial.write((unsigned char)(y2>>8)&0xff);
  Serial.write((unsigned char)(y2&0xff));
  
  Serial.write((unsigned char)(x3>>8)&0xff);
  Serial.write((unsigned char)(x3&0xff));
  
  Serial.write((unsigned char)(y3>>8)&0xff);
  Serial.write((unsigned char)(y3&0xff));
  
  Serial.write((unsigned char)(color>>8)&0xff);
  Serial.write((unsigned char)color&0xff);
}

void drawRect(int x1, int y1, int x2, int y2, int color){
  Serial.write(0x72);
  
  Serial.write((unsigned char)(x1>>8)&0xff);
  Serial.write((unsigned char)x1&0xff);
  
  Serial.write((unsigned char)(y1>>8)&0xff);
  Serial.write((unsigned char)y1&0xff);
  
  Serial.write((unsigned char)(x2>>8)&0xff);
  Serial.write((unsigned char)x2&0xff);
  
  Serial.write((unsigned char)(y2>>8)&0xff);
  Serial.write((unsigned char)y2&0xff);
  
  Serial.write((unsigned char)(color>>8)&0xff);
  Serial.write((unsigned char)color&0xff);

}

void drawEllipse(int x1, int y1, int xmaj, int ymin, int color){
  Serial.write(0x72);
  
  Serial.write((unsigned char)(x1>>8)&0xff);
  Serial.write((unsigned char)x1&0xff);
  
  Serial.write((unsigned char)(y1>>8)&0xff);
  Serial.write((unsigned char)y1&0xff);
  
  Serial.write((unsigned char)(xmaj>>8)&0xff);
  Serial.write((unsigned char)xmaj&0xff);
  
  Serial.write((unsigned char)(ymin>>8)&0xff);
  Serial.write((unsigned char)ymin&0xff);
  
  Serial.write((unsigned char)(color>>8)&0xff);
  Serial.write((unsigned char)color&0xff);

}


void drawASCII(int symb, int xCoor, int yCoor, int symbColor, int width, int height){
  Serial.write(0x74);
  
  Serial.write((unsigned char)symb);
  
  Serial.write((unsigned char)(xCoor>>8)&0xff);
  Serial.write((unsigned char)(xCoor&0xff));
  
  Serial.write((unsigned char)(yCoor>>8)&0xff);
  Serial.write((unsigned char)(yCoor&0xff));
  
  Serial.write((unsigned char)(symbColor>>8)&0xff);
  Serial.write((unsigned char)(symbColor&0xff));
  
  Serial.write(width);
  Serial.write(height);
}

void drawString(int xCoor, int yCoor, int font, int stringColor, int width, int height, char* string) {
  Serial.write(0x53);
  
  Serial.write((unsigned char)(xCoor>>8)&0xff);
  Serial.write((unsigned char)(xCoor&0xff));
  
  Serial.write((unsigned char)(yCoor>>8)&0xff);
  Serial.write((unsigned char)(yCoor&0xff));
  
  Serial.write((unsigned char)font);
  
  Serial.write((unsigned char)(stringColor>>8)&0xff);
  Serial.write((unsigned char)(stringColor&0xff));
  
  Serial.write((unsigned char)width);
  Serial.write((unsigned char)height);

  while (*string != 0) {
    Serial.write((unsigned char)*string);
    string++;
  }

  Serial.write((unsigned char)0x00);  // send terminator byte
  
  display_readAck();
}

/**
 * Sends the Control(mode, value) command to the LCD.
 * @param[in] mode Mode byte.
 * @param[in] value Value to set Mode to.s
 */

void display_control(uint8_t mode, uint8_t value) {
  Serial.write(DISPLAY_CMD_CONTROL);
  Serial.write(mode);
  Serial.write(value);
  
  display_readAck();
}

/**
 * Sends the Clear() command to the LCD.
 */
void display_clear() {
  Serial.write(DISPLAY_CMD_CLEAR);
  
  display_readAck();
}

void display_initialize() {
  int cnt = 0;
  while (1) {
    Serial.write(DISPLAY_CMD_AUTOBAUD);
    if (display_readAck() == DISPLAY_RESP_ACK) {
      return;
    }
  }
}

void drawGaugeNeedle(int centerX, int centerY, int rad,
  int startAngle, int endAngle, int pct, int color) {
  int angle = endAngle - startAngle;
  angle *= pct;
  angle /= 100;
  angle += startAngle;
  
  double angleRad = angle;
  angleRad *= PI/180;
  
  int endX = centerX - (int)(rad * cos(angleRad));
  int endY = centerY - (int)(rad * sin(angleRad));
  
  drawCircle(centerX, centerY, rad, black);
  drawLine(centerX, centerY, endX, endY, color);
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
      lineColor = green;
      drawLine(startX, startY, endX, endY, white);
      drawLine(startX, startY, nextStartX, nextStartY, green);
    } else if (i + incrAngle > ylwAngle) {
      lineColor = yellow;
          drawLine(startX, startY, endX, endY, white);
      drawLine(startX, startY, nextStartX, nextStartY, yellow);
    } else {
      drawLine(startX, startY, endX, endY, red);
    }
  }  
}
    
void setup(){
  pinMode(12,OUTPUT);
  digitalWrite(12,HIGH);
    
  Serial.begin(9600);

  display_initialize();
  
  delay(1000);

  display_initialize();  
  display_control(DISPLAY_MODE_ORIENTATION, DISPLAY_ORIENTATION_LANDSCAPE);

  for (int x=0;x<3;x++) {
    for (int y=0;y<2;y++) {
      drawString(10 + 100*x, 90+100*y,
        FONT_5x7, white, defaultFontWidth, defaultFontHeight,
        "Battery");
      drawGaugeFrame(50 + 100*x, 50 + 100*y, 35, 45, -40, 220, 20,
        80, 120, 180);
    }
  }
  drawString(10, 210,
    FONT_5x7, white, defaultFontWidth, defaultFontHeight,
    "Sys:");
  drawString(10, 220,
    FONT_5x7, white, defaultFontWidth, defaultFontHeight,
    "Comms:");
  drawString(50, 210,
    FONT_5x7, green, defaultFontWidth, defaultFontHeight,
    "Online");
  drawString(50, 220,
    FONT_5x7, red, defaultFontWidth, defaultFontHeight,
    "Offline");
    
  drawString(110, 210,
    FONT_5x7, white, defaultFontWidth, defaultFontHeight,
    "TCAS:");  // "Traffic Collision Avoidance System"
  drawString(110, 220,
    FONT_5x7, white, defaultFontWidth, defaultFontHeight,
    "EJECT:");  // "Ejection Seat"
  drawString(150, 210,
    FONT_5x7, red, defaultFontWidth, defaultFontHeight,
    "Offline");
  drawString(150, 220,
    FONT_5x7, red, defaultFontWidth, defaultFontHeight,
    "Offline");
    
  drawString(210, 210,
    FONT_5x7, white, defaultFontWidth, defaultFontHeight,
    "XPDR:");  // "Transponder"
  drawString(210, 220,
    FONT_5x7, white, defaultFontWidth, defaultFontHeight,
    "CVR:");  // "Cockpit Voice Recorder"
  drawString(250, 210,
    FONT_5x7, red, defaultFontWidth, defaultFontHeight,
    "Offline");
  drawString(250, 220,
    FONT_5x7, red, defaultFontWidth, defaultFontHeight,
    "Offline");
}

void displayStringTest() {
    char outString[3];
  outString[0] = '0';
  outString[1] = '0';
  outString[2] = 0;

  digitalWrite(13,LOW);

  while(1) {
    digitalWrite(13,HIGH);
    drawString(85 + 25*(outString[0] - '0'),
      10 + 20*(outString[1] - '0'),
      defaultFont, random(0,65535), defaultFontWidth, defaultFontHeight,
      outString);
    outString[1]++;
    if (outString[1] > '9') {
      outString[1] = '0';
      outString[0]++;
    }
    if (outString[0] > '9') {
      break;
    }

    display_clear();
    digitalWrite(13,LOW);   
  }
}

void loop() {
  for (int i=0;i<=100;i++){
    for (int x=0;x<3;x++) {
      for (int y=0;y<2;y++) {
        drawGaugeNeedle(50 + 100*x, 50 + 100*y, 30, -40, 220, i, white);
      }
    }
  }

}

