#include "types.h"
#include "hardware.h"

// TODO automatic compile time error checking for I2C BRG

/**
 * BRG values for the I2C
 */
#define I2C_BRG_100KHZ	((Fcy/100000-Fcy/10000000)-1)
#define I2C_BRG_400KHZ	((Fcy/400000-Fcy/10000000)-1)
#define I2C_BRG_1MHZ	((Fcy/1000000-Fcy/10000000)-1)

#if (I2C_BRG_100KHZ < 2) || (I2C_BRG_400KHZ < 2) || (I2C_BRG_1MHZ < 2)
	#error "I2CxBRG register values of less than 2 are not supported"
#endif

/**
 * Number of BRG loops to wait for before timing out.
 */
#define I2C_TIMEOUT		16

/**
 * R/W bit value for a write operation.
 */
#define I2C_RW_WRITE	0
/**
 * R/W bit balue for a read operation.
 */
#define I2C_RW_READ		1

/**
 * Parameter value to send a ACK after an operation.
 */
#define I2C_SEND_ACK	0
/**
 * Parameter value to send a NACK after an operation.
 */
#define I2C_SEND_NACK	1

inline void I2C_Init();
inline uint8_t I2C_SendStart();
inline void I2C_SendRepeatedStart();
inline void I2C_SendStop();
inline uint8_t I2C_SendByte(uint8_t data);
inline uint8_t I2C_Send7BitAddress(uint8_t address, uint8_t rw);
inline uint8_t I2C_ReadByte(uint8_t nack, uint8_t *data);
