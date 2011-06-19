#include "types.h"

#ifndef SD_SPI_H
#define SD_SPI_H

/**
 * Contains CID (Card Identifier) data for the SD Card.
 */
typedef struct {
	unsigned char MID;		//!< Manufacturer ID
	unsigned char OID[2];	//!< OEM/Application ID
	unsigned char PNM[5];	//!< Product name - this string is NOT null terminated
	unsigned char PRV;		//!< Product revision
	unsigned long PSN;		//!< Product serial number
	unsigned int MDT;		//!< Manufacturing date
} SD_CID;

/**
 * Contains CSD (Card-Specific Data) data for a Standard-capacity SD card.
 */
typedef struct {
	unsigned CSD_STRUCTURE		:2;
//	unsigned					:6;
	unsigned TAAC				:8;
	unsigned NSAC				:8;
	unsigned TRAN_SPEED			:8;
	unsigned CCC				:12;
	unsigned READ_BL_LEN		:4;
	unsigned READ_BL_PARTIAL	:1;
	unsigned WRITE_BLK_MISALIGN	:1;
	unsigned READ_BLK_MISALIGN	:1;
	unsigned DSR_IMP			:1;
//	unsigned					:2;
	unsigned C_SIZE				:12;
	unsigned VDD_R_CURR_MIN		:3;
	unsigned VDD_R_CURR_MAX		:3;
	unsigned VDD_W_CURR_MIN		:3;
	unsigned VDD_W_CURR_MAX		:3;
	unsigned C_SIZE_MULT		:3;
	unsigned ERASE_BLK_EN		:1;
	unsigned SECTOR_SIZE		:7;
	unsigned WP_GRP_SIZE		:7;
	unsigned WP_GRP_ENABLE		:1;
//	unsigned					:2;
	unsigned R2W_FACTOR			:3;
	unsigned WRITE_BL_LEN		:4;
	unsigned WRITE_BL_PARTIAL	:1;
//	unsigned					:5;
	unsigned FILE_FORMAT_GRP	:1;
	unsigned COPY				:1;
	unsigned PERM_WRITE_PROTECT	:1;
	unsigned TMP_WRITE_PROTECT	:1;
	unsigned FILE_FORMAT		:2;
	unsigned					:2;
} SD_CSD1;

extern char *CSD_TAAC_TimeUnit[8];
extern char *CSD_TAAC_TimeValue[16];
extern char *CSD_TRAN_SPEED_TransferRateUnit[8];
extern char *CSD_TRAN_SPEED_TimeValue[16];
extern char *CSD_VDD_CURR_MIN_Current[8];
extern char *CSD_VDD_CURR_MAX_Current[8];
extern char *CSD_FILE_FORMAT_Type[2][4];

/**
 * Contains the data necessary to use a SD card.
 */
typedef struct {
	uint8_t Ver2SDCard;			//!< Todo document me ??
	uint8_t CmdVer;				//!< Todo document me ??
	uint8_t SDHC;				//!< Is card SDHC?

	uint8_t ReadBlockMisalign;	//!< Does card support misaligned reads?
	uint8_t ReadBlockPartial;	//!< Does card support partial block reads?
	uint16_t ReadBlockLength;	//!< Read Block Length, set to 512 for 2GB cards.

	uint8_t WriteBlockMisalign;	//!< Does card support misaligned writes?
	uint8_t WriteBlockPartial;	//!< Does card support partial block writes?
	uint16_t WriteBlockLength;	//!< Write Block Length, set to 512 for 2GB cards.

	uint16_t ReadBlockMask;		//!< Masks to get the bits for an address within a block for reading. For example, a card with block length 512 would have this set to 0b00000001 11111111.
	uint16_t ReadBlockBits;		//!< Number of bits in ReadBlockMask

	uint16_t WriteBlockMask;	//!< Masks to get the bits for an address within a block for writing. For example, a card with block length 512 would have this set to 0b00000001 11111111.
	uint16_t WriteBlockBits;	//!< Number of bits in WriteBlockMask

	uint32_t SectorSize;		//!< Sector size in bytes.

	SD_CID CID;
	union {
		SD_CSD1		CSDVer1;
	} CSD;

	unsigned long Size;
} SDCard;

/**
 * Maximum number of times to send ACMD41 during card initialization before returning failure.
 */
#define SD_INIT_MAX_TRIES		1024

int8_t SD_SPI_Card_Init(SDCard *card);
int8_t SD_SPI_ReadCID(SDCard *card);
int8_t SD_SPI_ReadCSD(SDCard *card);

fs_length_t SD_SPI_ReadSingleBlock(SDCard *card, fs_addr_t begin, uint8_t* buffer);
fs_length_t SD_SPI_WriteSingleBlock(SDCard *card, fs_addr_t begin, uint8_t* buffer);

/*
 * Debug Tools
 */

void SD_PrintCID(SDCard *card);
void SD_PrintCSDVer1(SDCard *card);

#endif
