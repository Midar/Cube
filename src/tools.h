// generic useful stuff for any C++ program

#ifndef _TOOLS_H
#define _TOOLS_H

#ifdef __GNUC__
# define gamma __gamma
#endif

#include <math.h>

#ifdef __GNUC__
# undef gamma
#endif

#include <assert.h>
#include <limits.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#import <ObjFW/ObjFW.h>

typedef unsigned char uchar;
typedef unsigned short ushort;
typedef unsigned int uint;

#define max(a, b) (((a) > (b)) ? (a) : (b))
#define min(a, b) (((a) < (b)) ? (a) : (b))
#define rnd(max) (rand() % (max))
#define rndreset() (srand(1))
#define rndtime()                                            \
	{                                                    \
		for (int i = 0; i < (lastmillis & 0xF); i++) \
			rnd(i + 1);                          \
	}

#ifndef OF_WINDOWS
# define __cdecl
#endif

#define fast_f2nat(val) ((int)(val))

#ifdef __cplusplus
extern "C" {
#endif
extern void endianswap(void *, int, int);
#ifdef __cplusplus
}
#endif

#endif
