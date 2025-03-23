// implementation of generic tools

#include "tools.h"

///////////////////////// misc tools ///////////////////////

void
endianswap(
    void *memory, int stride, int length) // little indians as storage format
{
	if (*((char *)&stride))
		return;

	for (int w = 0; w < length; w++) {
		for (int i = 0; i < stride / 2; i++) {
			unsigned char *p = (unsigned char *)memory + w * stride;
			unsigned char t = p[i];
			p[i] = p[stride - i - 1];
			p[stride - i - 1] = t;
		}
	}
}
