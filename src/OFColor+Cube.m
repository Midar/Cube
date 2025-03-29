#include "cube.h"

#import "OFColor+Cube.h"

@implementation OFColor (Cube)
- (void)cube_setAsGLColor
{
	float red, green, blue, alpha;
	[self getRed:&red green:&green blue:&blue alpha:&alpha];
	glColor4f(red, green, blue, alpha);
}
@end
