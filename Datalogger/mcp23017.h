#include "types.h"

/**
 * MCP23017 Register Addresses
 * (when IOCON.BANK=0)
 */
#define MCP23017_ADDR_IODIRA	0x00
#define MCP23017_ADDR_IODIRB	0x01
#define MCP23017_ADDR_IPOLA		0x02
#define MCP23017_ADDR_IPOLB		0x03
#define MCP23017_ADDR_GPINTENA	0x04
#define MCP23017_ADDR_GPINTENB	0x05
#define MCP23017_ADDR_DEFVALA	0x06
#define MCP23017_ADDR_DEFVALB	0x07
#define MCP23017_ADDR_INTCONA	0x08
#define MCP23017_ADDR_INTCONB	0x09
#define MCP23017_ADDR_IOCON_1	0x0A
#define MCP23017_ADDR_IOCON_2	0x0B
#define MCP23017_ADDR_GPPUA		0x0C
#define MCP23017_ADDR_GPPUB		0x0D
#define MCP23017_ADDR_INTFA		0x0E
#define MCP23017_ADDR_INTFB		0x0F
#define MCP23017_ADDR_INTCAPA	0x10
#define MCP23017_ADDR_INTCAPB	0x11
#define MCP23017_ADDR_GPIOA		0x12
#define MCP23017_ADDR_GPIOB		0x13
#define MCP23017_ADDR_OLATA		0x14
#define MCP23017_ADDR_OLATB		0x15

/**
 * I2C address of the device.
 * Last 3 bits are hardware dependent, and should be OR'd with this address.
 */
#define MCP23017_I2C_ADDR		0b0100000

/*
 * Function prototypes
 */
inline void MCP23017_I2C_Open();
inline void MCP23017_I2C_Close();
inline uint8_t MCP23017_SendControlByte(uint8_t addr, uint8_t rw);
uint8_t MCP23017_SingleRegisterWrite(uint8_t addr, uint8_t reg, uint8_t data);
uint8_t MCP23017_SingleRegisterRead(uint8_t addr, uint8_t reg, uint8_t *data);
