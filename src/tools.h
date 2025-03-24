// generic useful stuff for any C++ program

#ifndef _TOOLS_H
#define _TOOLS_H

#include <math.h>

#include <assert.h>
#include <limits.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#import <ObjFW/ObjFW.h>

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

#ifdef __cplusplus
extern "C" {
#endif
extern void endianswap(void *, int, int);
#ifdef __cplusplus
}
#endif

#endif
