/*
 * File:   sd-spi-dma.h
 * Author: Ducky
 *
 * Created on March 22, 2011, 10:46 PM
 */

void SD_DMA_Init();
uint8_t* SD_DMA_GetBuffer(uint8_t bufferNum);
uint8_t SD_DMA_GetBusy();

uint8_t SD_DMA_SBR_Start(SDCard *card, fs_addr_t begin, uint8_t bufferNum);

uint8_t SD_DMA_MBW_GetIdle();
uint8_t SD_DMA_MBW_Start(SDCard *card, fs_addr_t begin);
uint8_t SD_DMA_MBW_SendBlock(uint8_t bufferNum);
uint8_t SD_DMA_MBW_End();
uint8_t SD_DMA_MBW_GetBlockStatus();
