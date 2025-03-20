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
#define rndtime()                                   \
	{                                           \
		loopi(lastmillis & 0xF) rnd(i + 1); \
	}
#define loop(v, m) for (int v = 0; v < (m); v++)
#define loopi(m) loop(i, m)
#define loopj(m) loop(j, m)
#define loopk(m) loop(k, m)
#define loopl(m) loop(l, m)

#ifndef OF_WINDOWS
# define __cdecl
#endif

#define fast_f2nat(val) ((int)(val))

extern void endianswap(void *, int, int);

#endif
