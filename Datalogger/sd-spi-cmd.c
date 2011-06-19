/*
 * File:   sd-spi-cmd.c
 * Author: Ducky
 *
 * Created on January 16, 2011, 1:29 PM
 *
 * Protocol layer of the SD Card SPI implementation
 */

#include "sd-spi-phy.h"
#include "sd-spi-cmd.h"

#include "hardware.h"
#include "uart.h"

#define SD_SPI_DEBUG_UART

/**
 * Sends a command to the SD Card. This function blocks until the transmission is complete.
 * The R1 Response byte is returned. The calling function should check to make sure it is valid.
 * The calling function can continue requesting bytes from the SD card for some operations.
 *
 * @bug There is currently no timeout, so this function might enter an infinite loop.
 *
 * @param command Command to send, bits [45:40].
 * @param arg1 First byte of the arguments, bits [39:32].
 * @param arg2 Second byte of the arguments, bits [31:24].
 * @param arg3 Third byte of the arguments, bits [16:23].
 * @param arg4 Fourth byte of the arguments, bits [8:15].
 * @param crc The 7-bit CRC to be transmitted, shifted one bit to the left, bits [7:1].
 *
 * @return The first byte of the response, which should be the R1 response
 */
inline uint8_t SD_SPI_SendCommand(uint8_t command,
		uint8_t arg1, uint8_t arg2, uint8_t arg3, uint8_t arg4, uint8_t crc) {
	uint8_t response = 0xFF;
	uint16_t i = 0;

	SD_SPI_Transfer(0b01000000 | command);
	SD_SPI_Transfer(arg1);
	SD_SPI_Transfer(arg2);
	SD_SPI_Transfer(arg3);
	SD_SPI_Transfer(arg4);
	SD_SPI_Transfer(crc | 0b00000001);

	// NON-STANDARD: Empirically determined SanDisk SD Cards output 0b10111111 before command response for some reason
	while (response & 0x80 && i < SD_SPI_MAX_CMD_WAIT) {
		response = SD_SPI_Transfer(SD_SPI_DUMMY_BYTE);
		i++;
	}
	return response;
}

/**
 * Sends the required blocks before terminating a command
 */
inline void SD_SPI_Terminate() {
	SD_SPI_Transfer(SD_SPI_DUMMY_BYTE);
	SD_SPI_Transfer(SD_SPI_DUMMY_BYTE);
}
