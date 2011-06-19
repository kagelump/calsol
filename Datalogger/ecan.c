/*
 * File:   ecan.c
 * Author: Ducky
 *
 * Created on January 15, 2011, 6:09 PM
 *
 * This file contains functions for working with the on-board ECAN module
 */

#ifdef __PIC24F__
	#include <p24Fxxxx.h>
#elif defined __PIC24H__
	#include <p24Hxxxx.h>
#endif

#include "ecan.h"
#include "hardware.h"

#include "uart.h"
#include "uartstring.h"
/*
 * Variables
 */

uint16_t ECANMsgBuf[ECAN_NUM_BUFFERS][ECAN_BUFFER_WORDS] __attribute__((space(dma), aligned(ECAN_ALIGN)));

/**
 * Initializes ECAN.
 * Next step is to configure it.
 */
void ECAN_Init() {
	uint8_t i, j;
	// Clear buffers
	for (i=0;i<ECAN_NUM_BUFFERS;i++) {
		for (j=0;j<ECAN_BUFFER_WORDS;j++) {
			ECANMsgBuf[i][j] = 0;
		}
	}
}

/**
 * Configures the ECAN module.
 * Next step is to have it enter a mode.
 * (Implemented according to AN1249)
 *
 * Afterwards, the user application should:
 * - Setup filters & masks
 * - Put the ECAN module into the operating mode
 * - Setup TX/RX buffers
 */
void ECAN_Config() {
	// Step 1: Request configuration mode
	C1CTRL1bits.WIN = 0;
	ECAN_SetMode(ECAN_MODE_CONFIG);

	// Step 2: Setup block and bit timing
	C1CFG1bits.BRP = ECAN_BRP;
	C1CFG1bits.SJW = ECAN_SJW - 1;
	C1CFG2bits.SEG1PH = ECAN_PHSEG1 - 1;
	C1CFG2bits.SEG2PHTS = 1;	// Phase Segment 2 programmable
	C1CFG2bits.SEG2PH = ECAN_PHSEG2 - 1;
	C1CFG2bits.PRSEG = ECAN_PRSEG - 1;
	C1CFG2bits.SAM = 0x01;		// Bus sampled 3 times

	// Step 3: Assign buffers
	C1FCTRLbits.DMABS = ECAN_DMABS;
}

/**
 * Requests a mode change in the ECAN module.
 * This function blocks until the mode change is complete.
 *
 * @param[in] mode Target mode
 */
void ECAN_SetMode(eECANMode mode) {
	C1CTRL1bits.REQOP = mode;
	while (C1CTRL1bits.OPMODE != mode);
}

/**
 * Sets a ECAN filter
 *
 * @param[in] filNum Filter number to set. (0-15)
 * @param[in] sidFilter SID filter bits.
 * @param[in] maskNum Mask number to use. (0-2)
 * @param[in] bufNum Buffer number to store filter hit CAN frames into,
 *		or use ECAN_FILTER_FIFO (15) to store into RX FIFO buffer.
 */
int8_t ECAN_SetStandardFilter(uint8_t filNum, uint16_t sidFilter, uint8_t maskNum, uint8_t bufNum) {
	volatile unsigned int *filter = &C1RXF0SID + filNum*2;
	unsigned int temp;

	// Sanity checks
	if (filNum > 15) {
		return -1;
	} else if (maskNum > 2) {
		return -2;
	} else if (bufNum > 15) {
		return -3;
	} else if (sidFilter > 0b11111111111) {
		return -4;
	}

	// Window mode
	C1CTRL1bits.WIN = 1;

	// Set SID bits
	*filter = sidFilter << 5;	// also sets EXIDE=0

	// Select mask
	filter = &C1FMSKSEL1 + (filNum / 8);
	maskNum = maskNum << (filNum % 8)*2;
	temp = ~(0b11 << ((filNum % 8)*2));
	*filter = (*filter & temp) | maskNum;

	// Select buffer
	filter = &C1BUFPNT1 + (filNum / 4);
	bufNum = bufNum << ((filNum % 4)*4);
	temp = ~( 0b1111  << ((filNum % 4)*4) );
	*filter = (*filter & temp) | bufNum;

	// enable the filter
	filNum = 1 << filNum;
	C1FEN1 = C1FEN1 | filNum;

	// Disable window mode
	C1CTRL1bits.WIN = 0;

	return 1;
}

/**
 * Sets a ECAN mask.
 *
 * @param[in] maskNum Mask number to set. (0-2)
 * @param[in] sidFilter SID filter bits.
 */
int8_t ECAN_SetStandardMask(uint8_t maskNum,  uint16_t sidFilter) {
	unsigned volatile int *filter = &C1RXM0SID + maskNum*2;

	// Sanity checks
	if (maskNum > 2) {
		return -1;
	} else if (sidFilter > 0b11111111111) {
		return -2;
	}

	// Window mode
	C1CTRL1bits.WIN = 1;

	// Set SID bits
	*filter = sidFilter << 5;	// also sets MIDE=0 (match anything)
	*(filter+1) = 0x00;			// zero out EID bits

	// Disable window mode
	C1CTRL1bits.WIN = 0;

	return 1;
}

/**
 * Disables the specified ECAN filter.
 *
 * @param[in] filNum Filter number to disable. (0-15)
 */
void ECAN_DisableFilter(uint8_t filNum) {
	// Enable window mode
	C1CTRL1bits.WIN = 1;

	filNum = ~(1 << filNum);	// calculate AND mask
	C1FEN1 = C1FEN1 & filNum;

	// Disable window mode
	C1CTRL1bits.WIN = 0;
}

/*
 * DMA Stuff
 */

/**
 * Initializes (and enables) DMA for ECAN.
 */
void ECAN_SetupDMA() {
	/* Initialize the DMA channel 0 for ECAN TX and clear the colission flags */
	DMACS0 = 0;
	/* Set up Channel 0 for peripheral indirect addressing mode normal operation, word operation */
	/* and select TX to peripheral */
	DMA0CON = 0x2020;
	/* Set up the address of the peripheral ECAN1 (C1TXD) */
	DMA0PAD = 0x0442;
	/* Set the data block transfer size of 8 */
	DMA0CNT = 7;
	/* Automatic DMA TX initiation by DMA request */
	DMA0REQ = 0x0046;
	/* DPSRAM atart address offset value */
	DMA0STA = __builtin_dmaoffset(&ECANMsgBuf[0]);
	/* Enable the channel */
	DMA0CONbits.CHEN = 1;
	/* Initialize DMA Channel 1 for ECAN RX and clear the collision flags */
	DMACS0 = 0;
	/* Set up Channel 1 for Peripheral Indirect addressing mode (normal operation, word operation */
	/* and select as RX to peripheral */
	DMA1CON = 0x0020;
	/* Set up the address of the peripheral ECAN1 (C1RXD) */
	DMA1PAD = 0x0440;
	/* Set the data block transfer size of 8 */
	DMA1CNT = 7;
	/* Automatic DMA Rx initiation by DMA request */
	DMA1REQ = 0x0022;
	/* DPSRAM atart address offset value */
	DMA1STA = __builtin_dmaoffset(&ECANMsgBuf[0]);
	/* Enable the channel */
	DMA1CONbits.CHEN = 1;
}

/*
 * ECAN Buffer Read/Write Operations
 */

/**
 * Scans for and returns the number of the next full RX buffer.
 *
 * @returns The number of the next full RX buffer.
 * @retval -1 All buffers are empty.
 */
int8_t ECAN_GetNextRXBuffer() {
	uint8_t i;
	unsigned int temp;

	if (C1RXFUL1 != 0) {
		temp = C1RXFUL1;
		for (i=0;i<16;i++) {
			if ((temp & 1) == 1) {
				return i;
			}
			temp = temp >> 1;
		}
	} else if (C1RXFUL2 != 0) {
		temp = C1RXFUL2;
		for (i=16;i<32;i++) {
			if ((temp & 1) == 1) {
				return i;
			}
			temp = temp >> 1;
		}
	}
	return -1;
}

/**
 * Loads a CAN frame into a buffer for transmission,
 *	and marks that buffer as a transmit buffer.
 *
 * @param[in] buffer Buffer number to load data into.
 * @param[in] sid Standard ID of the CAN frame.
 * @param[in] dlc ("Data Length Code") Length of CAN frame payload.
 * @param[in] data Pointer to data[0].
 *
 * @returns 1 on success, or negative number on error.
 * @retval 1 Success.
 * @retval -1 Failure: Invalid buffer specified.
 * @retval -2 Failure: Invalid SID specified.
 * @retval -3 Failure: Invalid DLC specified.
 * @retval -4 Failure: Non-zero DLC with invalid data pointer.
 */
int8_t ECAN_WriteStandardBuffer(uint8_t buffer,
	uint16_t sid, uint8_t dlc, uint8_t *data) {
	uint8_t i;
	uint16_t *canBuffer = &(ECANMsgBuf[buffer][0]);
	uint8_t *canPayloadBuffer = (uint8_t*)(canBuffer + 3);
	unsigned volatile int *bufferCtrl = &C1TR01CON + (buffer / 2);

	if (buffer >= ECAN_NUM_BUFFERS) {
		return -1;
	} else if (sid > 2047) {
		return -2;
	} else if (dlc > 8) {
		return -3;
	} else if ((dlc != 0) && (data == 0)) {
		return -4;
	}

	// mark as transmit buffer
	if (buffer % 2 == 0) {
		*bufferCtrl = *bufferCtrl | 0b10000000;
	} else {
		*bufferCtrl = *bufferCtrl | 0b1000000000000000;
	}

	// load buffer
	canBuffer[0] = sid << 2;	// also sets SRR=0, IDE=0
	canBuffer[2] = dlc;			// also sets RTR=0, RB1,RB0=0
	// load necessary data
	for (i=0;i<dlc;i++) {
		canPayloadBuffer[i] = data[i];
	}

	return 1;
}

/**
 * Reads a CAN buffer. This automatically clears the 'buffer full' bit.
 *
 * @param[in] buffer Buffer number to read from. (0-31)
 * @param[in] dlc Maximum number of bytes to read from payload.
 *
 * @param[out] sid Pointer to location to store the Standard ID of the CAN frame in the buffer.
 *		Set pointer to 0 to ignore this field.
 * @param[out] eid Pointer to location to store the Extended ID of the CAN frame in the buffer.
 *		Returns -1 if buffer does not contain an extended CAN frame.
 *		Set pointer to 0 to ignore this field.
 * @param[out] data Pointer to location to store payload.
 *		Up to a maximum of @a DLC bytes are stored.
 *
 * @returns Number of bytes read from payload
 */
int8_t ECAN_ReadBuffer(uint8_t buffer, uint16_t *sid, uint32_t *eid,
	uint8_t dlc, uint8_t *data) {
	uint16_t *canBuffer = &(ECANMsgBuf[buffer][0]);
	uint8_t *canPayloadBuffer = (uint8_t*)(canBuffer + 3);
	uint8_t i;

	if (buffer >= ECAN_NUM_BUFFERS) {
		return -1;
	}

	// parse buffer
	if (sid != 0) {
		*sid = canBuffer[0];
		*sid = (*sid >> 2) & 0b11111111111;
	}
	if (eid != 0) {
		if (canBuffer[0] & 0b0000000000000001) {
			*eid = canBuffer[2];
			*eid = (*eid >> 10) & 0b111111;
			*eid = *eid | (canBuffer[1] << 6);
		} else {
			*eid = -1;
		}
	}

	// retrieve payload
	unsigned char payload = canBuffer[2] & 0b1111;
	if (payload > 8) {	// should NEVER happen
		payload = 8;
	}
	if (dlc > payload) {
		dlc = payload;
	}
	for (i=0; i<dlc; i++) {
		data[i] = canPayloadBuffer[i];
	}

	// clear 'full' bit
	if (buffer > 15) {
		C1RXFUL2 = C1RXFUL2 & ~(0b1 << (buffer - 16));
	} else {
		C1RXFUL1 = C1RXFUL1 & ~(0b1 << buffer);
	}

	return dlc;
}

/**
 * Requests transmission of ECAN buffer @a buffer
 * This is non-blocking, and the transmission will occur in the background after this function returns.
 * HOWEVER, this does not guarantee that the transmission will complete successfully.
 *
 * @param buffer Buffer number to transmit.
 *
 * @returns 1 on success, negative on failure.
 * @retval 1 Success.
 * @retval -1 Failure: Invalid buffer.
 * @retval -2 Failure: Not a transmit buffer.
 */
uint8_t ECAN_TransmitBuffer(uint8_t buffer) {
	unsigned volatile int *bufferCtrl = &C1TR01CON + (buffer / 2);
	if (buffer > 7) {
		return -1;
	}

	if (buffer % 2 == 0) {
		if ((*bufferCtrl & 0b10000000) != 0) {
			*bufferCtrl = *bufferCtrl | 0b00001000;
		} else {
			return -2;
		}
	} else {
		if ((*bufferCtrl & 0b1000000000000000) != 0) {
			*bufferCtrl = *bufferCtrl | 0b0000100000000000;
		} else {
			return -2;
		}
	}
}

/*
 * Debug Functions
 */

/**
 * Prints the specified buffer contents to the UART
 */
void ECAN_PrintBuffer(uint8_t buffer) {
	uint16_t sid;
	uint32_t eid;
	uint8_t dlc;
	uint8_t data[8];
	uint8_t i=0;

	putsUART("Buffer ");
	putuiUART(buffer);
	putsUART(" (");

	dlc = ECAN_ReadBuffer(buffer, &sid, &eid, 8, data);

	if (dlc > 8) {
		putsUART("out of bounds)");
		newlineUART();
		return;
	}
	if (buffer < 8) {
		unsigned volatile int *bufferCtrl = &C1TR01CON + (buffer / 2);
		if (buffer % 2 == 0) {
			if ((*bufferCtrl & 0b10000000) != 0) {
				putsUART("TX");
			} else {
				putsUART("RX");
			}
		} else {
			if ((*bufferCtrl & 0b1000000000000000) != 0) {
				putsUART("TX");
			} else {
				putsUART("RX");
			}
		}
	} else {
		putsUART("RX Only");
	}
	putsUART("): ");

	putcolbUART(sid, 11);
	if (eid != -1) {
		putcUART(' ');
		putcolbUART(eid, 18);
	}

	putsUART(", Payload (");
	putuiUART(dlc);
	putsUART("): ");
	for (i=0;i<dlc;i++) {
		putcolbUART(data[i], 8);
		putcUART(' ');
	}
	newlineUART();
}
