#include "types.h"

/*
 * SD SPI Constants
 */

#define SD_SPI_DUMMY_BYTE				0xFF	//!< Dummy byte for a SPI read operation
#define SD_SPI_IDLE_RESPONSE			0xFF	//!< Response from the card when the card is not yet sending data
#define SD_SPI_FILL_DATA				0x00	//!< Data to fill a partial block

#define SD_SPI_MAX_CMD_WAIT				1000	//!< Maximum number of SPI bytes to wait for the SD card to respond

/**
 * Standard SPI commands (Simplified Physical Layer Spec 7.3.1.3).
 */
#define SD_SPI_CMD_GO_IDLE_STATE		0	//!< R1, resets card
#define SD_SPI_CMD_SEND_OP_COND			1	//!< R1, sends host capacity support information and activates card initialization process
// CMD5 reserved for SDIO mode
#define SD_SPI_CMD_SWITCH_FUNC			6	//!< R1, checks switchable function and switches card function
#define SD_SPI_CMD_SEND_IF_COND			8	//!< R7, sends interface condition including supply voltage, asks if card can operate
#define SD_SPI_CMD_SEND_CSD				9	//!< R1, asks card to send Card-Specific Data
#define SD_SPI_CMD_SEND_CID				10	//!< R1, asks card to send Card Indentification
#define SD_SPI_CMD_STOP_TRANSMISSION	12	//!< R1b, forces card to stop transmission in Multiple Block Read Operation
#define SD_SPI_CMD_SEND_STATUS			13	//!< R2, asks card to send status register
#define SD_SPI_CMD_SET_BLOCKLEN			16	//!< R1, sets block length (bytes) for block commands for a Standard Capacity Card
#define SD_SPI_CMD_READ_SINGLE_BLOCK	17	//!< R1, reads a block of size selected by SET_BLOCKLEN
#define SD_SPI_CMD_READ_MULTIPLE_BLOCK	18	//!< R1, reads blocks until interrupted by STOP_TRANSMISSION command
#define SD_SPI_CMD_WRITE_BLOCK			24	//!< R1, writes a block of size selected by SET_BLOCKLEN
#define SD_SPI_CMD_WRITE_MULTIPLE_BLOCK	25	//!< R1, writes blocks until interrupted by Stop Tran token
#define SD_SPI_CMD_PROGRAM_CSD			27	//!< R1, programs the programmable bits of the CSD
#define SD_SPI_CMD_SET_WRITE_PROT		28	//!< R1b, sets write protection bit of addressed group (if supported)
#define SD_SPI_CMD_CLR_WRITE_PROT		29	//!< R1b, clears write protection bit of addressed group (if supported)
#define SD_SPI_CMD_SEND_WRITE_PROT		30	//!< R1, asks card to send status of write protection bits (if supported)
#define SD_SPI_CMD_ERASE_WR_BLK_START_ADDR	32	//!< R1, sets address of first write block to be erased
#define SD_SPI_CMD_ERASE_WR_BLK_END_ADDR	33	//!< R1, sets address of last write block to be erased
#define SD_SPI_CMD_ERASE				38	//!< R1b, erases the selected write blocks
#define SD_SPI_CMD_LOCK_UNLOCK			42	//!< R1, set/reset the password or lock/unlock the card
#define SD_SPI_CMD_APP_CMD				55	//!< R1, defines that next command is an application-specific command
#define SD_SPI_CMD_GEN_CMD				56	//!< R1, ???
#define SD_SPI_CMD_READ_OCR				58	//!< R3, reads OCR register
#define SD_SPI_CMD_CRC_ON_OFF			59	//!< R1, turns CRC option on/off

/**
 * Application-specific Commands (Simplified Physical Layer Spec 7.3.1.3).
 */
#define SD_SPI_ACMD_SD_STATUS			13	//!< R2, sends SD status
#define SD_SPI_ACMD_SEND_NUM_WR_BLOCKS	22	//!< R1, sends number of well-written blocks
#define SD_SPI_ACMD_SET_WR_BLK_ERASE_COUNT	23	//!< R1, sets number of write blocks to be pre-erased before writing
// ACMD25 - ACMD26 reserved for SD security applications
#define SD_SPI_ACMD_SD_SEND_OP_COND		41	//!< R1, sends host capacity support information and activates card initialization process
#define SD_SPI_ACMD_SET_CLR_CARD_DETECT	42	//!< R1, connect/disconnect 50KOhm pull-up resistor on CS (may be used for card detection)
// ACMD43 - ACMD49 reserved for SD security applications
#define SD_SPI_ACMD_SEND_SCR			51	//!< R1, reads the SD Configuration Register

/**
 * Response-specific definitions.
 */
// Response R1
#define SD_SPI_R1_IDLE_STATE			0b00000001	//!< In Idle State bit, card is in idle state and running initialization
#define SD_SPI_R1_ERASE_RESET			0b00000010	//!< Erase Reset bit, erase sequence was cleared before executing because out of erase sequence command was receieved
#define SD_SPI_R1_ILLEGAL_COMMAND		0b00000100	//!< Illegal Command bit, illegal command code was detected
#define SD_SPI_R1_COM_CRC_ERROR			0b00001000	//!< Communication CRC Error bit, CRC check of last command failed
#define SD_SPI_R1_ERASE_SEQUENCE_ERROR	0b00010000	//!< Erase Sequence Error bit, error in the sequence of erase commands occurred
#define SD_SPI_R1_ADDRESS_ERROR			0b00100000	//!< Address Error bit, misaligned address that did not match the block length was used in the command
#define SD_SPI_R1_PARAMETER_ERROR		0b01000000	//!< Parameter Error bit, command argument was outside allowed range for this card

// Response R2 - first byte is identical to R1, second byte as defined below
#define SD_SPI_R2_CARD_LOCKED			0b00000001	//!< Card is Locked bit, set when card is locked by user, reset when it is unlocked
#define SD_SPI_R2_WP_ERASE_SKIP			0b00000010	//!< Write Protect Erase Skip bit, when host attempts to erase a write-protected sector
#define SD_SPI_R2_LOCK_FAILED			0b00000010	//!< Lock/unlock Command Failed bit, password errors during card lock/unlock operation
#define SD_SPI_R2_ERROR					0b00000100	//!< Error bit, a general / unknown error occurred during operation
#define SD_SPI_R2_CC_ERROR				0b00001000	//!< CC Error bit, internal card controller error
#define SD_SPI_R2_CARD_ECC_FAILED		0b00010000	//!< Card ECC Failed bit, card internal ECC applied but failed to correct the data
#define SD_SPI_R2_WP_VIOLATION			0b00100000	//!< Write Protect Violation bit, tried to write a write-protected block
#define SD_SPI_R2_ERASE_PARAM			0b01000000	//!< Erase Param bit, invalud selection for erase
#define SD_SPI_R2_OUT_OF_RANGE			0b10000000	//!< Out of Range bit
#define SD_SPI_R2_CSD_OVERWRITE			0b10000000	//!< CSD Overwrite bit

// Response R3 - first byte is identical to R1, next 4 bytes contain the OCR
// Responses R4, R5 reserved for IO mode

// Response R7 - first byte is identical to R1
#define SD_SPI_R7_B2_COMMAND_VERSION	0b11110000	//!< Command Version bits, in second byte
#define SD_SPI_R7_B4_VOLTAGE_ACCEPTED	0b00001111	//!< Voltage Accepted bits, in fourth byte
													//!< Last byte consists of check pattern

/**
 * Control Tokens (Simplified Physical Layer Spec 7.3.3).
 * Data Response Token:		x x x 0 (3 status bits) 1
 * Staus bits are:					010		Data accepted
 * 									101		Data rejected due to CRC error
 * 									110		Data rejected due to write error
 *  Data Error Token:		0 0 0 0 (out of range) (Card ECC failed) (CC error) (Error)
 *
 */
#define SD_SPI_TOKEN_START_BLOCK		0b11111110	//!< Start Block token for Single Block Read, Single Block Write, Multiple Block Read
#define SD_SPI_TOKEN_MBW_START_BLOCK	0b11111100	//!< Start Block token for Multiple Block Write
#define SD_SPI_TOKEN_MBW_STOP_TRAN		0b11111101	//!< Stop Tran token for Multiple Block Write

/*
 * Function Prototypes.
 */
inline uint8_t SD_SPI_SendCommand(uint8_t command,
		uint8_t arg1, uint8_t arg2, uint8_t arg3, uint8_t arg4, uint8_t crc);
inline void SD_SPI_Terminate();
