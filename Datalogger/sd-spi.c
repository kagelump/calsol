/*
 * File:   sd-spi.c
 * Author: Ducky
 *
 * Created on January 16, 2011, 1:29 PM
 *
 * Higher-level protocol layer of the SD Card SPI implementation
 */
#include "sd-spi-phy.h"
#include "sd-spi-cmd.h"
#include "sd-spi.h"

#include "sd-spi-dma.h"

#include "uart.h"

#define SD_SPI_DEBUG_UART

/**
 * Initializes the SD Card, implemented according to Physical Layer Spec 2.00, Section 7.2.1.
 * This also fills the card struct with card version (1.xx or 2.0+) and SDHC.
 * Further initialization of the card (like size, etc) is done later.
 *
 * @param[out] card Pointer to card data structure to fill.
 * @return Success or failure
 * @retval -1 Failure: Bad card pointer.
 * @retval -2 Failure: Bad response from card.
 * @retval -3 Failure: Invalid operating voltage.
 * @retval 1 Success.
 */
int8_t SD_SPI_Card_Init(SDCard *card) {
	uint8_t result[5];
	uint16_t i;

#ifdef SD_SPI_DEBUG_UART
		putlineUART("Initialize SD Card");
#endif

	if (card == 0) {
		return -1;	// bad card pointer
	}

	SD_SPI_Slow_Init();

	// Supply at least 74 clock cycles for power-on
	for (i=0; i<10; i++) {
		SD_SPI_Transfer(SD_SPI_DUMMY_BYTE);
	}

	// Try CMD0 (GO_IDLE_STATE)
	SD_SPI_Open();
	result[0] = SD_SPI_SendCommand(SD_SPI_CMD_GO_IDLE_STATE, 0x00, 0x00, 0x00, 0x00, 0x95);
	SD_SPI_Terminate();
	SD_SPI_Close();
#ifdef SD_SPI_DEBUG_UART
		putsUART("* Send GO_IDLE_STATE: ");
		putcolbUART(result[0], 8);
		newlineUART();
#endif
	if (result[0] != SD_SPI_R1_IDLE_STATE) {
#ifdef SD_SPI_DEBUG_UART
		putlineUART("Failure: Bad response to GO_IDLE_STATE");
#endif
		return -2;
	}

	// Try CMD8 (SEND_IF_COND) to see if it is a Ver2.00 or later SD Card
	SD_SPI_Open();
	result[0] = SD_SPI_SendCommand(SD_SPI_CMD_SEND_IF_COND, 0x00, 0x00, 0x01, 0b10101010, 0x87);
	if (result[0] == (SD_SPI_R1_ILLEGAL_COMMAND | SD_SPI_R1_IDLE_STATE)) {	// Ver 1.x SD Card
		SD_SPI_Terminate();
		SD_SPI_Close();

		card->Ver2SDCard = 0;

#ifdef SD_SPI_DEBUG_UART
		putsUART("* Send SEND_IF_COND: ");
		putcolbUART(result[0], 8);
		putlineUART(" (Ver 1.x SD Card)");
#endif
	} else if (result[0] == SD_SPI_R1_IDLE_STATE) {							// Ver 2.00 or later SD Card
		result[1] = SD_SPI_Transfer(SD_SPI_DUMMY_BYTE);
		result[2] = SD_SPI_Transfer(SD_SPI_DUMMY_BYTE);
		result[3] = SD_SPI_Transfer(SD_SPI_DUMMY_BYTE);
		result[4] = SD_SPI_Transfer(SD_SPI_DUMMY_BYTE);
		SD_SPI_Terminate();
		SD_SPI_Close();

#ifdef SD_SPI_DEBUG_UART
		putsUART("* Send SEND_IF_COND: ");
		putcolbUART(result[0], 8);	putcUART(' ');	putcolbUART(result[1], 8);	putcUART(' ');
		putcolbUART(result[2], 8);	putcUART(' ');	putcolbUART(result[3], 8);	putcUART(' ');
		putcolbUART(result[4], 8);
		putlineUART(" (Ver 2.0+ SD Card)");
#endif

		if (result[4] != 0b10101010) {	// Check pattern
#ifdef SD_SPI_DEBUG_UART
			putlineUART("Failure: Bad check pattern in SEND_IF_COND");
#endif
			return -2;	// bad check pattern
		}
		if ((result[3] & SD_SPI_R7_B4_VOLTAGE_ACCEPTED) != 0x01) {	// Check voltage range
#ifdef SD_SPI_DEBUG_UART
			putlineUART("Failure: Incompatible voltage range (from SEND_IF_COND)");
#endif
			return -3;	// voltage not supported
		}

		card->CmdVer = result[1] & SD_SPI_R7_B2_COMMAND_VERSION;
		card->Ver2SDCard = 1;
	} else {	// bad response - initialization failed
		SD_SPI_Terminate();
		SD_SPI_Close();
#ifdef SD_SPI_DEBUG_UART
		putsUART("* Send SEND_IF_COND: ");
		putcolbUART(result[0], 8);
		newlineUART();
		putlineUART("Failure: Bad response to SEND_IF_COND");
#endif
		return -2;
	}

	// Send CMD58 (READ_OCR)
	SD_SPI_Open();
	result[0] = SD_SPI_SendCommand(SD_SPI_CMD_READ_OCR, 0x00, 0x00, 0x00, 0x00, 0x00);
	if (result[0] != SD_SPI_R1_IDLE_STATE) {
		SD_SPI_Terminate();
		SD_SPI_Close();
#ifdef SD_SPI_DEBUG_UART
		putlineUART("Failure: Bad response to READ_OCR");
#endif
		return -2;
	}
	result[1] = SD_SPI_Transfer(SD_SPI_DUMMY_BYTE);
	result[2] = SD_SPI_Transfer(SD_SPI_DUMMY_BYTE);
	result[3] = SD_SPI_Transfer(SD_SPI_DUMMY_BYTE);
	result[4] = SD_SPI_Transfer(SD_SPI_DUMMY_BYTE);
	SD_SPI_Terminate();
	SD_SPI_Close();
#ifdef SD_SPI_DEBUG_UART
	putsUART("* Send READ_OCR: ");
	putcolbUART(result[0], 8);	putcUART(' ');	putcolbUART(result[1], 8);	putcUART(' ');
	putcolbUART(result[2], 8);	putcUART(' ');	putcolbUART(result[3], 8);	putcUART(' ');
	putcolbUART(result[4], 8);
	newlineUART();
#endif
	if ( (result[2] & 01111000) != 0 ) {
#ifdef SD_SPI_DEBUG_UART
		putlineUART("Failure: Incompatible voltage range (from READ_OCR)");
#endif
		return -3;	// voltage not supported
	}

#ifdef SD_SPI_DEBUG_UART
	putsUART("* Awaiting initialization ");
#endif
	for (i=0; i<SD_INIT_MAX_TRIES; i++) {
		SD_SPI_Open();
		SD_SPI_SendCommand(SD_SPI_CMD_APP_CMD, 0x00, 0x00, 0x00, 0x00, 0x00);
		SD_SPI_Terminate();
		result[0] = SD_SPI_SendCommand(SD_SPI_ACMD_SD_SEND_OP_COND, 0x00, 0x00, 0x00, 0x00, 0x00);
		SD_SPI_Terminate();
		SD_SPI_Close();

		if (result[0] == 0x00) {
#ifdef SD_SPI_DEBUG_UART
			putcUART(' ');
			putcolbUART(result[0], 8);
			newlineUART();
			putlineUART("Initialization complete");
#endif
			break;
		} else if (result[0] == SD_SPI_R1_IDLE_STATE) {
#ifdef SD_SPI_DEBUG_UART
			putcUART('.');
#endif
		} else {
#ifdef SD_SPI_DEBUG_UART
			putcUART(' ');
			putcolbUART(result[0], 8);
			newlineUART();
			putlineUART("Failure: Bad response to ACMD41");
#endif
			return -2;
		}
		// TODO Fix timeout - currently timeout returns a 1
		// TODO Add SDHC support - set HCS and issue CMD58 to detect SDHC
	}
	return 1;
}

/**
 * Reads the CID data of the SD card and stores it into @a card.
 * 
 * @pre The SD Card @a card must be successfully initialized (call to @c SD_SPI_Card_Init returned 1).
 *
 * @param[in,out] card SDCard struct to store data into
 * @return Success or failure
 * @retval -1 Failure: Bad card pointer.
 * @retval -2 Failure: Bad response from card.
 * @retval 1 Success.
 */
int8_t SD_SPI_ReadCID(SDCard *card) {
	uint8_t result[17];
	uint16_t i;
#ifdef SD_SPI_DEBUG_UART
		putlineUART("Read SD Card CID");
#endif

	if (card == 0) {
		return -1;	// bad card pointer
	}

	SD_SPI_Open();
	result[0] = SD_SPI_SendCommand(SD_SPI_CMD_SEND_CID, 0x00, 0x00, 0x00, 0x00, 0x00);
	if (result[0] != 0x00) {
		SD_SPI_Terminate();
		SD_SPI_Close();
#ifdef SD_SPI_DEBUG_UART
		putcolbUART(result[0], 8);
		newlineUART();
		putlineUART("Failure: Bad response");
#endif
		return -2;
	}

	// NONSTANDARD - EMPRICIALLY DETERMINED
	// Wait for inter-block delay (if such a thing actually exists)
	result[1] = 0xFF;
	while (result[1] == 0xFF) {
		result[1] = SD_SPI_Transfer(SD_SPI_DUMMY_BYTE);
	}
	while (result[1] == 0xFE) {
		result[1] = SD_SPI_Transfer(SD_SPI_DUMMY_BYTE);
	}

	// Read data
	for (i=2; i<17; i++) {
		result[i] = SD_SPI_Transfer(SD_SPI_DUMMY_BYTE);
	}

	// Fetch the rest of the (non-data carrying) block
	for (i=0; i<16*3; i++) {
		SD_SPI_Transfer(SD_SPI_DUMMY_BYTE);
	}

	SD_SPI_Terminate();
	SD_SPI_Close();

#ifdef SD_SPI_DEBUG_UART
	putcolbUART(result[0], 8);	newlineUART();
	for (i=0; i<16; i++) {
		putcolbUART(result[i+1], 8);
		putcUART(' ');
		if ((i % 8) == 7) {
			newlineUART();
		}
	}
#endif

	card->CID.MID = result[1];
	card->CID.OID[0] = result[2];
	card->CID.OID[1] = result[3];
	card->CID.PNM[0] = result[4];
	card->CID.PNM[1] = result[5];
	card->CID.PNM[2] = result[6];
	card->CID.PNM[3] = result[7];
	card->CID.PNM[4] = result[8];
	card->CID.PRV = result[9];
	card->CID.PSN = result[10];		card->CID.PSN = card->CID.PSN << 8;
	card->CID.PSN |= result[11];	card->CID.PSN = card->CID.PSN << 8;
	card->CID.PSN |= result[12];	card->CID.PSN = card->CID.PSN << 8;
	card->CID.PSN |= result[13];
	card->CID.MDT = result[14];		card->CID.MDT = card->CID.MDT << 8;
	card->CID.MDT |= result[15];

	return 1;
}

/**
 * Reads the CSD data of the SD card and stores it into @a card
 * 
 * @pre The SD Card @a card must be successfully initialized (call to @c SD_SPI_Card_Init returned 1).
 *
 * @param[in,out] card SDCard struct to store data into
 * @return Success or failure
 * @retval -1 Failure: Bad card pointer.
 * @retval -2 Failure: Bad response from card.
 * @retval -3 Failure: Parsing error (invalid data).
 * @retval -128 Failure: Not yet implemented functionality.
 * @retval 1 Success.
 */
int8_t SD_SPI_ReadCSD(SDCard *card) {
	uint8_t result[17];
	uint16_t i;
#ifdef SD_SPI_DEBUG_UART
		putlineUART("Read SD Card CSD");
#endif

	if (card == 0) {
		return -1;	// bad card pointer
	}

	SD_SPI_Open();
	result[0] = SD_SPI_SendCommand(SD_SPI_CMD_SEND_CSD, 0x00, 0x00, 0x00, 0x00, 0x00);
	if (result[0] != 0x00) {
		SD_SPI_Terminate();
		SD_SPI_Close();
#ifdef SD_SPI_DEBUG_UART
		putcolbUART(result[0], 8);
		newlineUART();
		putlineUART("Failure: Bad response");
#endif
		return -2;
	}

	// NONSTANDARD - EMPRICIALLY DETERMINED
	// Wait for inter-block delay (if such a thing actually exists)
	result[1] = 0xFF;
	while (result[1] == 0xFF) {
		result[1] = SD_SPI_Transfer(SD_SPI_DUMMY_BYTE);
	}
	while (result[1] == 0xFE) {
		result[1] = SD_SPI_Transfer(SD_SPI_DUMMY_BYTE);
	}

	// Read data
	for (i=2; i<17; i++) {
		result[i] = SD_SPI_Transfer(SD_SPI_DUMMY_BYTE);
	}
	
	// Fetch the rest of the (non-data carrying) block
	for (i=0; i<16*3; i++) {
		SD_SPI_Transfer(SD_SPI_DUMMY_BYTE);
	}
	SD_SPI_Terminate();
	SD_SPI_Close();

#ifdef SD_SPI_DEBUG_UART
	putcolbUART(result[0], 8);	newlineUART();
	for (i=0; i<16; i++) {
		putcolbUART(result[i+1], 8);
		putcUART(' ');
		if ((i % 8) == 7) {
			newlineUART();
		}
	}
#endif

	if (result[1] == 0x00) {
		card->ReadBlockMisalign = (result[7] >> 5) & 0b1;
		card->ReadBlockPartial = (result[7] >> 7) & 0b1;
		card->ReadBlockBits = (result[6] >> 0) & 0b1111;
		if (card->ReadBlockBits >= 9 && card->ReadBlockBits <= 11) {
			card->ReadBlockLength = (uint16_t)0b1 << card->ReadBlockBits;
			if (card->ReadBlockLength == 1024) {
				card->ReadBlockLength = 512;
				card->ReadBlockBits = 9;
			}
			card->ReadBlockMask = card->ReadBlockLength - 1;
		} else {
			return -3;
		}

		card->WriteBlockMisalign = (result[7] >> 6) & 0b1;
		card->WriteBlockPartial = (result[14] >> 5) & 0b1;
		card->WriteBlockBits = (result[13] >> 0) & 0b11;
		card->WriteBlockBits = card->WriteBlockBits << 2;
		card->WriteBlockBits |= (result[14] >> 6) & 0b11;
		if (card->WriteBlockBits >= 9 && card->WriteBlockBits <= 11) {
			card->WriteBlockLength = (uint16_t)0b1 << card->WriteBlockBits;
			if (card->WriteBlockLength == 1024) {
				card->WriteBlockLength = 512;
				card->WriteBlockBits = 9;
			}
			card->WriteBlockMask = card->WriteBlockLength - 1;
		} else {
			return -3;
		}

		card->SectorSize = (result[11] >> 0) & 0b111111;
		card->SectorSize = card->SectorSize << 1;
		card->SectorSize |= (result[12] >> 7) & 0b1;
		card->SectorSize++;
		card->SectorSize = card->SectorSize * card->WriteBlockLength;

		card->CSD.CSDVer1.CSD_STRUCTURE = (result[1] >> 6) & 0b11;
		card->CSD.CSDVer1.TAAC = result[2];
		card->CSD.CSDVer1.NSAC = result[3];
		card->CSD.CSDVer1.TRAN_SPEED = result[4];

		card->CSD.CSDVer1.CCC = result[5];
		card->CSD.CSDVer1.CCC = card->CSD.CSDVer1.CCC << 4;
		card->CSD.CSDVer1.CCC |= result[6] >> 4;

		card->CSD.CSDVer1.READ_BL_LEN = (result[6] >> 0) & 0b1111;
		card->CSD.CSDVer1.READ_BL_PARTIAL = (result[7] >> 7) & 0b1;
		card->CSD.CSDVer1.WRITE_BLK_MISALIGN = (result[7] >> 6) & 0b1;
		card->CSD.CSDVer1.READ_BLK_MISALIGN = (result[7] >> 5) & 0b1;
		card->CSD.CSDVer1.DSR_IMP = (result[7] >> 4) & 0b1;
		
		card->CSD.CSDVer1.C_SIZE = (result[7] >> 0) & 0b11;
		card->CSD.CSDVer1.C_SIZE = card->CSD.CSDVer1.C_SIZE << 8;
		card->CSD.CSDVer1.C_SIZE |= result[8];
		card->CSD.CSDVer1.C_SIZE = card->CSD.CSDVer1.C_SIZE << 2;
		card->CSD.CSDVer1.C_SIZE |= (result[9] >> 6) & 0b11;

		card->CSD.CSDVer1.VDD_R_CURR_MIN = (result[9] >> 3) & 0b111;
		card->CSD.CSDVer1.VDD_R_CURR_MAX = (result[9] >> 0) & 0b111;

		card->CSD.CSDVer1.VDD_W_CURR_MIN = (result[10] >> 5) & 0b111;
		card->CSD.CSDVer1.VDD_W_CURR_MAX = (result[10] >> 2) & 0b111;

		card->CSD.CSDVer1.C_SIZE_MULT = (result[10] >> 0) & 0b11;
		card->CSD.CSDVer1.C_SIZE_MULT = card->CSD.CSDVer1.C_SIZE_MULT << 1;
		card->CSD.CSDVer1.C_SIZE_MULT |= (result[11] >> 7) & 0b1;

		card->CSD.CSDVer1.ERASE_BLK_EN = (result[11] >> 6) & 0b1;

		card->CSD.CSDVer1.SECTOR_SIZE = (result[11] >> 0) & 0b111111;
		card->CSD.CSDVer1.SECTOR_SIZE = card->CSD.CSDVer1.SECTOR_SIZE << 1;
		card->CSD.CSDVer1.SECTOR_SIZE |= (result[12] >> 7) & 0b1;

		card->CSD.CSDVer1.WP_GRP_SIZE = (result[12] >> 0) & 0b1111111;
		card->CSD.CSDVer1.WP_GRP_ENABLE = (result[13] >> 7) & 0b1;

		card->CSD.CSDVer1.R2W_FACTOR = (result[13] >> 2) & 0b111;

		card->CSD.CSDVer1.WRITE_BL_LEN = (result[13] >> 0) & 0b11;
		card->CSD.CSDVer1.WRITE_BL_LEN = card->CSD.CSDVer1.WRITE_BL_LEN << 2;
		card->CSD.CSDVer1.WRITE_BL_LEN |= (result[14] >> 6) & 0b11;
		
		card->CSD.CSDVer1.WRITE_BL_PARTIAL = (result[14] >> 5) & 0b1;

		card->CSD.CSDVer1.FILE_FORMAT_GRP = (result[15] >> 7) & 0b1;
		card->CSD.CSDVer1.COPY = (result[15] >> 6) & 0b1;
		card->CSD.CSDVer1.PERM_WRITE_PROTECT = (result[15] >> 5) & 0b1;
		card->CSD.CSDVer1.TMP_WRITE_PROTECT = (result[15] >> 4) & 0b1;
		card->CSD.CSDVer1.FILE_FORMAT = (result[15] >> 2) & 0b11;
	} else if (result[1] == 0x40) {
		return -128;
	}
	
	return 1;
}

/**
 * Reads a single block of data from the SD Card.
 *
 * @pre The SD Card @a card must be successfully initialized (call to @c SD_SPI_Card_Init returned 1).
 * @pre The SD Card @a must have had the CSD successfully read (call to @c SD_SPI_ReadCSD returned 1).
 * @param[in] card SDCard struct.
 * @param[in] begin Block number to begin on. A block is defined to be 512 bytes, regardless of what the SD Card reports.
 * @param[out] buffer Buffer to write the data too.
 *
 * @bug This does not handle data error tokens yet.
 *
 * @return Number of data bytes read.
 * If this number does not equal a block size, then an error occurred and data in
 * the buffer should be regarded as invalid.
 */
fs_length_t SD_SPI_ReadSingleBlock(SDCard *card, fs_addr_t begin, uint8_t* buffer) {
	SD_DMA_SBR_Start(card, begin, 2);
	while (!SD_DMA_GetIdle());

	uint8_t* dmaBuf = SD_DMA_GetBuffer(2);
	uint16_t i = 0;
	for (i=0;i<512;i++) {
		buffer[i] = dmaBuf[i];
	}

	return 512;
}

/**
 * Writes data to the SD Card using the single block write command.
 *
 * @pre The SD Card @a card must be successfully initialized (call to @c SD_SPI_Card_Init returned 1).
 * @pre The SD Card @a must have had the CSD successfully read (call to @c SD_SPI_ReadCSD returned 1).
 * @param[in] card SDCard struct.
 * @param[in] begin Byte address to begin on. This must be block aligned.
 * @param[in] size Size, in bytes, of the data to write. This must be equal to the block size.
 * @param[out] buffer Buffer to containing the data to be written.
 * @return Number of data bytes written.
 */
fs_length_t SD_SPI_WriteSingleBlock(SDCard *card, fs_addr_t begin, uint8_t* buffer) {
	uint8_t* dmaBuf = SD_DMA_GetBuffer(2);
	uint16_t i = 0;
	for (i=0;i<512;i++) {
		dmaBuf[i] = buffer[i];
	}

	if (!SD_DMA_MBW_Start(card, begin)) {
		while (1);
	}

	SD_DMA_MBW_SendBlock(2);

	while (SD_DMA_MBW_GetBlockStatus() == 0x00);

	SD_DMA_MBW_End();

	while (SD_DMA_MBW_GetBlockStatus() == 0x00);

	return 512;
}
