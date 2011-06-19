/*
 * File:   sd-spi-dma.c
 * Author: Ducky
 *
 * Created on March 22, 2011, 10:45 PM
 */

#include <libpic30.h>

#include "types.h"
#include "hardware.h"

#include "sd-spi-phy.h"
#include "sd-spi-cmd.h"
#include "sd-spi.h"
#include "sd-spi-dma.h"

#define SD_DMA_NUM_BUFFERS	3	//!< Number of SD SPI DMA buffers.

#define SD_DMA_PREPAD_SIZE	1	//!< Number of bytes of padding before each DMA buffer. This is to ensure word-alignment of data bytes.
#define SD_DMA_TOKEN_SIZE	1	//!< Number of bytes to add before each data block - start tran token.
#define SD_DMA_DATA_SIZE	512	//!< Number of bytes of the data area for each data block.
#define SD_DMA_CRC_SIZE		2	//!< Number of bytes to add after data in each block - 2 CRC bytes.
#define SD_DMA_BUFFER_SIZE	(SD_DMA_PREPAD_SIZE + SD_DMA_DATA_SIZE + SD_DMA_TOKEN_SIZE + SD_DMA_CRC_SIZE)

#define SD_DMA_TRANSFER_CYCLES	10*2	//!< Number of CPU cycles taken to transfer a SPI byte

uint8_t SD_DMA_Buffer0[SD_DMA_BUFFER_SIZE] __attribute__((space(dma)));	//!< SD DMA data block buffer 0
uint8_t SD_DMA_Buffer1[SD_DMA_BUFFER_SIZE] __attribute__((space(dma)));	//!< SD DMA data block buffer 1
uint8_t SD_DMA_Buffer2[SD_DMA_BUFFER_SIZE] __attribute__((space(dma)));	//!< SD DMA data block buffer 2

uint8_t SD_DMA_TransmitIdleBuffer __attribute((space(dma)));			//!< SD DMA buffer to hold the idle byte for transmission
uint8_t SD_DMA_ReceiveBuffer __attribute__((space(dma)));				//!< SD DMA buffer to receive bytes

uint8_t *SD_DMA_Buffer[SD_DMA_NUM_BUFFERS];								//!< Pointer to the SD DMA data block buffers in array form
uint16_t SD_DMA_Buffer_Offset[SD_DMA_NUM_BUFFERS];						//!< Holds DMA offset of the SD DMA data block buffers

/**
 * SD DMA State variables are below.
 * To reduce parallelism bugs, the state variables are locked depending on state
 * of the variable SD_DMA_BackgroundState. Whether the user program or the DMA module
 * (through interrupts) has control of the state variables is dependant on the current
 * SD_DMA_BackgroundState.
 * Note - Currently the only way to stop an operation in progress is to disable the DMA module
 * and re-initialize the SD card (send CMD0, ...)
 *
 * Programming Guidelines:
 * - When state is owned by the user program, state should be changed BEFORE
 *	starting the DMA transfer.
 *
 * TODO - Need to ensure consistent states on reset and add timeout
 */

/**
 * This variable keeps track of what the DMA module is doing in the background.
 * This state is only changed to keep track of state between function calls and interrupts.
 * This state is NOT changed when SD card operations are operating in teh foreground.
 * In general, a new command should only be issued when this state is in SD_DMA_Idle.
 */
enum {
	SD_DMA_Idle=0,				//!< Nothing happening in the background, new commands can be issued.
								//!< Parallelism: State variables owned by user
	
/*	Background single block writes are not currently supported
	SD_DMA_SBW_Idle,			//!< A Single Block Write command has been issued, data transfer has not yet begun.
								//!< Parallelism: State variables owned by program (user-initiated actions)
	SD_DMA_SBW_BlockSend,		//!< A block is being transferred for a Single Block Write command.
								//!< Parallelism: State variables owned by DMA module interrupts
	SD_DMA_SBW_BlockWait,		//!< Waiting for data response token after sending a block.
								//!< Parallelism: State variables owned by DMA module interrupts
	SD_DMA_SBW_BlockBusy,		//!< Waiting for end of busy signal after the data response token.
								//!< Parallelism: State variables owned by program ( SD_DMA_Tasks() )
*/
	SD_DMA_CommandTerminate,	//!< The required clocks after terminating a command are being transferred.
								//!< Parallelism: State variabled owned by DMA module interrupts.

	SD_DMA_MBW_Idle=10,			//!< A Multiple Block Write command has been issued, data is currently not being transferred.
								//!< Parallelism: State variables owned by program (user-initiated actions)
	SD_DMA_MBW_BlockSend,		//!< A block is being transferred for a Multiple Block Write command.
								//!< Parallelism: State variables owned by DMA module interrupts
	SD_DMA_MBW_BlockWait,		//!< Waiting for data response token after sending a block.
								//!< Parallelism: State variables owned by DMA module interrupts
	SD_DMA_MBW_BlockBusy,		//!< Waiting for end of busy signal after the data response token.
								//!< Parallelism: State variables owned by program ( SD_DMA_Tasks() )
	SD_DMA_MBW_CommandBusy,		//!< Waiting for end of busy signal after a Stop Tran token.
								//!< Parallelism: State variables owned by program ( SD_DMA_Tasks() )

	SD_DMA_SBR_BlockWait=20,	//!< A Single Block Read command has been issued, currently waiting for a Data Token response
								//!< Parallelism: State variables owned by DMA module interrupts
	SD_DMA_SBR_BlockReceive,	//!< A block is being transferred for a Single Block Read command.
								//!< Parallelism: State variables owned by DMA module interrupts

} SD_DMA_BackgroundState;
uint8_t SD_DMA_BackgroundCommand;	//!< Opcode of the outstanding command in the background, valid only if SD_SPI_DMA_BackgroundState != SD_DMA_Idle.
uint8_t SD_DMA_BackgroundResponse;	//!< Response of the outstanding command in the background, valid depending on state

/**
 * Initializes SD DMA state/buffer variables and
 *	sets up DMA channels 2 and 3 for SPI SDO and SDI.
 */
void SD_DMA_Init() {
#if SD_DMA_NUM_BUFFERS != 3
#error "SD SPI SMD Buffers not 3!"
#error "If the number of buffers is being changed, you must also update the code in this section to be consistent"
#endif
	// Initialize state variables
	SD_DMA_BackgroundState = SD_DMA_Idle;

	// Initialize buffer variables and calculate DMA offset address
	SD_DMA_Buffer[0] = SD_DMA_Buffer0;
	SD_DMA_Buffer[1] = SD_DMA_Buffer1;
	SD_DMA_Buffer[2] = SD_DMA_Buffer2;
	
	SD_DMA_Buffer_Offset[0] = __builtin_dmaoffset(SD_DMA_Buffer0) + SD_DMA_PREPAD_SIZE;
	SD_DMA_Buffer_Offset[1] = __builtin_dmaoffset(SD_DMA_Buffer1) + SD_DMA_PREPAD_SIZE;
	SD_DMA_Buffer_Offset[2] = __builtin_dmaoffset(SD_DMA_Buffer2) + SD_DMA_PREPAD_SIZE;

	SD_DMA_TransmitIdleBuffer = SD_SPI_DUMMY_BYTE;

	// Setup DMA channel 2 (MOSI, transmit channel)
	DMA2CON = 0b0110000000000001;
	DMA2REQ = 0x21;
	DMA2PAD = (volatile unsigned int) &SPI2BUF;

	// Setup DMA channel 3 (MISO, receive channel)
	DMA3CON = 0b0100000000010000;
	DMA3REQ = 0x21;
	DMA3PAD = (volatile unsigned int) &SPI2BUF;
}

/**
 * Returns a pointer to the beginning of a SD SPI DMA buffer's data area.
 * @param bufferNum DMA buffer number.
 * @return Pointer to beginning of the data area for the specified buffer or
 *	NULL if an invalid /a bufferNum is specified.
 *	Its length is SD_DMA_BUFFER_SIZE ( = 512 ).
 * @retval NULL Invalid /a bufferNum specified.
 */
uint8_t* SD_DMA_GetBuffer(uint8_t bufferNum) {
	if (bufferNum  >= SD_DMA_NUM_BUFFERS) {
		return NULL;
	}
	return SD_DMA_Buffer[bufferNum] + SD_DMA_PREPAD_SIZE + SD_DMA_TOKEN_SIZE;
}

/**
 * @return Whether the SD SPI DMA interface is busy.
 * @retval 1 There is a SD SPI DMA operation in progress.
 * @retval 0 There is no SD SPI DMA operation in progress. Another transfer may be initiated.
 */
uint8_t SD_DMA_GetBusy() {
	return DMA2CONbits.CHEN;
}

/**
 * @return Whether there is a DMA command to the SD card in progress.
 * @retval 0 There is a DMA command to the SD card in progress.
 *	It is not safe to issue new command to the SD card.
 * @retval 1 There is no DMA command to the SD card in progress.
 *	It is safe to issue new commands to the SD card.
 */
uint8_t SD_DMA_GetIdle() {
	return (SD_DMA_BackgroundState == SD_DMA_Idle);
}

/**
 * @return Command number (opcode) of the DMA command in progress.
 *	Valid only if there is a DMA command im progress (SD_DMA_GetIdle() returns 0)
 */
uint8_t SD_DMA_GetBackgroundCommand() {
	return SD_DMA_BackgroundCommand;
}

/**
 * Uses SPI through DMA to send the command for Single Block Read.
 * This function blocks until the command is sent and a Data Token is received.
 *  The block read operation continues in the background, and when it is complete,
 *  a call to SD_DMA_SBR_GetStatus() will return a nonzero value.
 * This operation only happens if SD_DMA_BackgroundState == SD_DMA_Idle (no command in progress),
 *	otherwise this function returns zero to indicate failure.
 *
 * @pre The SD Card @a card must be successfully initialized (call to @c SD_SPI_Card_Init returned 1).
 * @pre The SD Card @a must have had the CSD successfully read (call to @c SD_SPI_ReadCSD returned 1).
 * @pre There is no command in progress. (SD_DMA_BackgroundState == SD_DMA_Idle)
 *
 * @param[in] card SDCard struct.
 * @param[in] begin Block number to begin on. A block is defined to be 512 bytes, regardless of what the SD Card reports.
 * @param[in] bufferNum DMA buffer number to store received data in.
 * @return Success or failure.
 * @retval 1 Success - data blocks can be sent, SD_DMA_BackgroundState now SD_DMA_MBW_Idle.
 * @retval 0 Failure - command failed or prerequisites not met.
 *	If the command failed, SD_DMA_BackgroundState is still SD_DMA_Idle.
 *	If the pre-requisites are not met. SD_DMA_BackgroundState is not touched.
 *	It may be necessary to re-initialize the SD card.
 */
uint8_t SD_DMA_SBR_Start(SDCard *card, fs_addr_t begin, uint8_t bufferNum) {
	uint8_t result;				// Variable to store SD Card responses into.
	uint8_t addr[4];			// Input address in 4 bytes to send to the SD card.

	// Sanity checks
	if (SD_DMA_BackgroundState != SD_DMA_Idle) {	// Background state check
		return 0;
	}
	if (bufferNum >= SD_DMA_NUM_BUFFERS) {		// Invalid buffer number
		return 0;
	}

	begin = begin << 9;
	addr[0] = begin & 0xff;
	addr[1] = (begin >> 8) & 0xff;
	addr[2] = (begin >> 16) & 0xff;
	addr[3] = (begin >> 24) & 0xff;

	// Begin SD Card Operations
	SD_SPI_Open();
	// Send command
	result = SD_SPI_SendCommand(SD_SPI_CMD_READ_SINGLE_BLOCK, addr[3], addr[2], addr[1], addr[0], 0x00);

	if (result != 0x00) {
		SD_SPI_Terminate();
		SD_SPI_Close();
#ifdef SD_SPI_DEBUG_UART
		putcolbUART(result, 8);
		newlineUART();
		putlineUART("Failure: Bad response");
#endif
		return 0;
	}

	// Wait for Data Response Token
	result = SD_SPI_DUMMY_BYTE;
	while (result == SD_SPI_DUMMY_BYTE) {
		result = SD_SPI_Transfer(SD_SPI_DUMMY_BYTE);
	}
	if (result != SD_SPI_TOKEN_START_BLOCK) {
		SD_SPI_Terminate();
		SD_SPI_Close();

		return 0;
	}

	// Prepare DMA registers
	DMA2CON = 0b0110000000010001;	// No post-increment, one-shot, no ping-pong
	DMA2CNT = SD_DMA_DATA_SIZE + SD_DMA_CRC_SIZE - 1;
	DMA2STA = __builtin_dmaoffset(&SD_DMA_TransmitIdleBuffer);
	IEC1bits.DMA2IE = 0;

	DMA3CON = 0b0100000000000001;	// Post-increment, one-shot, no ping-pong
	DMA3CNT = SD_DMA_DATA_SIZE + SD_DMA_CRC_SIZE - 1;
	DMA3STA = SD_DMA_Buffer_Offset[bufferNum] + SD_DMA_TOKEN_SIZE;	// Skip the block start token
	IFS2bits.DMA3IF = 0;
	IEC2bits.DMA3IE = 1;

	SD_DMA_BackgroundState = SD_DMA_SBR_BlockReceive;

	// Enable DMA channels and initiate transfer
	DMA2CONbits.CHEN = 1;
	DMA3CONbits.CHEN = 1;
	DMA2REQbits.FORCE = 1;

	return 1;
}


/**
 * @return Whether the state is SD_DMA_MBW_Idle
 * @retval 0 The MBW command is not idle.
 *	It is not safe to send a new block to the SD card.
 * @retval 1 The MBW command is idle.
 *	It is safe to send a new block to the SD card.
 */
uint8_t SD_DMA_MBW_GetIdle() {
	return (SD_DMA_BackgroundState == SD_DMA_MBW_Idle);
}

/**
 * Uses SPI through DMA to send the command for Multiple Block Write.
 * This function blocks until the command is sent and a response is received,
 *	but does not send any data blocks. That is done by calling SD_DMA_MBW_SendBlock
 *	(possibly multiple times for a single command). The command is terminated
 *	and data is programmed into the NVM by calling SD_DMA_MBW_End.
 * This operation only happens if SD_DMA_BackgroundState == SD_DMA_Idle (no command in progress),
 *	otherwise this function returns zero to indicate failure.
 *
 * @pre The SD Card @a card must be successfully initialized (call to @c SD_SPI_Card_Init returned 1).
 * @pre The SD Card @a must have had the CSD successfully read (call to @c SD_SPI_ReadCSD returned 1).
 * @pre There is no command in progress. (SD_DMA_BackgroundState == SD_DMA_Idle)
 *
 * @param[in] card SDCard struct.
 * @param[in] begin Block number to begin on. A block is defined to be 512 bytes, regardless of what the SD Card reports.
 * @return Success or failure.
 * @retval 1 Success - data blocks can be sent, SD_DMA_BackgroundState now SD_DMA_MBW_Idle.
 * @retval 0 Failure - command failed or prerequisites not met.
 *	If the command failed, SD_DMA_BackgroundState is still SD_DMA_Idle.
 *	If the pre-requisites are not met. SD_DMA_BackgroundState is not touched.
 *	It may be necessary to re-initialize the SD card.
 */
uint8_t SD_DMA_MBW_Start(SDCard *card, fs_addr_t begin) {
	uint8_t result;				// Variable to store SD Card responses into.
	uint8_t addr[4];			// Input address in 4 bytes to send to the SD card.

	// Sanity checks
	if (SD_DMA_BackgroundState != SD_DMA_Idle) {	// Background state check
		return 0;
	}

	begin = begin << 9;
	addr[0] = begin & 0xff;
	addr[1] = (begin >> 8) & 0xff;
	addr[2] = (begin >> 16) & 0xff;
	addr[3] = (begin >> 24) & 0xff;

	// Begin SD Card Operations
	SD_SPI_Open();
	// Send command
	result = SD_SPI_SendCommand(SD_SPI_CMD_WRITE_MULTIPLE_BLOCK, addr[3], addr[2], addr[1], addr[0], 0x00);

	if (result != 0x00) {
		SD_SPI_Terminate();
		SD_SPI_Close();
#ifdef SD_SPI_DEBUG_UART
		putcolbUART(result, 8);
		newlineUART();
		putlineUART("Failure: Bad response");
#endif
		return 0;
	}

	SD_DMA_BackgroundState = SD_DMA_MBW_Idle;

	return 1;
}

/**
 * Uses SPI through DMA to send a write block for a Multiple Block Write operation.
 * This returns before the DMA operation completes - that is, the transfer continues
 *  in the background.
 * This operation only happens if SD_DMA_BackgroundState == SD_DMA_MBW_Idle (Multiple Block Write Idle),
 *	otherwise this function returns zero to indicate failure.
 *
 * @pre The buffer /a bufferNum is already filled with the data to write to the card.
 * @pre The Multiple Block Write command has already been sent to the SD Card and
 *	there are no operations in progress. (SD_DMA_BackgroundState == SD_DMA_MBW_Idle)
 * @param bufferNum DMA buffer number containing the data to send.
 *
 * @return Status of the operation
 * @retval 1 Success - data block will be transferred in the background.
 * @retval 0 Failure - pre-requisite condition not met, no change to current
 *	DMA background state and no operations initiated.
 */
uint8_t SD_DMA_MBW_SendBlock(uint8_t bufferNum) {
	if (SD_DMA_BackgroundState != SD_DMA_MBW_Idle) {	// Failure - pre-requisite not met (SD_DMA_BackgroundState not SD_DMA_MBW_Idle)
		return 0;
	}
	if (bufferNum > SD_DMA_NUM_BUFFERS) {				// Failure - invalid buffer specified.
		return 0;
	}

	// Clear any data remaining in the RX buffer
	if (SPI2STATbits.SPIRBF) {
		uint8_t dummy = SPI2BUF;
	}

	// Append prefix (start block token) and postfix (dummy CRC)
	SD_DMA_Buffer[bufferNum][1] = SD_SPI_TOKEN_MBW_START_BLOCK;
	SD_DMA_Buffer[bufferNum][514] = SD_SPI_DUMMY_BYTE;
	SD_DMA_Buffer[bufferNum][515] = SD_SPI_DUMMY_BYTE;

	// Update state
	SD_DMA_BackgroundState = SD_DMA_MBW_BlockSend;

	// Prepare DMA registers
	DMA2CON = 0b0110000000000001;	// Post-increment, one-shot, no ping-pong
	DMA2CNT = SD_DMA_TOKEN_SIZE + SD_DMA_DATA_SIZE + SD_DMA_CRC_SIZE - 1;
	DMA2STA = SD_DMA_Buffer_Offset[bufferNum];
	IFS1bits.DMA2IF = 0;
	IEC1bits.DMA2IE = 1;
	IEC2bits.DMA3IE = 0;

	DMA3CON = 0b0100000000010000;	// No post-increment, continuous, no ping-pong
	DMA3CNT = 0;
	DMA3STA = __builtin_dmaoffset(&SD_DMA_ReceiveBuffer);

	// Enable DMA channels and initiate transfer
	DMA2CONbits.CHEN = 1;
	DMA3CONbits.CHEN = 1;
	DMA2REQbits.FORCE = 1;

	return 1;
}

/**
 * Uses SPI through DMA to send a Stop Tran token.
 * This blocks until the token is sent, and then lets the busy signals continue in the background.
 * This operation only happens if SD_DMA_BackgroundState == SD_DMA_MBW_Idle (Multiple Block Write Idle),
 *	otherwise this function returns zero to indicate failure.
 *
 * @pre The Multiple Block Write command has already been sent to the SD Card and
 *	there are no operations in progress. (SD_DMA_BackgroundState == SD_DMA_MBW_Idle)
 *
 * @return Status of the operation
 * @retval 1 Success - Stop Tran token sent, busy signals being received in the background.
 * @retval 0 Failure - pre-requisite condition not met, no change to current
 *	DMA background state and no operations initiated.
 */
uint8_t SD_DMA_MBW_End() {
	if (SD_DMA_BackgroundState != SD_DMA_MBW_Idle) {	// Failure - pre-requisite not met (SD_DMA_BackgroundState not SD_DMA_MBW_Idle)
		return 0;
	}

	DMA3CONbits.CHEN = 0;		// Disable receive channel for processor receive mode
	SD_SPI_Transfer(SD_SPI_TOKEN_MBW_STOP_TRAN);

	if (SPI2STATbits.SPIROV) {
		putcUART('x');
		SPI2STATbits.SPIROV = 0;
	}

	SD_DMA_BackgroundResponse = SD_DMA_ReceiveBuffer;		// Store data response token
	SD_DMA_ReceiveBuffer = 0x00;

	// Prepare DMA to continuously transmit idle bytes
	DMA2CON = 0b0110000000010000;	// No post-increment, continuous, no ping-pong
	DMA2CNT = 0;
	DMA2STA = __builtin_dmaoffset(&SD_DMA_TransmitIdleBuffer);
	IEC1bits.DMA2IE = 0;
	IEC2bits.DMA3IE = 0;			// Disable all interrupts, program handles it from here

	// Update background state
	SD_DMA_BackgroundState = SD_DMA_MBW_CommandBusy;

	DMA2CONbits.CHEN = 1;
	DMA3CONbits.CHEN = 1;
	
	DMA2REQbits.FORCE = 1;
}

/**
 * @return Status of the last block sent.
 * @retval 0x00 Still waiting for busy signals to end.
 * @retval anyting_else Data response token of last block sent.
 *	The block send operation is now complete, and a new block can be sent.
 */
uint8_t SD_DMA_MBW_GetBlockStatus() {
	if (SD_DMA_BackgroundState == SD_DMA_MBW_BlockBusy
			&& SD_DMA_ReceiveBuffer == SD_SPI_IDLE_RESPONSE) {		// Have a data response token, busy signals over
		SD_DMA_BackgroundState = SD_DMA_MBW_Idle;
		DMA2CONbits.CHEN = 0;	// Stop sending idle bytes
		__delay32(SD_DMA_TRANSFER_CYCLES);	// Wait for outstanding bytes, if any
		DMA3CONbits.CHEN = 0;	// Stop receiving bytes

		return SD_DMA_BackgroundResponse;
	} else if (SD_DMA_BackgroundState == SD_DMA_MBW_CommandBusy
			&& SD_DMA_ReceiveBuffer == SD_SPI_IDLE_RESPONSE) {
		unsigned char result;

		SD_DMA_BackgroundState = SD_DMA_Idle;
		DMA2CONbits.CHEN = 0;	// Stop sending idle bytes
		__delay32(SD_DMA_TRANSFER_CYCLES);	// Wait for outstanding bytes, if any
		DMA3CONbits.CHEN = 0;	// Stop receiving bytes

		SD_SPI_Terminate();
		SD_SPI_Close();

		return 0x01;
	} else {
		return 0x00;
	}
}

/**
 * DMA2 Interrupt - SPI Transmit Complete Interrupt
 */
void __attribute__((__interrupt__)) _DMA2Interrupt(void) {
	IFS1bits.DMA2IF = 0;
	switch (SD_DMA_BackgroundState) {
		case SD_DMA_MBW_BlockSend:
			// Update state
			SD_DMA_BackgroundState = SD_DMA_MBW_BlockWait;

			// Prepare DMA to send idle bytes and wait for data token response
			DMA2CON = 0b0110000000010001;	// No post-increment, one-shot, no ping-pong
			DMA2CNT = 0;
			DMA2STA = __builtin_dmaoffset(&SD_DMA_TransmitIdleBuffer);
			IEC1bits.DMA2IE = 0;
			IFS2bits.DMA3IF = 0;
			IEC2bits.DMA3IE = 1;	// Interrupt on receive only

			// Re-enable channel 2 and initiate DMA transfer
			DMA2CONbits.CHEN = 1;
			DMA2REQbits.FORCE = 1;
			break;
		default:
			break;
	}
}

/**
 * DMA3 Interrupt - SPI Reception Complete Interrupt
 */
void __attribute__((__interrupt__)) _DMA3Interrupt(void) {
	IFS2bits.DMA3IF = 0;
	switch (SD_DMA_BackgroundState) {
		case SD_DMA_MBW_BlockWait:
			if ((SD_DMA_ReceiveBuffer & 0b00010001) == 0b00000001) {	// Data response token
				SD_DMA_BackgroundResponse = SD_DMA_ReceiveBuffer;		// Store data response token
				SD_DMA_ReceiveBuffer = 0x00;

				// Prepare DMA to continuously transmit idle bytes
				DMA2CON = 0b0110000000010000;	// No post-increment, continuous, no ping-pong
				IEC2bits.DMA3IE = 0;			// Disable all interrupts, program handles it from here
				
				DMA2CONbits.CHEN = 1;
				DMA2REQbits.FORCE = 1;

				// Update background state
				SD_DMA_BackgroundState = SD_DMA_MBW_BlockBusy;
			} else {	// Not data response token
				// Keep sending out idle bytes
				DMA2CONbits.CHEN = 1;
				DMA2REQbits.FORCE = 1;
			}
			break;
		case SD_DMA_CommandTerminate:
			DMA2CONbits.CHEN = 0;
			DMA3CONbits.CHEN = 0;

			SD_SPI_Close();

			SD_DMA_BackgroundState = SD_DMA_Idle;
			break;
		case SD_DMA_SBR_BlockReceive:
			SD_DMA_BackgroundState = SD_DMA_CommandTerminate;
			
			// Prepare DMA registers
			DMA2CON = 0b0110000000010001;	// No post-increment, one-shot, no ping-pong
			DMA2CNT = 2 - 1;
			DMA2STA = __builtin_dmaoffset(&SD_DMA_TransmitIdleBuffer);
			IFS1bits.DMA2IF = 0;
			IEC1bits.DMA2IE = 0;

			DMA3CON = 0b0100000000010000;	// No post-increment, one-shot, no ping-pong
			DMA3CNT = 2 - 1;
			DMA3STA = __builtin_dmaoffset(&SD_DMA_ReceiveBuffer);
			IFS2bits.DMA3IF = 0;
			IEC2bits.DMA3IE = 1;

			// Enable DMA channels and initiate transfer
			DMA2CONbits.CHEN = 1;
			DMA3CONbits.CHEN = 1;
			DMA2REQbits.FORCE = 1;
		default:
			break;
	}
}
