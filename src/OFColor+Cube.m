#include "cube.h"

#import "OFColor+Cube.h"

@implementation OFColor (Cube)
- (void)cube_setAsGLColor
{
	float red, green, blue, alpha;

	[self getRed: &red green: &green blue: &blue alpha: &alpha];

	glColor4f(red, green, blue, alpha);
}

- (void)cube_setAsGLClearColor
{
	float red, green, blue, alpha;

	[self getRed: &red green: &green blue: &blue alpha: &alpha];

	glClearColor(red, green, blue, alpha);
}

- (void)cube_setAsGLFogColor
{
	float color[4];

	[self getRed: &color[0]
	       green: &color[1]
		blue: &color[2]
	       alpha: &color[3]];

	glFogfv(GL_FOG_COLOR, color);
}
@end
