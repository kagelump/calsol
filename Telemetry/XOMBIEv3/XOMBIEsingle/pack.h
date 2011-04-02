#ifndef _PACK_H_
#define _PACK_H_

#include <stdint.h>

uint8_t encodeFirstByte(uint32_t a);
void decodeFirstByte(uint8_t* src, uint32_t* p32_dest);
uint8_t encodeSecondByte(uint32_t a);
void decodeSecondByte(uint8_t* src, uint32_t* p32_dest);
uint8_t encodeThirdByte(uint32_t a);
void decodeThirdByte(uint8_t* src, uint32_t* p32_dest);
uint8_t encodeFourthByte(uint32_t a);
void decodeFourthByte(uint8_t* src, uint32_t* p32_dest);

/**
 *  Modifies the dest array to encode the int src
 *  @param src   - The data to be encoded. Assumes 32-bit ints
 *  @param dest - The array to store the encoded data. 
 *                Expects room for at least 4 bytes.
 */ 
void encode(uint32_t src, uint8_t* dest);

/**
 *  Modifiers the dest pointer to decode the dest array
 *  @param src   - The pointer to the data to decode. Must have
 *                 at least 4 bytes of data.
 *  @param dest  - A pointer to the memory location that will
 *                 contain the decoded message
 */
void decode(uint8_t* src, uint32_t* dest);

#endif
