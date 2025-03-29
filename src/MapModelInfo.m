#import "MapModelInfo.h"

@implementation MapModelInfo
+ (instancetype)infoWithRad: (int)rad
			  h: (int)h
		       zoff: (int)zoff
		       snap: (int)snap
		       name: (OFString *)name
{
	return [[self alloc] initWithRad: rad
				       h: h
				    zoff: zoff
				    snap: snap
				    name: name];
}

- (instancetype)initWithRad: (int)rad
			  h: (int)h
		       zoff: (int)zoff
		       snap: (int)snap
		       name: (OFString *)name
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
