/*
 * File:   main.c
 * Author: Ducky
 *
 * Created on January 15, 2011, 5:22 PM
 */

//	#include <p24Hxxxx.h>	// included in hardware.h
#include <string.h>

#include "hardware.h"

#include "datalogger-debug.h"

#include "ecan.h"
#include "uart.h"
#include "uart-dma.h"
#include "uartansi.h"
#include "timer.h"

#include "sd-spi.h"
#include "sd-spi-dma.h"
#include "fat32.h"
#include "fat32-file.h"
#include "fat32-file-opt.h"
#include "mcp23017.h"

/*
 * Function Prototypes
 */
void OscInit(void);
void AnalogInit(void);
void OutputInit(void);
void PPSInit(void);

/*
 * Configuration Bits
 */
#if defined(__PIC24HJ128GP502__)
	_FBS(RBS_NO_RAM & BSS_NO_FLASH & BWRP_WRPROTECT_OFF);
	_FSS(RSS_NO_RAM & SSS_NO_FLASH & SWRP_WRPROTECT_OFF);
	_FGS(GSS_OFF & GCP_OFF & GWRP_OFF);

	_FOSCSEL(FNOSC_PRI & IESO_OFF);
	_FOSC(FCKSM_CSDCMD & IOL1WAY_OFF & OSCIOFNC_OFF & POSCMD_HS);
	_FWDT(FWDTEN_OFF & WINDIS_OFF & WDTPRE_PR128 & WDTPOST_PS32768);
	_FPOR(ALTI2C_ON & FPWRT_PWR1);
	_FICD(JTAGEN_OFF & ICS_PGD2);
#elif defined (__dsPIC33FJ128MC802__)
	_FBS(RBS_NO_RAM & BSS_NO_FLASH & BWRP_WRPROTECT_OFF);
	_FSS(RSS_NO_RAM & SSS_NO_FLASH & SWRP_WRPROTECT_OFF);
	_FGS(GSS_OFF & GCP_OFF & GWRP_OFF);
	
	_FOSCSEL(FNOSC_PRIPLL & IESO_OFF);
	_FOSC(FCKSM_CSDCMD & IOL1WAY_OFF & OSCIOFNC_OFF & POSCMD_HS);
	//_FOSCSEL(FNOSC_FRC & IESO_OFF);		Configuration for internal 7.37 MHz FRC
	//_FOSC(FCKSM_CSDCMD & IOL1WAY_OFF & OSCIOFNC_ON & POSCMD_NONE);
	_FWDT(FWDTEN_OFF & WINDIS_OFF & WDTPRE_PR128 & WDTPOST_PS32768);
	_FPOR(PWMPIN_ON & HPOL_OFF & ALTI2C_ON & FPWRT_PWR1);
	_FICD(JTAGEN_OFF & ICS_PGD2);
#endif

uint8_t led=0b00000000;

/**
 *
 * @param input
 * @param buffer
 */
void Int16ToString(uint16_t input, char *buffer) {
	uint8_t chr;
	chr = input & 0x0f;
	if (chr < 0x0a) {
		buffer[3] = chr + '0';
	} else {
		buffer[3] = chr + '7';
	}

	chr = (input >> 4) & 0x0f;
	if (chr < 0x0a) {
		buffer[2] = chr + '0';
	} else {
		buffer[2] = chr + '7';
	}

	chr = (input >> 8) & 0x0f;
	if (chr < 0x0a) {
		buffer[1] = chr + '0';
	} else {
		buffer[1] = chr + '7';
	}

	chr = (input >> 12) & 0x0f;
	if (chr < 0x0a) {
		buffer[0] = chr + '0';
	} else {
		buffer[0] = chr + '7';
	}
}

/**
 * 
 * @param input
 * @param buffer
 */
void Int12ToString(uint16_t input, char *buffer) {
	uint8_t chr;
	chr = input & 0x0f;
	if (chr < 0x0a) {
		buffer[2] = chr + '0';
	} else {
		buffer[2] = chr + '7';
	}

	chr = (input >> 4) & 0x0f;
	if (chr < 0x0a) {
		buffer[1] = chr + '0';
	} else {
		buffer[1] = chr + '7';
	}

	chr = (input >> 8) & 0x0f;
	if (chr < 0x0a) {
		buffer[0] = chr + '0';
	} else {
		buffer[0] = chr + '7';
	}
}

/**
 *
 * @param input
 * @param buffer
 */
void Int8ToString(uint8_t input, char *buffer) {
	uint8_t chr;
	chr = input & 0x0f;
	if (chr < 0x0a) {
		buffer[1] = chr + '0';
	} else {
		buffer[1] = chr + '7';
	}

	chr = (input >> 4) & 0x0f;
	if (chr < 0x0a) {
		buffer[0] = chr + '0';
	} else {
		buffer[0] = chr + '7';
	}
}

int main(void) {
	OscInit();
	AnalogInit();
	OutputInit();
	PPSInit();

	Timer_Init();
	I2C_Init();
	UART_Init();
	UART_DMA_Init();
	
	DBG_printf("Calsol Datalogger v0.1 (alpha)");
	DBG_printf("  Built %s %s with C30 ver %i", __DATE__, __TIME__, __C30_VERSION__);
	
	DBG_DATA_printf("Device reset:%s%s%s%s%s%s%s%s",
			(RCONbits.TRAPR? " Trap" : ""),
			(RCONbits.IOPUWR? " IllegalOpcode/UninitializedW" : ""),
			(RCONbits.CM? " ConfigMismatch" : ""),
			(RCONbits.EXTR? " ExternalReset" : ""),
			(RCONbits.SWR? " SoftwareReset" : ""),
			(RCONbits.WDTO? " WatchdogTimeout" : ""),
			(RCONbits.BOR? " BrownOutReset" : ""),
			(RCONbits.POR? " PowerOnReset" : "")
			);

	if (!MCP23017_SingleRegisterWrite(0b000, MCP23017_ADDR_IODIRA, 0b00011111)) {
		DBG_ERR_printf("I2C MCP23017 IODIRA failed");
	}
	if (!MCP23017_SingleRegisterWrite(0b000, MCP23017_ADDR_GPPUA, 0b00011111)) {
		DBG_ERR_printf("I2C MCP23017 GPPUA failed");
	}
	if (!MCP23017_SingleRegisterWrite(0b000, MCP23017_ADDR_GPPUB, 0b11111111)) {
		DBG_ERR_printf("I2C MCP23017 GPPUB failed");
	}

	ECAN_Init();
	ECAN_Config();
	C1FCTRLbits.FSA = 4;	// FIFO starts
	C1FEN1 = 0;
	ECAN_SetStandardFilter(0, 0x00, 0, 15);
	ECAN_SetStandardMask(0, 0x00);
	ECAN_SetMode(ECAN_MODE_OPERATE);
	ECAN_SetupDMA();

	ECAN_WriteStandardBuffer(0, 0xDE, 8, (uint8_t*)"LOLDUCKS");

	DBG_printf("Initialization complete");

	SDCard card;
	FAT32FS fs;
	FAT32File file;
	FAT32FileOpt fileOpt;

	LED_FAULT_IO = 1;
	while (1) {
		uint8_t data;
		
		led &= ~0b01000000;
		if (!MCP23017_SingleRegisterWrite(0b000, MCP23017_ADDR_OLATA, led)) {
			DBG_ERR_printf("I2C MCP23017 OLATA update failed");
		}

		Timer_Delay(500);

		if (MCP23017_SingleRegisterRead(0b000, MCP23017_ADDR_GPIOA, &data)) {
			putcolbUART(data, 8);
			newlineUART();
			if ((data & 0b111) != 0b111) {
				led &= ~0b00100000;
			} else {
				led |= 0b00100000;
			}
		} else {
			DBG_ERR_printf("I2C MCP23017 GPIOA read failed");
		}


		led |= 0b01000000;
		if (!MCP23017_SingleRegisterWrite(0b000, MCP23017_ADDR_OLATA, led)) {
			DBG_ERR_printf("I2C MCP23017 OLATA update failed");
		}
		
		DBG_DATA_printf("Attempting card init");
		if (SD_SPI_Card_Init(&card) < 0) {
			continue;
		}
		SD_SPI_Init(); // TODO HACK HACK REMOVE incldude better max speed calculation
		if (SD_SPI_ReadCID(&card) < 0) {
			continue;
		}
		if (SD_SPI_ReadCSD(&card) < 0) {
			continue;
		}
		SD_DMA_Init();

		if (FAT32_Initialize(&fs, &card) != 1) {
			DBG_ERR_printf("FAT32 Initialize failed");
			continue;
		}
		FAT32File test;
		char fname[10];
		strncpy(fname, "DLGTST00", 8);
		fname[8] = 0;
		fname[9] = 0;

		uint8_t i=0;
		
		for (i=0;i<255;i++) {
			Int8ToString(i, fname+6);
			if (FAT32_OpenFile(&fs, &fs.rootDirectory, &test, fname, "DLG") == -1) {
				break;
			}
		}

		DBG_DATA_printf("Using filename '%s'", fname);
		if (FAT32_CreateFileOpt(&fs, &fs.rootDirectory, &fileOpt, fname, "DLG") != 1) {
			DBG_ERR_printf("FAT32 Create file optimized file failed");
			continue;
		}

		DBG_printf("Created file '%s'", fname);
		break;
	}

	LED_FAULT_IO = 0;
	led |= 0b01000000;

	while (1) {
		unsigned char data;

		if (MCP23017_SingleRegisterRead(0b000, MCP23017_ADDR_GPIOA, &data)) {
			if ((data & 0b111) != 0b111) {
				led &= ~0b00100000;
			} else {
				led |= 0b00100000;
			}
		} else {
			DBG_ERR_printf("I2C MCP23017 GPIOA read failed");
		}
		if (!MCP23017_SingleRegisterWrite(0b000, MCP23017_ADDR_OLATA, led)) {
			DBG_ERR_printf("I2C MCP23017 OLATA update failed");
		}

		unsigned char get = getcUART();
		if (get == 'n') {
			ECAN_TransmitBuffer(0);
			DBG_DATA_printf("CAN Transmit");
		} else if (get == 'k') {
			uint16_t result;
			uint16_t i = 0;
			char buffer[512];

			uint16_t j = 0;
			for (j=0;j<100;j++) {
				Int16ToString(0, buffer + j*5);
				buffer[j*5+4] = '\n';
			}

			for (i=0;i<1024;i++) {
				result = 0;
				while (result == 0) {
					result = FAT32_WriteFileOpt(&fileOpt, (uint8_t*)buffer, 512);
				}

				for (j=0;j<100;j++) {
					Int16ToString(i+1, buffer + j*5);
					buffer[j*5+4] = '\n';
				}
				strncpy(buffer+500, "End of Sect\n", 12);
			}
			while(fileOpt.dataBufferNumFilled > 0) {
				FAT32_WriteFileOpt(&fileOpt, NULL, 0);
			}
			DBG_printf("Done");
		} else if (get == 'l') {
			uint16_t i;
			for (i=0;i<1024;i++) {
				DBG_DATA_printf("Iteration %i", i);
				while (fileOpt.overflowBufferSize > 8100);
				FAT32_WriteFileOpt(&fileOpt, (uint8_t*)"Duckies!\n", 9);
			}
			DBG_printf("Done");
		} else if (get == 'x') {
			DBG_printf("Closing file ... ");
			FAT32_Terminate(&fileOpt);
			DBG_printf("File closed - remove disk now.");
			while(1);
		} else if (get != 0) {
			DBG_printf("Unrecognized key '%c'", get);
			newlineUART();
		}

		int8_t nextBuf;
		while ((nextBuf = ECAN_GetNextRXBuffer()) != -1) {
			uint16_t sid;
			uint32_t eid;
			uint8_t dlc;
			uint8_t data[8];
			char buffer[32];
			uint8_t i = 0;
			if ((C1RXOVF1 != 0) || (C1RXOVF2 != 0)) {
				C1RXOVF1 = 0;
				C1RXOVF2 = 0;
			} else {
			}

			dlc = ECAN_ReadBuffer(nextBuf, &sid, &eid, 8, data);

			Int12ToString(sid, buffer);
			buffer[3] = ',';

			Int8ToString(dlc, buffer + 4);
			for (i=0;i<dlc;i++) {
				buffer[6+i*3] = ',';
				Int8ToString(data[i], buffer+7+i*3);
			}
			
			buffer[6+dlc*3] = '\n';
			buffer[7+dlc*3] = 0;

			FAT32_WriteFileOpt(&fileOpt, (uint8_t*)buffer, 7+dlc*3);

			led ^= 0b10000000;

			UART_DMA_WriteBlockingS(buffer);
		}
	}

    return 0;
}

/**
 * Initializes oscillator configuration, including setting up PLL
 */
void OscInit(void) {
	_PLLPRE = 14;	// N1=16
	_PLLPOST = 1;	// N2=4
	_PLLDIV = 126;	// M=128
}

/**
 * Initializes analog input configuration, including whether pins are digital or analog.
 */
void AnalogInit(void) {
	AD1PCFGL = 0b0001111111111111;	// Set unused analog pins for digital IO

	AD1CON2bits.VCFG = 0b000;		// VR+ = AVdd, VR- = AVss
	AD1CON3bits.ADCS = 31;			// 32 Tcy conversion clock
	AD1CON1bits.SSRC = 0b111;		// Auto-sample
	AD1CON3bits.SAMC = 8;			// and Auto-sample Time bits
	AD1CON1bits.FORM = 0b00;		// Integer representation
	AD1CON2bits.SMPI = 0b0000;		// Interrupt rate, 1 for each sample/convert

	//AD1CON1bits.ADON = 1;			// Enable A/D module	//todo reenable analog
}

/**
 * Initializes both direction and initial state of all GPIO pins.
 */
void OutputInit(void) {
	LED_FAULT_IO = 0;
	LED_FAULT_TRIS = 0;

	SD_SPI_CS_IO = 1;
	SD_SPI_CS_TRIS = 0;

	SD_SPI_SCK_TRIS = 0;
	SD_SPI_MOSI_TRIS = 0;
}

/**
 * Initializes PPS selections for all peripheral modules using PPS: UART, ECAN, SD SPI.
 */
void PPSInit(void) {
	// Unlock Registers
	__asm__ volatile (	"MOV #OSCCON, w1 \n"
						"MOV #0x46, w2 \n"
						"MOV #0x57, w3 \n"
						"MOV.b w2, [w1] \n"
						"MOV.b w3, [w1] \n"
						"BCLR OSCCON,#6");
	// UART Pins
	//UART_TX_RPR = U1TX_IO;
	UART_TX_RPR = U2TX_IO;
	_U1RXR = UART_RX_RPN;

	// ECAN Pins
	ECAN_TXD_RPR = C1TX_IO;
	_C1RXR = ECAN_RXD_RPN;

	// SD SPI Pins
	SD_SPI_SCK_RPR = SCK2OUT_IO;
	SD_SPI_MOSI_RPR = SDO2_IO;
	_SDI2R = SD_SPI_MISO_RPN;

	// Lock Registers
	__asm__ volatile (	"MOV #OSCCON, w1 \n"
						"MOV #0x46, w2 \n"
						"MOV #0x57, w3 \n"
						"MOV.b w2, [w1] \n"
						"MOV.b w3, [w1] \n"
						"BSET OSCCON, #6" );
}
