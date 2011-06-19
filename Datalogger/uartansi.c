#include "uart.h"
#include "uartansi.h"

/**
 * Puts the Control Sequence Introducer (CSI) onto the UART.
 */
void ANSI_PutCSI() {
#ifdef ANSI_USE_SINGLE_CSI
	putcUART(ANSI_CSI);
#else
	putcUART(ANSI_ESC);
	putcUART('[');
#endif
}

void ANSI_Command( char cmd ) {
	ANSI_PutCSI();
	putcUART(cmd);
}

void ANSI_Command1( char arg, char cmd ) {
	ANSI_PutCSI();
	putcUART(arg);
	putcUART(cmd);
}

void ANSI_Command1s( char* arg, char cmd ) {
	ANSI_PutCSI();
	putsUART(arg);
	putcUART(cmd);
}

void ANSI_SGR( char code ) {
	ANSI_PutCSI();
	putcUART(code);
	putcUART(ANSI_SEQ_SGR);
}

void ANSI_SetColor( char colorCode ) {
	ANSI_PutCSI();
	putcUART('3');
	putcUART(colorCode);
	putcUART(ANSI_SEQ_SGR);
}
