#define FAT32_DEBUG_UART
#define FAT32_DEBUG_UART_DATA
#define FAT32_DEBUG_UART_SPAM

#ifdef FAT32_DEBUG_UART
	#include "uart.h"
	#include "uartansi.h"
	#include <stdio.h>
	extern char DBG_buffer[128];
	extern char next;
	#define STR_HELPER(x) #x
	#define STR(x) STR_HELPER(x)

	#define DBG_printf(f, ...)		if (next) {																				\
										UART_DMA_WriteBlockingS("\23336m[- Info]\23337m " __FILE__ " " STR(__LINE__) ": ");	\
										next = 0;																			\
									} else {																				\
										UART_DMA_WriteBlockingS("\23336m[| Info]\23337m " __FILE__ " " STR(__LINE__) ": ");	\
										next = 1;																			\
									}																						\
									sprintf(DBG_buffer, f, ## __VA_ARGS__);													\
									UART_DMA_WriteBlockingS(DBG_buffer);													\
									UART_DMA_WriteBlockingS("\r\n");
	#define DBG_ERR_printf(f, ...)	if (next){																				\
										UART_DMA_WriteBlockingS("\23331m[- Err ]\23337m " __FILE__ " " STR(__LINE__) ": ");	\
										next = 0;																			\
									} else {																				\
										UART_DMA_WriteBlockingS("\23331m[| Err ]\23337m " __FILE__ " " STR(__LINE__) ": ");	\
										next = 1;																			\
									}																						\
									sprintf(DBG_buffer, f, ## __VA_ARGS__);													\
									UART_DMA_WriteBlockingS(DBG_buffer);													\
									UART_DMA_WriteBlockingS("\r\n");
	#ifdef FAT32_DEBUG_UART_DATA
	#define DBG_DATA_printf(f, ...)	if (next){																				\
										UART_DMA_WriteBlockingS("\23333m[- Data]\23337m " __FILE__ " " STR(__LINE__) ": ");	\
										next = 0;																			\
									} else {																				\
										UART_DMA_WriteBlockingS("\23333m[| Data]\23337m " __FILE__ " " STR(__LINE__) ": ");	\
										next = 1;																			\
									}																						\
									sprintf(DBG_buffer, f, ## __VA_ARGS__);													\
									UART_DMA_WriteBlockingS(DBG_buffer);													\
									UART_DMA_WriteBlockingS("\r\n");
	#else
		#define DBG_DATA_printf(f, ...)
	#endif
	#ifdef FAT32_DEBUG_UART_SPAM
	#define DBG_SPAM_printf(f, ...)	if (next){																				\
										UART_DMA_WriteBlockingS("\23333m[- Data]\23337m " __FILE__ " " STR(__LINE__) ": ");	\
										next = 0;																			\
									} else {																				\
										UART_DMA_WriteBlockingS("\23333m[| Data]\23337m " __FILE__ " " STR(__LINE__) ": ");	\
										next = 1;																			\
									}																						\
									sprintf(DBG_buffer, f, ## __VA_ARGS__);												\
									UART_DMA_WriteBlockingS(DBG_buffer);												\
									UART_DMA_WriteBlockingS("\r\n");
	#else
		#define DBG_SPAM_printf(f, ...)
	#endif
#else
	#define DBG_printf(f, ...)
	#define DBG_ERR_printf(f, ...)
	#define DBG_DATA_printf(f, ...)
	#define DBG_SPAM_printf(f, ...)
#endif
