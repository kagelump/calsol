
#define UART_DMA_BUFFER_SIZE	96

#define UART_UMODEbits			U2MODEbits
#define UART_UBRG				U2BRG
#define UART_USTAbits			U2STAbits

#define UART_IRQSEL_VAL			0b0011111
#define UART_DMAPAD_VAL			(uint16_t)&U2TXREG

#define UART_DMACON				DMA7CON
#define UART_DMACONbits			DMA7CONbits
#define	UART_DMAREQbits			DMA7REQbits
#define UART_DMASTA				DMA7STA
#define UART_DMAPAD				DMA7PAD
#define UART_DMACNT				DMA7CNT

#define UART_DMAInterrupt		_DMA7Interrupt
#define UART_DMAIF				_DMA7IF
#define UART_DMAIE				_DMA7IE

void UART_DMA_Init();
uint16_t UART_DMA_WriteAtomicS(char* string);
uint16_t UART_DMA_WriteAtomic(char* data, uint16_t dataLen);
void UART_DMA_WriteBlockingS(char* string);
uint16_t UART_DMA_SendBlock();
