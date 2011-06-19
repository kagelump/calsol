#include "hardware.h"
#include "types.h"

/**
 * The UART baud rate, in bits/sec. The BRG is calculated at compile time from this number.
 */
#define UART_BAUD		256000

// BRGH formula: ( Fcy / ( 4 * baud ) ) - 1
// BRG  formula: ( Fcy / ( 16 * baud ) ) - 1
#if (((Fcy / 4) / UART_BAUD) - 1) < 255
	#define UART_BRG	(((Fcy / 4) / UART_BAUD) - 1)
	#define UART_BRGH	1
#else
	#define UART_BRG	(((Fcy / 16) / UART_BAUD) - 1)
	#define UART_BRGH	0
#endif
//TODO Add compile-time baud error percentage check

/**
 * Buffer size to use during x to string conversions
 */
#define CONV_STR_SIZE		16

/*
 * UART Function Prototypes
 */
void UART_Init();

char getcUART();

void putcUART( char c );
void putsUART( char *buffer );
void newlineUART();
void putlineUART( char *buffer );

void putiUART( int value );
void putuiUART( unsigned int value );
void putleniUART( int value, unsigned char len );
void putlUART( long value );
void putulUART( unsigned long value );

void puthUART( int value );
void putlenhUART( int value, unsigned char len );

void putbUART( unsigned int value, unsigned char bits );
void putcolbUART( unsigned int value, unsigned char bits );
void putcolulbUART( unsigned long value, unsigned char bits );

void putbufhUART(uint8_t *buf, uint16_t len, uint8_t breakLen, uint8_t lineLen);
void putfilenameUART(uint8_t *name);
