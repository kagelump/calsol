#include "types.h"

/*
 * Function Prototypes
 */

void SD_SPI_Init();
inline void SD_SPI_Open();
inline void SD_SPI_Close();
inline uint8_t SD_SPI_Transfer(uint8_t data);
