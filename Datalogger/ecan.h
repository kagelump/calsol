/*
 * File:   ecan.h
 * Author: Ducky
 *
 * Created on January 15, 2011, 6:09 PM
 *
 * This file contains function prototypes and configuration definitions for the
 * on-board ECAN module
 */
#include "types.h"
#include "hardware.h"

// TODO automatic compile time error checking for ECAN and can timing in general

/* Timing Parameters
 * Design Guidelines:
 * Implicit: 1 TQ synchronization segment
 * Should be between 8 and 25 TQ in a NBT
 * PHSEG2 must be smaller than PRSEG and PH1SEG
 * PHSEG2 must be larger than SJW
 * Sampling happens at end of Phase Segment 1, must take place at 60-70% of bit time
 * Number of TQ must divide event into Fcan clock
 */

/**
 * CAN bitrate, in bits/sec.
 */
//#define ECAN_BITRATE 500000
#define ECAN_BITRATE 1000000
/**
 * Synchronization Jump Width, in Time Quanta (TQ).
 * Code will automatically generate (subtract 1) the register value.
 * (1 TQ - 4 TQ)
 */
#define ECAN_SJW	1
/**
 * Propagation Segment, in Time Quanta (TQ).
 * Code will automatically generate (subtract 1) the register value.
 * (1 TQ - 8 TQ)
 */
#define ECAN_PRSEG	1
/**
 * Phase Segment 1, in Time Quanta (TQ).
 * Code will automatically generate (subtract 1) the register value.
 * (1 TQ - 8 TQ)
 */
#define ECAN_PHSEG1	5
/**
 * Phase Segment 2, in Time Quanta (TQ).
 * Code will automatically generate (subtract 1) the register value.
 * (1 TQ - 8 TQ)
 */
#define ECAN_PHSEG2	3

/**
 * Number of time quanta per bit. (8 TQ - 25 TQ)
 */
#define ECAN_NTQ (ECAN_SJW + ECAN_PRSEG + ECAN_PHSEG1 + ECAN_PHSEG2)
/**
 * CAN Baud Rate Prescaler.
 * Compiler generated and checked.
 */
#define ECAN_BRP ((((Fcy/2)/ECAN_NTQ)/ECAN_BITRATE)-1)

#if (Fcy > 40000000)
	#error "Fcan can not exceed 40 MHz"
#endif
#if (ECAN_SJW < 1) || (ECAN_SJW > 4)
	#error "ECAN_SJW must be between 1 TQ and 4 TQ"
#endif
#if (ECAN_PRSEG < 1) || (ECAN_PRSEG > 8)
	#error "ECAN_PRSEG must be between 1 TQ and 8 TQ"
#endif
#if (ECAN_PHSEG1 < 1) || (ECAN_PHSEG1 > 8)
	#error "ECAN_PHSEG1 must be between 1 TQ and 8 TQ"
#endif
#if (ECAN_PHSEG2 < 1) || (ECAN_PHSEG2 > 8)
	#error "ECAN_PHSEG2 must be between 1 TQ and 8 TQ"
#endif
#if (ECAN_NTQ < 8) || (ECAN_NTQ > 25)
	#error "ECAN_NTQ must be between 8 TQ and 25 TQ"
#endif
#if (ECAN_BRP > 63)
	#error "BRP must not exceed 63"
#endif

/**
 * Number of ECAN RX buffers to use.
 */
#define ECAN_NUM_BUFFERS	24
/**
 * The number of words per buffer, used in the calculation of buffer alignment.
 */
#define ECAN_BUFFER_WORDS	8
/**
 * Byte alignment boundary of the ECAN buffer.
 * This is necessary for the DMA module to function correctly.
 */
#define ECAN_ALIGN			512	// (ECAN_NUM_BUFFERS * ECAN_BUFFER_WORDS * 2)

#if ECAN_NUM_BUFFERS == 4
	#define ECAN_DMABS	0b000
#elif ECAN_NUM_BUFFERS == 6
	#define ECAN_DMABS	0b001
#elif ECAN_NUM_BUFFERS == 8
	#define ECAN_DMABS	0b010
#elif ECAN_NUM_BUFFERS == 12
	#define ECAN_DMABS	0b011
#elif ECAN_NUM_BUFFERS == 16
	#define ECAN_DMABS	0b100
#elif ECAN_NUM_BUFFERS == 24
	#define ECAN_DMABS	0b101
#elif ECAN_NUM_BUFFERS == 32
	#define ECAN_DMABS	0b110
#else
	#error "ECAN_NUM_BUFFERS must be either 4, 6, 8, 12, 16, 24, or 32"
#endif

/**
 * ECAN buffer number to direct a received message to the FIFO.
 */
#define ECAN_FILTER_FIFO		15

typedef enum {
	ECAN_MODE_OPERATE = 0b000,
	ECAN_MODE_DISABLE = 0b001,
	ECAN_MODE_LOOPBACK = 0b010,
	ECAN_MODE_LISTEN = 0b011,
	ECAN_MODE_CONFIG = 0b100,
	ECAN_MODE_LISTENALL	= 0b111
} eECANMode;

/*
 * Function Prototypes
 */
void ECAN_Init();
void ECAN_Config();
void ECAN_SetMode(eECANMode mode);
int8_t ECAN_SetStandardFilter(uint8_t filNum, uint16_t sidFilter, uint8_t maskNum, uint8_t bufNum);
int8_t ECAN_SetStandardMask(uint8_t maskNum,  uint16_t sidFilter);
void ECAN_DisableFilter(uint8_t filNum);
void ECAN_SetupDMA();
int8_t ECAN_GetNextRXBuffer();
int8_t ECAN_WriteStandardBuffer(uint8_t buffer,
	uint16_t sid, uint8_t dlc, uint8_t *data);
int8_t ECAN_ReadBuffer(uint8_t buffer, uint16_t *sid, uint32_t *eid,
	uint8_t dlc, uint8_t *data);
uint8_t ECAN_TransmitBuffer(uint8_t buffer);

void ECAN_PrintBuffer(uint8_t buffer);
