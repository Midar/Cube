#import "OFString+Cube.h"

#include "cube.h"

@implementation OFString (Cube)
- (int)cube_intValue
{
	@try {
		return self.intValue;
	} @catch (OFInvalidFormatException *e) {
		conoutf(@"invalid value: %@", self);
		return 0;
	} @catch (OFOutOfRangeException *e) {
		conoutf(@"invalid value: %@", self);
		return 0;
	}
}

- (int)cube_intValueWithBase: (unsigned char)base
{
	@try {
		return [self intValueWithBase: base];
	} @catch (OFInvalidFormatException *e) {
		conoutf(@"invalid value: %@", self);
		return 0;
	} @catch (OFOutOfRangeException *e) {
		conoutf(@"invalid value: %@", self);
		return 0;
	}
}
@end
