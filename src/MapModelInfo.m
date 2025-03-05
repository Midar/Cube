#import "MapModelInfo.h"

@implementation MapModelInfo
- (instancetype)initWithRad:(int)rad
                          h:(int)h
                       zoff:(int)zoff
                       snap:(int)snap
                       name:(OFString *)name
{
	self = [super init];

	_rad = rad;
	_h = h;
	_zoff = zoff;
	_snap = snap;
	_name = [name copy];

	return self;
}
@end
