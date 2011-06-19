/*
 * File:   sd-spi-debug.c
 * Author: Ducky
 *
 * Created on January 19, 2011, 6:24 PM
 *
 * Debugging tools for SD-SPI. Usually involves dumping data to the UART.
 */
#include "sd-spi-phy.h"
#include "sd-spi-cmd.h"
#include "sd-spi.h"

#include "uart.h"

char *CSD_TAAC_TimeUnit[8] = {
	"1ns", "10ns", "100ns", "1us",
	"10us", "100us", "1ms", "10ms"
};
char *CSD_TAAC_TimeValue[16] = {
	"Rsv", "1.0", "1.2", "1.3",
	"1.5", "2.0", "2.5", "3.0",
	"3.5", "4.0", "4.5", "5.0",
	"5.5", "6.0", "7.0", "8.0"
};

char *CSD_TRAN_SPEED_TransferRateUnit[8] = {
	"100kbit/s", "1Mbit/s", "10Mbit/s", "100Mbit/s",
	"Rsv4", "Rsv5", "Rsv6", "Rsv7"
};
char *CSD_TRAN_SPEED_TimeValue[16] = {
	"Rsv", "1.0", "1.2", "1.3",
	"1.5", "2.0", "2.5", "3.0",
	"3.5", "4.0", "4.5", "5.0",
	"5.5", "6.0", "7.0", "8.0"
};
char *CSD_VDD_CURR_MIN_Current[8] = {
	"0.5mA", "1mA", "5mA", "10mA",
	"25mA", "35mA", "60mA", "100mA",
};
char *CSD_VDD_CURR_MAX_Current[8] = {
	"1mA", "5mA", "10mA", "25mA",
	"35mA", "45mA", "80mA", "200mA"
};
char *CSD_FILE_FORMAT_Type[2][4] = {
	{
		"Hard disk-like with partition table",
		"DOS FAT (floppy-like) with boot-sector only",
		"Universal File Format",
		"Others/Unknown"
	},
	{
		"Rsv1,0",
		"Rsv1,1",
		"Rsv1,2",
		"Rsv1,3"
	}
};

/**
 * Outputs the data in the card CID register onto the UART in a human-readable form.
 *
 * @pre The CSD data must be successfully read (call to @c SD_SPI_ReadCID returned 1).
 *
 * @param[in] card Card whose data to output. Must be initialized, otherwise will output gibberish.
 */
void SD_PrintCID(SDCard *card) {
	putlineUART("Card CID Data:");

	putsUART("* MID: Manufacturer ID: ");
	putiUART(card->CID.MID);
	newlineUART();

	putsUART("* OID: OEM/Application ID: ");
	putcUART(card->CID.OID[0]);
	putcUART(card->CID.OID[1]);
	putsUART(" (");		puthUART(card->CID.OID[0]);
	putcUART(' ');		puthUART(card->CID.OID[1]);
	putlineUART(")");

	putsUART("* PNM: Product Name: ");
	putcUART(card->CID.PNM[0]);
	putcUART(card->CID.PNM[1]);
	putcUART(card->CID.PNM[2]);
	putcUART(card->CID.PNM[3]);
	putcUART(card->CID.PNM[4]);
	putsUART(" (");	putlenhUART(card->CID.PNM[0], 2);
	putcUART(' ');		putlenhUART(card->CID.PNM[1], 2);
	putcUART(' ');		putlenhUART(card->CID.PNM[2], 2);
	putcUART(' ');		putlenhUART(card->CID.PNM[3], 2);
	putcUART(' ');		putlenhUART(card->CID.PNM[4], 2);
	putlineUART(")");

	putsUART("* PRV: Product Revision: ");
	putiUART(card->CID.PRV & 0x0F);
	putcUART('.');
	putiUART((card->CID.PRV >> 4) & 0x0F);
	newlineUART();

	putsUART("* PSN: Product Serial: ");
	putlenhUART((card->CID.PSN >> 24) & 0x0F, 2);
	putcUART(' ');	putlenhUART((card->CID.PSN >> 16) & 0x0F, 2);
	putcUART(' ');	putlenhUART((card->CID.PSN >> 8) & 0x0F, 2);
	putcUART(' ');	putlenhUART((card->CID.PSN >> 0) & 0x0F, 2);
	newlineUART();

	putsUART("* MDT: Manufacturing Date: ");
	putiUART((card->CID.MDT >> 0) & 0x0F);
	putcUART('-');
	putiUART(((card->CID.MDT >> 4) & 0xFF) + 2000);
	newlineUART();
}

/**
 * Outputs the data in the card CSD Version 1 register onto the UART in a human-readable form.
 *
 * @pre The CSD data must be successfully read (call to @c SD_SPI_ReadCSD returned 1).
 * @pre The data must be version 1 (CSD_STRUCTURE = 0b00).
 *
 * @param[in] card Card whose data to output. Must be initialized, otherwise will output gibberish.
 */
void SD_PrintCSDVer1(SDCard *card) {
	int i;

	putlineUART("Card CSD Data:");

	putsUART("* CSD_STRUCTURE: CSD structure: ");
	putcolbUART(card->CSD.CSDVer1.CSD_STRUCTURE, 2);
	putcUART(' ');
	putiUART(card->CSD.CSDVer1.CSD_STRUCTURE);
	newlineUART();

	putsUART("* TAAC: data read access-time-1: ");
	putcolbUART(card->CSD.CSDVer1.TAAC, 8);
	putcUART(' ');
	putsUART(CSD_TAAC_TimeValue[(card->CSD.CSDVer1.TAAC >> 3) & 0b1111]);
	putsUART(" * ");
	putsUART(CSD_TAAC_TimeUnit[(card->CSD.CSDVer1.TAAC >> 0) & 0b111]);
	newlineUART();

	putsUART("* NSAC: data read access-time-2 in CLK cycles (NSAC*100): ");
	putcolbUART(card->CSD.CSDVer1.NSAC, 8);
	putcUART(' ');
	putiUART(card->CSD.CSDVer1.NSAC);
	putsUART(" * 100 clock cycles");
	newlineUART();

	putsUART("* TRAN_SPEED: max. data transfer rate: ");
	putcolbUART(card->CSD.CSDVer1.TAAC, 8);
	putcUART(' ');
	putsUART(CSD_TRAN_SPEED_TimeValue[(card->CSD.CSDVer1.TRAN_SPEED >> 3) & 0b1111]);
	putsUART(" * ");
	putsUART(CSD_TRAN_SPEED_TransferRateUnit[(card->CSD.CSDVer1.TRAN_SPEED >> 0) & 0b111]);
	newlineUART();

	putsUART("* CCC: card command classes: ");
	putcolbUART(card->CSD.CSDVer1.CCC, 12);
	putsUART(" (Supported classes:");
	for (i=0;i<12;i++) {
		if ((card->CSD.CSDVer1.CCC >> i) & 0b1) {
			putcUART(' ');
			putiUART(i);
		}
	}
	putsUART(")");
	newlineUART();

	putsUART("* READ_BL_LEN: max. read data block length: ");
	putcolbUART(card->CSD.CSDVer1.READ_BL_LEN, 4);
	putcUART(' ');
	if (card->CSD.CSDVer1.READ_BL_LEN >= 9 && card->CSD.CSDVer1.READ_BL_LEN <= 11) {
		putiUART((int)0b1 << card->CSD.CSDVer1.READ_BL_LEN);
	} else {
		putsUART("reserved");
	}
	newlineUART();

	putsUART("* READ_BL_PARTIAL: partial blocks for read allowed: ");
	putcolbUART(card->CSD.CSDVer1.READ_BL_PARTIAL, 1);
	newlineUART();

	putsUART("* WRITE_BLK_MISALIGN: write block misalignment: ");
	putcolbUART(card->CSD.CSDVer1.WRITE_BLK_MISALIGN, 1);
	newlineUART();

	putsUART("* READ_BLK_MISALIGN: read block misalignment: ");
	putcolbUART(card->CSD.CSDVer1.READ_BLK_MISALIGN, 1);
	newlineUART();

	putsUART("* DSR_IMP: DSR implemented: ");
	putcolbUART(card->CSD.CSDVer1.DSR_IMP, 1);
	newlineUART();

	putsUART("* C_SIZE: device size: ");
	putcolbUART(card->CSD.CSDVer1.C_SIZE, 12);
	putcUART(' ');
	putiUART(card->CSD.CSDVer1.C_SIZE);
	newlineUART();
	// TODO finish size calculation

	putsUART("* VDD_R_CURR_MIN: max. read current @ VDD min: ");
	putcolbUART(card->CSD.CSDVer1.VDD_R_CURR_MIN, 3);
	putcUART(' ');
	putsUART(CSD_VDD_CURR_MIN_Current[card->CSD.CSDVer1.VDD_R_CURR_MIN]);
	newlineUART();

	putsUART("* VDD_R_CURR_MAX: max. read current @ VDD max: ");
	putcolbUART(card->CSD.CSDVer1.VDD_R_CURR_MAX, 3);
	putcUART(' ');
	putsUART(CSD_VDD_CURR_MAX_Current[card->CSD.CSDVer1.VDD_R_CURR_MAX]);
	newlineUART();

	putsUART("* VDD_W_CURR_MIN: max. write current @ VDD min: ");
	putcolbUART(card->CSD.CSDVer1.VDD_W_CURR_MIN, 3);
	putcUART(' ');
	putsUART(CSD_VDD_CURR_MIN_Current[card->CSD.CSDVer1.VDD_W_CURR_MIN]);
	newlineUART();

	putsUART("* VDD_W_CURR_MAX: max. write current @ VDD max: ");
	putcolbUART(card->CSD.CSDVer1.VDD_W_CURR_MAX, 3);
	putcUART(' ');
	putsUART(CSD_VDD_CURR_MAX_Current[card->CSD.CSDVer1.VDD_W_CURR_MAX]);
	newlineUART();

	putsUART("* C_SIZE_MULT: device size multiplier: ");
	putcolbUART(card->CSD.CSDVer1.C_SIZE_MULT, 3);
	putcUART(' ');
	putiUART(card->CSD.CSDVer1.C_SIZE_MULT);
	newlineUART();
	// TODO finish size calculation

	putsUART("* ERASE_BLK_EN: erase single block enable: ");
	putcolbUART(card->CSD.CSDVer1.ERASE_BLK_EN, 1);
	newlineUART();

	putsUART("* SECTOR_SIZE: erase sector size: ");
	putcolbUART(card->CSD.CSDVer1.SECTOR_SIZE, 7);
	putcUART(' ');
	putiUART(card->CSD.CSDVer1.SECTOR_SIZE + 1);
	putsUART(" blocks");
	newlineUART();

	putsUART("* WP_GRP_SIZE: write protect group size: ");
	putcolbUART(card->CSD.CSDVer1.WP_GRP_SIZE, 7);
	putcUART(' ');
	putiUART(card->CSD.CSDVer1.WP_GRP_SIZE + 1);
	putsUART(" erase sectors");
	newlineUART();

	putsUART("* WP_GRP_ENABLE: write protect group enable: ");
	putcolbUART(card->CSD.CSDVer1.WP_GRP_ENABLE, 1);
	newlineUART();

	putsUART("* R2W_FACTOR: write speed factor: ");
	putcolbUART(card->CSD.CSDVer1.R2W_FACTOR, 3);
	putcUART(' ');
	if (card->CSD.CSDVer1.R2W_FACTOR <= 5) {
		putiUART((int)0b1 << card->CSD.CSDVer1.R2W_FACTOR);
	} else {
		putsUART("reserved");
	}
	newlineUART();

	putsUART("* WRITE_BL_LEN: max. write block length: ");
	putcolbUART(card->CSD.CSDVer1.WRITE_BL_LEN, 4);
	putcUART(' ');
	if (card->CSD.CSDVer1.WRITE_BL_LEN >= 9 && card->CSD.CSDVer1.WRITE_BL_LEN <= 11) {
		putiUART((int)0b1 << card->CSD.CSDVer1.WRITE_BL_LEN);
	} else {
		putsUART("reserved");
	}
	newlineUART();

	putsUART("* WRITE_BL_PARTIAL: partial blocks for write allowed: ");
	putcolbUART(card->CSD.CSDVer1.WRITE_BL_PARTIAL, 1);
	newlineUART();

	putsUART("* FILE_FORMAT_GRP: File format group: ");
	putcolbUART(card->CSD.CSDVer1.FILE_FORMAT_GRP, 1);
	newlineUART();

	putsUART("* COPY: copy flag (OTP): ");
	putcolbUART(card->CSD.CSDVer1.COPY, 1);
	newlineUART();

	putsUART("* PERM_WRITE_PROTECT: permanent write protection: ");
	putcolbUART(card->CSD.CSDVer1.PERM_WRITE_PROTECT, 1);
	newlineUART();

	putsUART("* TMP_WRITE_PROTECT: temporary write protection: ");
	putcolbUART(card->CSD.CSDVer1.TMP_WRITE_PROTECT, 1);
	newlineUART();

	putsUART("* FILE_FORMAT: File format: ");
	putcolbUART(card->CSD.CSDVer1.FILE_FORMAT, 2);
	putcUART(' ');
	newlineUART();
	putsUART(CSD_FILE_FORMAT_Type[card->CSD.CSDVer1.FILE_FORMAT_GRP][card->CSD.CSDVer1.FILE_FORMAT]);
	newlineUART();

	unsigned long MULT = 1 << (card->CSD.CSDVer1.C_SIZE_MULT+2);
	unsigned long BLOCKNR = (card->CSD.CSDVer1.C_SIZE + 1) * MULT;
	unsigned long BLOCK_LEN = 1 << card->CSD.CSDVer1.READ_BL_LEN;
	unsigned long capacity = BLOCKNR * BLOCK_LEN;

	putsUART("* MULT ");	putulUART(MULT);	newlineUART();
	putsUART("* BLOCKNR ");	putulUART(BLOCKNR);	newlineUART();
	putsUART("* BLOCK_LEN ");	putulUART(BLOCK_LEN);	newlineUART();
	putsUART("* capacity ");	putulUART(capacity);	newlineUART();
}
