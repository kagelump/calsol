/*
 * File:   sd-spi-phy.c
 * Author: Ducky
 *
 * Created on January 15, 2011, 11:02 PM
 *
 * Physical Layer of the SD Card SPI implementation
 */

#include "hardware.h"
#include "sd-spi-phy.h"

/**
 * One-time initialization of the SPI module for the SD Card in slow (<400kBit/s mode)
 * GPIO initialization (for SD SPI CS line) needs to be done elsewhere.
 * Since SPI2 is dedicated to the SD card (non-shared),
 *		timing and clock settings are done here.
 */
inline void SD_SPI_Slow_Init() {
	SPI2STATbits.SPIEN = 0;		// disable SPI module
	SPI2CON1bits.MSTEN = 1;		// master mode
	SPI2STATbits.SPIROV = 0;

	SPI2CON1 = 0b0000000001111100;	// 1:1 secondary prescale, 1:1 primary prescale
	SPI2CON2 = 0b0000000000000000;

	SPI2STATbits.SPIEN = 1;		// enable SPI module
}

/**
 * One-time initialization of the SPI module for the SD Card.
 * GPIO initialization (for SD SPI CS line) needs to be done elsewhere.
 * Since SPI2 is dedicated to the SD card (non-shared),
 *		timing and clock settings are done here.
 */
inline void SD_SPI_Init() {
	SPI2STATbits.SPIEN = 0;		// disable SPI module
	SPI2CON1bits.MSTEN = 1;		// master mode
	SPI2STATbits.SPIROV = 0;

	SPI2CON1 = 0b0000000001111011;	// 1:1 secondary prescale, 1:1 primary prescale
	SPI2CON2 = 0b0000000000000000;

	SPI2STATbits.SPIEN = 1;		// enable SPI module
}

/**
 * Opens the SPI interface for transmission of a message.
 */
inline void SD_SPI_Open() {
	SPI2STATbits.SPIROV = 0;
	SPI2STATbits.SPIEN = 1;			// Enable SPI
	SD_SPI_CS_IO = 0;				// Bring CS pin low
}

/**
 * Closes the SPI interface after transmission of a message.
 */
inline void SD_SPI_Close() {
	SD_SPI_CS_IO = 1;				// Bring CS pin high
	SPI2STATbits.SPIEN = 0;
}

/**
 * Transmits a data byte @a data over the SPI bus, and returns the response.
 * This is blocking until the transmission completes.
 *
 * @param data Data byte to be shifted out the SPI bus.
 * @return The response byte from the device.
 */
inline uint8_t SD_SPI_Transfer(uint8_t data) {
	while (SPI2STATbits.SPITBF);	// wait for empty buffer location
	SPI2BUF = data;
	while (!SPI2STATbits.SPIRBF);	// wait until data is received
	data = SPI2BUF;

	return data;
}
