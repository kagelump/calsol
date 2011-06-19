#ifdef __PIC24F__
#include <p24Fxxxx.h>
#elif defined __PIC24H__
#include <p24Hxxxx.h>
#endif

#include "uart.h"
#include "uartstring.h"
#include "uartansi.h"

/**
 * Initializes the UART module, using specifications defined in uart.h.
 */
void UART_Init() {
	U1MODEbits.BRGH = UART_BRGH;
	U1MODEbits.UARTEN = 1;
	U1BRG = UART_BRG;
}

/**
 * Retrieves a character from the UART RX buffer.
 *
 * @bug Currently, it is not possible to retrieve the null character without confusion.
 * @returns Character retrieved.
 * @retval 0 if the UART RX buffer is empty.
 */
char getcUART() {
	if (U1STAbits.URXDA) {
		return U1RXREG;
	} else {
		return 0;
	}
}

/**
 * Places a character onto the UART TX buffer.
 * This may block if the UART TX buffer is full, as the function waits for an empty slot.
 * However, once the character has been placed, the UART TX buffer will empty in the background.
 *
 * @param[in] c Character to transmit
 */
void putcUART( char c ) {
	while (U1STAbits.UTXBF);	// wait until buffer not full
	U1TXREG = c;
}

/**
 * Places a string onto the UART TX buffer.
 * This basically is a wrapper call to putcUART, so same caveats apply. See documentation for putcUART.
 *
 * @param buffer Pointer to the null-terminated string to transmit.
 */
void putsUART( char *buffer )
{
	while(*buffer)
	{
		putcUART(*buffer);
		buffer++;
	}
}

/**
 * Places a newline (\\r \\n) onto the UART TX buffer.
 * This basically is a wrapper call to putcUART, so same caveats apply. See documentation for putcUART.
 */
void newlineUART()
{
	putcUART('\r');
	putcUART('\n');
}

/**
 * Places a line of text into the UART TX buffer.
 * This is basically a wrapper call to putsUART and newlineUART, so same caveats apply.
 *
 * @param buffer Pointer to the null-terminated string to transmit.
 */
void putlineUART( char *buffer )
{
	putsUART(buffer);
	newlineUART();
}

/*
 * Put Number Operations
 */

/**
 * Puts the decimal string representation of signed integer @a value onto the UART TX buffer.
 *
 * @param value Signed integer to transmit.
 */
void putiUART( int value )
{
	char buffer[CONV_STR_SIZE];
	itoa(value, buffer);
	putsUART(buffer);
}

/**
 * Puts the decimal string representation of unsigned integer @a value onto the UART TX buffer.
 *
 * @param value Unigned integer to transmit.
 */
void putuiUART( unsigned int value )
{
	char buffer[CONV_STR_SIZE];
	uitoa(value, buffer);
	putsUART(buffer);
}

/**
 * Puts the decimal string representation of signed long @a value onto the UART TX buffer.
 *
 * @param value Signed long to transmit.
 */
void putlUART( long value )
{
	char buffer[CONV_STR_SIZE];
	ltoa(value, buffer);
	putsUART(buffer);
}

/**
 * Puts the decimal string representation of unsigned long @a value onto the UART TX buffer.
 *
 * @param value Unsigned long to transmit.
 */
void putulUART( unsigned long value )
{
	char buffer[CONV_STR_SIZE];
	ultoa(value, buffer);
	putsUART(buffer);
}

/**
 * Puts the decimal string representation of signed integer @a value onto the UART TX buffer.
 *
 * @param value Signed integer to transmit.
 * @param len Minimum length of the string transmitted.
 *		Output string will be padded with 0's to meet this condition.
 */
void putleniUART( int value, unsigned char len )
{
	char buffer[CONV_STR_SIZE];
	lenitoa(value, buffer, len);
	putsUART(buffer);
}

/**
 * Puts the hexadecimal string representation of signed integer @a value onto the UART TX buffer.
 *
 * @param value Signed integer to transmit.
 */
void puthUART( int value )
{
	char buffer[CONV_STR_SIZE];
	htoa(value, buffer);
	putsUART(buffer);
}

/**
 * Puts the hexadecimal string representation of signed integer @a value onto the UART TX buffer.
 *
 * @param value Signed integer to transmit.
 * @param len Minimum length of the string transmitted.
 *		Output string will be padded with 0's to meet this condition.
 */
void putlenhUART( int value, unsigned char len )
{
	char buffer[CONV_STR_SIZE];
	lenhtoa(value, buffer, len);
	putsUART(buffer);
}

/**
 * Puts the binary string representation of the lowest @a bits bits of
 *		unsigned integer @a value onto the UART TX buffer.
 *
 * @param value Unsigned integer to transmit.
 * @param bits Number of bits to transmit.
 */
void putbUART( unsigned int value, unsigned char bits )
{
	char i;

	for (i=(bits-1); i>=0; i--)
	{
		putcUART( ((value & ((unsigned int)1 << i)) != 0) + '0' );
	}
}

/**
 * Puts the binary string representation of the lowest @a bits bits of
 *		unsigned integer @a value onto the UART TX buffer
 * This also colors the bits, with 1s being cyan and 0s bing blue.
 * Text is restored to white afterwards.
 *
 * @param value Unsigned integer to transmit.
 * @param bits Number of bits to transmit.
 */
void putcolbUART( unsigned int value, unsigned char bits )
{
	char i;
	char lastBit = 255;

	for (i=(bits-1); i>=0; i--)
	{
		if ((value & ((unsigned int)1 << i)) != 0)
		{
			if (lastBit != 1) {
				ANSI_SetColor(ANSI_COLOR_CYAN);
				lastBit = 1;
			}
			putcUART('1');
		}
		else
		{
			if (lastBit != 0) {
				ANSI_SetColor(ANSI_COLOR_BLUE);
				lastBit = 0;
			}
			putcUART('0');
		}
	}
	ANSI_SetColor(ANSI_COLOR_WHITE);
}

/**
 * Puts the binary string representation of the lowest @a bits bits of
 *		unsigned long @a value onto the UART TX buffer
 * This also colors the bits, with 1s being cyan and 0s bing blue.
 * Text is restored to white afterwards.
 *
 * @param value Unsigned long to transmit.
 * @param bits Number of bits to transmit.
 */
void putcolulbUART( unsigned long value, unsigned char bits )
{
	char i;

	for (i=(bits-1); i>=0; i--)
	{
		if ((value & ((unsigned long)1 << i)) != 0)
		{
			ANSI_SetColor(ANSI_COLOR_CYAN);
			putcUART('1');
		}
		else
		{
			ANSI_SetColor(ANSI_COLOR_BLUE);
			putcUART('0');
		}
	}
	ANSI_SetColor(ANSI_COLOR_WHITE);
}

void putbufhUART(uint8_t *buf, uint16_t len, uint8_t breakLen, uint8_t lineLen) {
	uint8_t *lineStart = buf;
	char buffer[CONV_STR_SIZE];
	int i = 0;

	lenhtoa(0, buffer, 4);
	putsUART(buffer);
	putsUART(" - ");

	for (i=0;i<len;i++) {
		lenhtoa(*(unsigned char*)buf, buffer, 2);
		putsUART(buffer);
		putcUART(' ');
		buf++;

		if ((i + 1) % lineLen == 0) {
			putsUART(" - ");
			while (lineStart < buf) {
				if (*lineStart >= 32 && *lineStart <= 127) {
					putcUART(*lineStart);
				} else {
					putcUART('.');
				}
				lineStart++;
			}
			newlineUART();
			if (i+1 < len) {
				lenhtoa(i+1, buffer, 4);
				putsUART(buffer);
				putsUART(" - ");
			}
		} else if ((i + 1) % breakLen == 0) {
			putcUART(' ');
		}
	}
}

void putfilenameUART(uint8_t *name) {
	uint8_t i=0;
	for (i=0;i<8;i++) {
		putcUART(name[i]);
	}
	putcUART('.');
	for (i=8;i<11;i++) {
		putcUART(name[i]);
	}
}
