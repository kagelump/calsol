/*
 * File:   hardware.h
 * Author: Ducky
 *
 * Created on January 15, 2011, 5:22 PM
 *
 * This file contains the definitions for hardware IO pins
 */
#ifndef HARDWARE_H
#define HARDWARE_H

#if defined(__PIC24HJ128GP502__)
#include "C:\Program Files (x86)\Microchip\mplabc30\v3.25\support\PIC24H\h\p24Hxxxx.h"
#elif defined (__dsPIC33FJ128MC802__)
//#include "C:\Program Files (x86)\Microchip\mplabc30\v3.25\support\dsPIC33F\h\p33Fxxxx.h"
#include <p33Fxxxx.h>
#elif
#error "hardware.h: Processor not listed"
#endif

/*
 * Clock Settings
 */
#define Fosc 40000000
#define Fcy (Fosc/2)

/*
 * Onboard GPIO
 */
#define	LED_FAULT_IO		LATBbits.LATB0
#define LED_FAULT_TRIS		TRISBbits.TRISB0

/*
 * Peripheral Configuration
 */
// UART (BRG register calculated in code)
#define UART_TX_RPN		7
#define UART_TX_RPR		_RP7R
#define UART_RX_RPN		4
#define UART_RX_RPR		_RP4R

// ECAN
#define ECAN_RXD_RPN	14
#define ECAN_RXD_RPR	_RP14R
#define ECAN_TXD_RPN	15
#define ECAN_TXD_RPR	_RP15R

// SD Card SPI Interface
#define SD_SPI_CS_IO	LATAbits.LATA4
#define SD_SPI_CS_TRIS	TRISAbits.TRISA4
#define SD_SPI_SCK_RPN	2
#define SD_SPI_SCK_RPR	_RP2R
#define SD_SPI_SCK_TRIS	TRISBbits.TRISB2
#define SD_SPI_MOSI_RPN	3
#define SD_SPI_MOSI_RPR	_RP3R
#define SD_SPI_MOSI_TRIS	TRISBbits.TRISB3
#define SD_SPI_MISO_RPN	1
#define SD_SPI_MISO_RPR	_RP1R

// Alternative SPI Interface
// (to be configured based on application)

/*
 * PPS Options
 */
#define NULL_IO		0
#define C1OUT_IO	1
#define C2OUT_IO	2
#define U1TX_IO		3
#define U1RTS_IO	4
#define U2TX_IO		5
#define U2RTS_IO	6
#define SDO1_IO		7
#define SCK1OUT_IO	8
#define SS1OUT_IO	9
#define SDO2_IO		10
#define SCK2OUT_IO	11
#define SS2OUT_IO	12

#define C1TX_IO		16

#define OC1_IO		18
#define OC2_IO		19
#define OC3_IO		20
#define OC4_IO		21
#define OC5_IO		22

#endif
