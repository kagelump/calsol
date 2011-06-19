/*
 * File:   i2c-phy.c
 * Author: Ducky
 *
 * Created on January 30, 2011, 1:17 AM
 */
#include "i2c-phy.h"

/**
 * One-time initialization of the I2C transceiver.
 * The I2C BRG is not set here since it is device dependent.
 */
inline void I2C_Init() {
	I2C1CONbits.I2CEN = 1;
}

/**
 * Sends a start bit. This function blocks until the start bit completes.
 * 
 * @return Whether it was successful or not.
 * @retval 0 Start bit not sent - bus busy.
 * @retval 1 Start bit sent successfully.
 */
inline uint8_t I2C_SendStart() {
	if (!I2C1STATbits.P && I2C1STATbits.S) {
		return 0;
	}
	I2C1CONbits.SEN = 1;
	while (I2C1CONbits.SEN);	// wait for start condition to end

	return 1;
}

/**
 * Sends a repeated start bit. This function blocks until the stop bit completes.
 */
inline void I2C_SendRepeatedStart() {
	while ((I2C1CON & 0b11111) != 0);
	
	I2C1CONbits.RSEN = 1;
	while (I2C1CONbits.RSEN);	// wait for start condition to end
}

/**
 * Sends a stop bit. This function blocks until the stop bit completes.
 */
inline void I2C_SendStop() {
	while ((I2C1CON & 0b11111) != 0);
	
	I2C1CONbits.PEN = 1;
	while(I2C1CONbits.PEN);
}

/**
 * Puts a data byte on the I2C bus. This function blocks until the transmission completes.
 * @param[in] data Data byte to transmit.
 * @return The ACK bit from the device.
 * @retval 0 Device has sent an acknowledge.
 * @retval 1 Device has not sent an acknowledge.
 */
inline uint8_t I2C_SendByte(uint8_t data) {
	// TODO Error checking I2C IWCOL
	I2C1TRN = data;
	while(I2C1STATbits.TRSTAT);

	return I2C1STATbits.ACKSTAT;
}

/**
 * Puts the 7-bit device address plus R/W bit on the I2C bus. This function blocks until the transmission completes.
 * @param[in] address 7-bit I2C device address.
 * @param[in] rw Read or /Write (1 for read, 0 for write).
 * @return The NACK bit from the device.
 * @retval 0 Device has sent an acknowledge.
 * @retval 1 Device has not sent an acknowledge.
 */
inline uint8_t I2C_Send7BitAddress(uint8_t address, uint8_t rw) {
	return I2C_SendByte((address << 1) | (rw & 0x01));
}

// TODO Implement 10bit I2C support

/**
 * Reads a byte from a I2C device. This function blocks until the transmission is complete.
 *
 * Typically, an NACK is generated on the last read.
 * @param[in] nack Generate a ACK (0) or NACK (1) bit at the end of the message.
 * @param[out] data Data byte read from the device.
 * @return Success or failure.
 * @retval 0 Failure - data read timed out, data byte is not valid.
 * @retval 1 Success - data byte is valid.
 *
 * @bug It is up to the user to handle a timeout and to possibly initiate recovery procedures.
 * As it is, a timeout will return from this function, but will cause further I2C fucntion calls to
 * go into an infinite loop.
 */
inline uint8_t I2C_ReadByte(uint8_t nack, uint8_t *data) {
	uint16_t timeout;
	
	while ((I2C1CON & 0b11111) != 0);
	
	I2C1CONbits.RCEN = 1;
	for (timeout=0; timeout<I2C_TIMEOUT*I2C1BRG && !I2C1STATbits.RBF; timeout++);
	if (I2C1STATbits.RBF) {
		*data = I2C1RCV;
	} else {
		return 0;
	}
	
	// Generate Acknowledge
	while ((I2C1CON & 0b11111) != 0);
	I2C1CONbits.ACKDT = nack;
	I2C1CONbits.ACKEN = 1;

	while (I2C1CONbits.ACKEN);

	return 1;
}
