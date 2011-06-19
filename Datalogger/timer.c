/*
 * File:   timer.c
 * Author: Ducky
 *
 * Created on January 15, 2011, 11:12 PM
 *
 * Timer Library
 */
// TODO: Needs major rework.
#include "hardware.h"

#include "timer.h"

volatile unsigned char trig = 0;

/**
 * One-time initialization of the Timer 1 module.
 */
void Timer_Init() {
	T1CONbits.TCKPS = 0b00;	// 1:1 prescale
	T1CONbits.TCS = 0;		// internal clock, Fcy
	T1CONbits.TSIDL = 0;	// continue in idle mode
	PR1 = TIMER_PERIOD;
	IEC0bits.T1IE = 1;		// enable interrupt
}

/**
 * Delays (using idle mode) for @a delay milliseconds.
 * This uses the Timer 1 resource.
 *
 * @note Since this puts the device into Idle mode, ensure background operations
 *		intended to continue operating stay enabled during Idle.
 * @param delay Amount of time to delay, in milliseconds.
 */
void Timer_Delay (unsigned int delay) {
	T1CONbits.TON = 1;
	TMR1 = 0;

	while (delay != 0) {
		if (!IFS0bits.T1IF) {
			Idle();
		}
		if (trig == 1) {
			trig = 0;
			delay--;
		}
	}
	T1CONbits.TON = 0;
}

/**
 * Starts the Timer.
 * @deprecated
 * @note awaiting rework
 */
void Timer_Start() {
	T1CONbits.TON = 1;
	TMR1 = 0;
}

/**
 * Stops the Timer.
 * @deprecated
 * @note awaiting rework
 */
void Timer_Stop() {
	T1CONbits.TON = 0;
}

/**
 * Checks if the timer was triggered
 * @deprecated
 * @note awaiting rework
 *
 * @return Whether the timer was triggered.
 * @retval 1 if the timer was triggered.
 * @retval 0 if the timer was not triggered.
 */
unsigned char Timer_GetTriggered() {
	unsigned char rtn = trig;
	trig = 0;
	return rtn;
}

// Interrupt Handler
void _ISRFAST __attribute__((interrupt, auto_psv)) _T1Interrupt(void)
{
	IFS0bits.T1IF = 0;
	trig = 1;
}
