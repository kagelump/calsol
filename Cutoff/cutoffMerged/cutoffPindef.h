/* CalSol - UC Berkeley Solar Vehicle Team 
 * cutoffPindef.h - Cutoff Module
 * Purpose: Pin Definitions for the cutoff module
 * Author(s): Jimmy Hack, Ryan Tseng, Brian Duffy
 * Date: Jun 18th 2011
 */

#ifndef _CUTOFF_PINDEF_H_
#define _CUTOFF_PINDEF_H_
#include <WProgram.h>

/* PINOUTS */
#define BUZZER   12
//relays
#define RELAY1   18
#define RELAY2   19
#define RELAY3   20  //no led
#define LVRELAY  13
//leds
#define LED1     23
#define LED2     22
#define LEDFAIL  14
#define CANINT    3
//readings
#define CGND     5 //we cannot just write digital pin 26!  Need to use the Analog Pin numbers for analog reads.  These are different than the digital pin numbers
#define C1       3 //digital 28
#define C2       4 //digital 27
#define V1       1 //digital 30
#define V2       2 //digital 29
//input/output
//bottom port
#define IO_B1     7
#define IO_B2     6
#define IO_B3     5
#define IO_B4     7
//top port
#define IO_T1     2   //OFF SWITCH
#define IO_T2     1   //SONG 1 (Tetris)
#define IO_T3     0   //SONG 2 (Bad Romance)
#define IO_T4    31   //Analog 0

void initPins() {
  //initialize pinouts
  pinMode(BUZZER, OUTPUT);
  digitalWrite(BUZZER, LOW);
  pinMode(RELAY1, OUTPUT);
  pinMode(RELAY2, OUTPUT);
  pinMode(RELAY3, OUTPUT);
  pinMode(LVRELAY, OUTPUT);
  pinMode(LEDFAIL, OUTPUT);
  pinMode(LED1, OUTPUT);
  digitalWrite(LED1, LOW);
  pinMode(LED2, OUTPUT);  
  digitalWrite(LED2, LOW);
  pinMode(IO_T1, INPUT); //OFF SWITCH
  digitalWrite(IO_T1, HIGH);
  pinMode(IO_T2, INPUT); //Song 1
  digitalWrite(IO_T2, HIGH);
  pinMode(IO_T3, INPUT); //Song 
  digitalWrite(IO_T3, HIGH);
  pinMode(IO_T4, OUTPUT);
  pinMode(IO_B1, OUTPUT);
  pinMode(IO_B2, OUTPUT);
  pinMode(IO_B3, OUTPUT);
  pinMode(IO_B4, OUTPUT);
  
  pinMode(V1, INPUT);
  digitalWrite(V1, HIGH);
  pinMode(V2, INPUT);
  digitalWrite(V2, HIGH);
}
#endif
