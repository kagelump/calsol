/*
 * File:   uartstring.c
 * Author: Ducky, portions of code lifted from Wikipedia
 *
 * This file contains functions for converting numbers to strings.
 *
 * @bug All functions do not check string length, so buffer overruns are possible.
 */
#include <string.h>

#include "uart.h"
#include "uartstring.h"

/**
 * Converts signed integer @a n to decimal ASCII characters in @a s.
 *
 * @param[in] n Signed integer to convert.
 * @param[out] s Pointer to location to store string.
 * @returns Pointer to output string.
 */
char* itoa(int n, char s[])
{
    int i, sign, c, j;

    if ((sign = n) < 0)			// record sign
        n = -n;					// make n positive

    i = 0;
    do {						// generate digits in reverse order
        s[i++] = n % 10 + '0';	// get next digit
    } while ((n /= 10) > 0);	// delete it

    if (sign < 0)
        s[i++] = '-';
    s[i] = '\0';

	// reverse the string
    for (i = 0, j = strlen(s)-1; i<j; i++, j--) {
        c = s[i];
        s[i] = s[j];
        s[j] = c;
    }

	// this allows it to be used as a string argument
	return s;
}

/**
 * Converts unsigned integer @a n to decimal ASCII characters in @a s.
 *
 * @param[in] n Unsigned integer to convert.
 * @param[out] s Pointer to location to store string.
 * @returns Pointer to output string.
 */
char* uitoa(unsigned int n, char s[])
{
    int i, c, j;

    i = 0;
    do {						// generate digits in reverse order
        s[i++] = n % 10 + '0';	// get next digit
    } while ((n /= 10) > 0);	// delete it

    s[i] = '\0';

	// reverse the string
    for (i = 0, j = strlen(s)-1; i<j; i++, j--) {
        c = s[i];
        s[i] = s[j];
        s[j] = c;
    }

	// this allows it to be used as a string argument
	return s;
}

/**
 * Converts signed integer @a n to decimal ASCII characters in @a s.
 * Output string will have a minimum length @a len.
 *
 * @param[in] n Signed integer to convert.
 * @param[out] s Pointer to location to store string.
 * @param[in] len Minimum length of output string.
 *		Output string will be padded with 0's to meet this condition.
 * @returns Pointer to output string.
 */
char* lenitoa(int n, char s[], unsigned char len)
{
    int i, sign, c, j;

    if ((sign = n) < 0)			// record sign
        n = -n;					// make n positive

    i = 0;
    do {						// generate digits in reverse order
        s[i++] = n % 10 + '0';	// get next digit
    } while ((n /= 10) > 0);	// delete it

    if (sign < 0)
	{
		while (i < len - 1)	{
			s[i++] = '0';
		}
        s[i++] = '-';
	}	else	{
		while (i < len)	{
			s[i++] = '0';
		}
	}
    s[i] = '\0';

	// reverse the string
    for (i = 0, j = strlen(s)-1; i<j; i++, j--) {
        c = s[i];
        s[i] = s[j];
        s[j] = c;
    }

	// this allows it to be used as a string argument
	return s;
}

/**
 * Converts signed long @a n to decimal ASCII characters in @a s.
 *
 * @param[in] n Signed long to convert.
 * @param[out] s Pointer to location to store string.
 * @returns Pointer to output string.
 */
char* ltoa(long n, char s[])
{
    int i, c, j;
	long sign;

    if ((sign = n) < 0)			// record sign
        n = -n;					// make n positive

    i = 0;
    do {						// generate digits in reverse order
        s[i++] = n % 10 + '0';	// get next digit
    } while ((n /= 10) > 0);	// delete it

    if (sign < 0)
        s[i++] = '-';
    s[i] = '\0';

	// reverse the string
    for (i = 0, j = strlen(s)-1; i<j; i++, j--) {
        c = s[i];
        s[i] = s[j];
        s[j] = c;
    }

	// this allows it to be used as a string argument
	return s;
}

/**
 * Converts unsigned long @a n to decimal ASCII characters in @a s.
 *
 * @param[in] n Unsigned long to convert.
 * @param[out] s Pointer to location to store string.
 * @returns Pointer to output string.
 */
char* ultoa(unsigned long n, char s[])
{
    int i, c, j;

    i = 0;
    do {						// generate digits in reverse order
        s[i++] = n % 10 + '0';	// get next digit
    } while ((n /= 10) > 0);	// delete it

    s[i] = '\0';

	// reverse the string
    for (i = 0, j = strlen(s)-1; i<j; i++, j--) {
        c = s[i];
        s[i] = s[j];
        s[j] = c;
    }

	// this allows it to be used as a string argument
	return s;
}

/**
 * Converts signed integer @a n to hexadecimal ASCII characters in @a s.
 *
 * @param[in] n Signed integer to convert.
 * @param[out] s Pointer to location to store string.
 * @returns Pointer to output string.
 */
char* htoa(int n, char s[])
{
    int i, sign, c, j;

    if ((sign = n) < 0)			// record sign
        n = -n;					// make n positive

    i = 0;
    do {						// generate digits in reverse order
        s[i] = n % 16;		// get next digit
		if (s[i] < 10)
			s[i] += '0';
		else
			s[i] += 'A' - 10;
		i++;
    } while ((n /= 16) > 0);	// delete it

    if (sign < 0)
        s[i++] = '-';
    s[i] = '\0';

	// reverse the string
    for (i = 0, j = strlen(s)-1; i<j; i++, j--) {
        c = s[i];
        s[i] = s[j];
        s[j] = c;
    }

	// this allows it to be used as a string argument
	return s;
}

/**
 * Converts signed integer @a n to hexadecimal ASCII characters in @a s.
 * Output string will have a minimum length @a len.
 *
 * @param[in] n Signed integer to convert.
 * @param[out] s Pointer to location to store string.
 * @param[in] len Minimum length of output string.
 *		Output string will be padded with 0's to meet this condition.
 * @returns Pointer to output string.
 */
char* lenhtoa(int n, char s[], unsigned char len)
{
    int i, sign, c, j;

    if ((sign = n) < 0)			// record sign
        n = -n;					// make n positive

    i = 0;
    do {						// generate digits in reverse order
        s[i] = n % 16;		// get next digit
		if (s[i] < 10)
			s[i] += '0';
		else
			s[i] += 'A' - 10;
		i++;
    } while ((n /= 16) > 0);	// delete it

    if (sign < 0)
	{
		while (i < len - 1)	{
			s[i++] = '0';
		}
        s[i++] = '-';
	}	else	{
		while (i < len)	{
			s[i++] = '0';
		}
	}
    s[i] = '\0';

	// reverse the string
    for (i = 0, j = strlen(s)-1; i<j; i++, j--) {
        c = s[i];
        s[i] = s[j];
        s[j] = c;
    }

	// this allows it to be used as a string argument
	return s;
}
