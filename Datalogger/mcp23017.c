/*
 * File:   mcp23017.c
 * Author: Ducky
 *
 * Created on January 30, 2011, 5:05 PM
 */
#include "i2c-phy.h"
#include "mcp23017.h"

#include "uart.h"

/**
 * Sets up the I2C module for the MCP23017.
 * Sets the baud rate generator to 1MHz.
 */
inline void MCP23017_I2C_Open() {
	I2C1BRG = I2C_BRG_1MHZ;
}

/**
 * Any post-message stuff relating to the I2C module goes here.
 * Currently, it does nothing.
 */
inline void MCP23017_I2C_Close() {

}

/**
 * Puts the 7-bit device address plus R/W bit on the I2C bus. This function blocks until the transmission completes.
 * @param[in] addr 3-bit MCP23017 address set by A2, A1, A0 pins in the lowest 3 bits.
 * @param[in] rw Read or /Write (1 for read, 0 for write).
 * @return The ACK bit from the device.
 * @retval 0 Device has sent an acknowledge.
 * @retval 1 Device has not sent an acknowledge.
 */
inline uint8_t MCP23017_SendControlByte(uint8_t addr, uint8_t rw) {
	return I2C_Send7BitAddress(MCP23017_I2C_ADDR | addr, rw);
}

/**
 * Writes a single register on the MCP23017.  This function blocks until the transmission completes.
 * @param[in] addr 3-bit MCP23017 address set by A0, A1, A2 pins.
 * @param[in] reg Register address on the MCP23017 to write.
 * @param[in] data Data to put in the register.
 * @return Success or failure
 * @retval 1 Success.
 * @retval 0 Failure.
 */
uint8_t MCP23017_SingleRegisterWrite(uint8_t addr, uint8_t reg, uint8_t data) {
	MCP23017_I2C_Open();

	if (!I2C_SendStart()) {
		MCP23017_I2C_Close();
		return 0;
	}

	if (MCP23017_SendControlByte(addr, I2C_RW_WRITE)) {
		I2C_SendStop();
		MCP23017_I2C_Close();
		return 0;
	}

	if (I2C_SendByte(reg)) {
		I2C_SendStop();
		MCP23017_I2C_Close();
		return 0;
	}

	if (I2C_SendByte(data)) {
		I2C_SendStop();
		MCP23017_I2C_Close();
		return 0;
	}

	I2C_SendStop();
	MCP23017_I2C_Close();
	
	return 1;
}

/**
 * Reads a single register from the MCP23017.  This function blocks until the transmission completes.
 * @bug Currently, it is not possible to return an error condition
 * @param[in] addr 3-bit MCP23017 address set by A0, A1, A2 pins.
 * @param[in] reg Register address on the MCP23017 to write.
 * @param[out] data Data byte read from the device.
 * @return Success or failure.
 * @retval 0 Failure - data read timed out, data byte is not valid.
 * @retval 1 Success - data byte is valid.
 */
uint8_t MCP23017_SingleRegisterRead(uint8_t addr, uint8_t reg, uint8_t *data) {
	MCP23017_I2C_Open();

	if (!I2C_SendStart()) {
		MCP23017_I2C_Close();
		return 0;
	}

	if (MCP23017_SendControlByte(addr, I2C_RW_WRITE)) {
		I2C_SendStop();
		MCP23017_I2C_Close();
		return 0;
	}

	if (I2C_SendByte(reg)) {
		I2C_SendStop();
		MCP23017_I2C_Close();
		return 0;
	}

	I2C_SendRepeatedStart();

	if (MCP23017_SendControlByte(addr, I2C_RW_READ)) {
		I2C_SendStop();
		MCP23017_I2C_Close();
		return 0;
	}

	if (I2C_ReadByte(I2C_SEND_NACK, data)) {
		I2C_SendStop();
		MCP23017_I2C_Close();

		return 1;
	} else {
		I2C1CONbits.I2CEN = 0;

		return 0;
	}
}

