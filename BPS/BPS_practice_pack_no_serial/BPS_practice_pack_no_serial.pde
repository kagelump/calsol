#include "SPI.h"  
// LTC6802-2 BMS with isolator installed 
// pin 39 - SPI Clock 
// pin 38 - MISO 
// pin 37 - MOSI 
// pin B0 - Slave Select  
#define START digitalWrite(B0,LOW); //Begins chip communication 
#define END digitalWrite(B0,HIGH); //Ends chip communication  

//Control Bytes 
#define WRCFG 0x01 //write config 
#define RDCFG 0x02 //read config 
#define RDCV  0x04 //read cell voltages 
#define RDFLG 0x06 //read voltage flags 
#define RDTMP 0x08 //read temperatures  
#define STCVAD 0x10 //start cell voltage A/D conversion 
#define STTMPAD 0x30 //start temperature A/D conversion  
#define DSCHG 0x60 //start cell voltage A/D allowing discharge
#define fan1 16
#define fan2 17

const byte boards[3] = { 0x80 , 0x81 , 0x82 };
const byte OV = 0xAB; //4.1V
const byte UV = 0x71; //2.712V
const float over = 4.1;
const float under = 2.7;
const int B = 3988;

byte config[6] = { 0xE5,0x00,0x00,0x00,UV,OV }; //Default config
int heartrate= 250; //send heartbeat every 250ms;
unsigned long lastHeartbeat =0;
unsigned long cycleTime =0;

//Write the configuration 
void writeConfig(byte*config) {
  START
  SPI.transfer(WRCFG); //configuration is written to all chips
  for(int i=0;i<6;i++) {
    SPI.transfer(config[i]);
  }
  END 
}

//Write single configuration to board
void writeConfig(byte*config,byte board) {
  START
  SPI.transfer(board); //non-broadcast command
  SPI.transfer(WRCFG); //configuration is written to all chips
  for(int i=0;i<6;i++) {
    SPI.transfer(config[i]);
  }
  END 
}

//Read the configuration for a board
void readConfig(byte*config,byte board) {
  START   
  SPI.transfer(board); //board address is selected
  SPI.transfer(RDCFG); //configuration is read
  for(int i=0;i<6;i++) {
    config[i] = SPI.transfer(RDCFG);
  }
  END
}

//Begins CV A/D conversion
void beginCellVolt() {
  START
  SPI.transfer(STCVAD);
  delay(15); //Time for conversions, approx 12ms
  END
}

//Reads cell voltage registers  
void readCellVolt(float*cv,byte board) {
  START
  SPI.transfer(board); //board address is selected
  SPI.transfer(RDCV); //cell voltages to be read
  byte cvr[18]; //buffer to store unconverted values
  for(int i=0;i<18;i++) {
    cvr[i] = SPI.transfer(RDCV);
  }
  END 

  //converting cell voltage registers to cell voltages
  cv[0] = (cvr[0] & 0xFF) | (cvr[1] & 0x0F) << 8;
  cv[1] = (cvr[1] & 0xF0) >> 4 | (cvr[2] & 0xFF) << 4;
  cv[2] = (cvr[3] & 0xFF) | (cvr[4] & 0x0F) << 8;
  cv[3] = (cvr[4] & 0xF0) >> 4 | (cvr[5] & 0xFF) << 4;
  cv[4] = (cvr[6] & 0xFF) | (cvr[7] & 0x0F) << 8;
  cv[5] = (cvr[7] & 0xF0) >> 4 | (cvr[8] & 0xFF) << 4;
  cv[6] = (cvr[9] & 0xFF) | (cvr[10] & 0x0F) << 8;
  cv[7] = (cvr[10] & 0xF0) >> 4 | (cvr[11] & 0xFF) << 4;
  cv[8] = (cvr[12] & 0xFF) | (cvr[13] & 0x0F) << 8;
  cv[9] = (cvr[13] & 0xF0) >> 4 | (cvr[14] & 0xFF) << 4;
  cv[10] = (cvr[15] & 0xFF) | (cvr[16] & 0x0F) << 8;
  cv[11] = (cvr[16] & 0xF0) >> 4 | (cvr[17] & 0xFF) << 4;
  
  for(int i=0;i<12;i++) {
    cv[i] = cv[i]*1.5*0.001;
  }
}  

void beginTemp() {
  START
  SPI.transfer(STTMPAD);
  delay(15); //Time for conversions
  END
}

//Reads temperatures
void readTemp(short*temp,byte board) {
  START
  SPI.transfer(board); //board address is selected
  SPI.transfer(RDTMP); //temperatures to be read
  byte tempr[5];
  for(int i=0;i<5;i++) {
    tempr[i] = SPI.transfer(RDTMP);
  }
  END
    //convert temperature registers to temperatures
  temp[0] = (tempr[0] & 0xFF) | (tempr[1] & 0x0F) << 8;
  temp[1] = (tempr[1] & 0xF0) >> 4 | (tempr[2] & 0xFF) << 4;
  temp[2] = (tempr[3] & 0xFF) | (tempr[4] & 0x0F) << 8;
}

// Converts external thermistor voltage readings 
// into temperature (K) using B-value equation
void convertVoltTemp(short*volt,float*temp) {
  float resist[2];
  resist[0] = (10000 / ((3.11/(volt[0]*1.5*0.001))-1));
  resist[1] = (10000 / ((3.11/(volt[1]*1.5*0.001))-1));
  float rinf = 10000 * exp(-1*(B/298.15));
  temp[0] = (B/log(resist[0]/rinf)) - 273.15;
  temp[1] = (B/log(resist[1]/rinf)) - 273.15;

  temp[2] = (volt[2]*1.5*0.125) - 273;
}

//Sends out CAN packet
void sendCAN(int ID,char*data,int size) {
  CanMessage msg = CanMessage();
  msg.id = ID; //msg id isn't decided yet
  msg.len = size;
  for(int i=0;i<size;i++) {
    msg.data[i] = data[i];
  }
  //float f = *((float*)&msg.data[0]);
  //Serial.println(ID,HEX);
  //Serial.println(f);
  Can.send(msg);
}

//Checks voltages for undervoltage
boolean checkOverVoltage(float*voltages,float limit,int length) {
  for(int i=0;i<length;i++) {
    if(voltages[i] >= limit) {
      return true;
    }
  }
  return false;
}

//Checks voltages for undervoltage
boolean checkUnderVoltage(float*voltages,float limit,int length) {
  for(int i=0;i<length;i++) {
    if(voltages[i] <= limit) {
      return true;
    }
  }
  return false;
}

//Checks temperatures within range
boolean checkTemperatures(float*temps,float limit) {
  for(int i=0;i<2;i++) {
    if(temps[i] >= limit) {
      return true;
    }
  }
  return false;
}

void setup() {
  //delay(2000);
  //asm volatile ("  jmp 0");
  Can.begin(1000);
  Serial.begin(115200);
  char init[1] = { 0x00 };
  sendCAN(0x041,init,1);
  pinMode(B0,OUTPUT);
  pinMode(fan1,OUTPUT);
  pinMode(fan2,OUTPUT);
  digitalWrite(fan1,HIGH);
  digitalWrite(fan2,HIGH);
  END //Sets Slave Select to high (unselected)
  SPI.begin();
  SPI.setClockDivider(SPI_CLOCK_DIV64);
  SPI.setDataMode(SPI_MODE3);
  SPI.setBitOrder(MSBFIRST);
  delay(500);
}

void loop() {
  config[0] = 0xE5;
  config[1] = 0x00; //Reset discharge bits
  config[2] = 0x00; //Reset discharge bits
  writeConfig(config);
  boolean discharge = false;
  boolean warning = false;
  boolean error = false;
  
  //Active Configuration
  for(int k=0;k<3;k++) {
    int length = 12;
    if(k==2) {
      length = length-3;
    }
    //Communications check
    /*
    Serial.print("Board Address: ");
    Serial.print("0x");
    Serial.println(boards[k],HEX);
    */
    byte rconfig[6];
    readConfig(rconfig,boards[k]);
    if(rconfig[0]==0xFF || rconfig[0]==0x00 || rconfig[0]==0x02) {
      //Serial.println("Board not communicating.");
      error = true;
      continue;
    }
    /*
    Serial.println("Configuration Registers: ");
    for(int i=0;i<6;i++) {
      Serial.print("|");
      Serial.print(rconfig[i] & 0xFF,HEX);
    }
    Serial.println("|");
    Serial.println("------------------------------------------");
    */

    //Reading cell voltages
    beginCellVolt();
    float cv[12];
    readCellVolt(cv,boards[k]);
    /*
    Serial.println("Cell Voltages: ");
    for(int i=0;i<length;i++) {
      Serial.print(i+1);
      Serial.print(": ");
      Serial.println(cv[i]);
    }
    Serial.println("------------------------------------------");
    */

    //Reading temperatures
    beginTemp();
    short temp[3];
    float convTemp[3];
    readTemp(temp,boards[k]);
    convertVoltTemp(temp,convTemp);
    /*
    Serial.println("Temperature: ");
    Serial.print("External 1: ");
    Serial.println(convTemp[0]);
    Serial.print("External 2: ");
    Serial.println(convTemp[1]);
    Serial.print("Internal: ");
    Serial.println(convTemp[2]);
    Serial.println("------------------------------------------");
    */
    
    //Check for absolute voltage problems
    if(checkOverVoltage(cv,4.0,length)) {
      if(checkOverVoltage(cv,over,length)) {
        char overchg[1] = { 0x01 };
        sendCAN(0x021,overchg,1);
        error = true;
        delay(10);
        Serial.println("Overvoltage cells");
        delay(30000);
      } else {
        warning = true;
        discharge = true;
      }
    }
    if(checkUnderVoltage(cv,2.8,length)) {
      if(checkUnderVoltage(cv,under,length)) {
        char underchg[1] = { 0x02 };
        sendCAN(0x021,underchg,1);
        error = true;
        delay(10);
        Serial.println("Undervoltage cells");
        delay(30000);
      } else {
          warning = true;
      }
    }
    //Check for absolute temperature problems
    if(checkTemperatures(convTemp,40)) {
      if(checkTemperatures(convTemp,45)) {
        char exceedtmp[1] = { 0x04 };
        sendCAN(0x021,exceedtmp,1);
        error = true;
        delay(10);
        Serial.println("Exceeded Temperature Limit");
        delay(30000);
      } else {
        warning = true;
      }
    }
    //Serial.println("==========================================");
    
    /*
    //Setting fans based upon temperature
    if(checkTemperatures(convTemp,38)) {
      digitalWrite(fan2,HIGH);
    } else {
      digitalWrite(fan2,LOW);
    }
    */

    //Sending out CAN packets
    for(int i=0;i<(length+3);i++) {
      char data[4];
      int ID = (1 << 8) | (k << 4) | i;
      if(i < length) {
        if(k==2 && i > 8 && i < 12) {
          continue;
        } else {
          data[0] = *((char*)&cv[i]);
          data[1] = *((char*)&cv[i]+1);
          data[2] = *((char*)&cv[i]+2);
          data[3] = *((char*)&cv[i]+3);
        }
      } else {
          data[0] = *((char*)&convTemp[i-length]);
          data[1] = *((char*)&convTemp[i-length]+1);
          data[2] = *((char*)&convTemp[i-length]+2);
          data[3] = *((char*)&convTemp[i-length]+3);
      }
      sendCAN(ID,data,4);
    }
    //Serial.println("Sent CAN packets");
    
    //Basic discharge, will discharge cells if voltage > 3.6V
    if(discharge) {
      for(int i=0;i<12;i++) {
        if(cv[i] > 3.6) {
          if(i < 8) {
            config[1] = config[1] | (1 << i); //Sets DCC bits 0-7
          } else {
            config[2] = config[2] | (1 << (i-8)); //Sets DCC bits 8-11
          }
        }
      }
      delay(10);
      Serial.println("Discharge occuring");
    }
  }
  
  if ((millis()-lastHeartbeat)>heartrate){
    //Heartbeat, tells board in case of warning or error.
    if(error) {
      char err[1] = { 0x04 };
      sendCAN(0x041,err,1);
      delay(10);
      Serial.println("Error detected");
    } else if(warning) {
      char warn[1] = { 0x01 };
      sendCAN(0x041,warn,1);
      delay(10);
      Serial.println("Warning detected");
    } else {
      char ok[1] = { 0x00 };
      sendCAN(0x041,ok,1);
      delay(10);
      Serial.println("BPS operations OK");
    }
    lastHeartbeat=millis();
  }
  
  //Standby Configuration
  if(!discharge) {
    config[0] = 0xE0;
    writeConfig(config); //Writes the standby config (low current)
  }
  //delay(500); //sends at best 2 times a second   //I think we should avoid using delay whenever possible.  There are other ways around this, like interupts and checking timers.
  unsigned long newCycleTime=millis();
  //Serial.println(newCycleTime-cycleTime);  //print out the amount of time each cycle is takin
  cycleTime=newCycleTime;
}
