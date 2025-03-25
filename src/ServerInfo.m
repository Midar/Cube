#import "ServerInfo.h"

#include "cube.h"

@implementation ServerInfo
+ (instancetype)infoWithName:(OFString *)name;
{
	return [[self alloc] initWithName:name];
}

- (instancetype)initWithName:(OFString *)name
{
	self = [super init];

	_name = [name copy];
	_full = @"";
	_mode = 0;
	_numplayers = 0;
	_ping = 9999;
	_protocol = 0;
	_minremain = 0;
	_map = @"";
	_sdesc = @"";
	_address.host = ENET_HOST_ANY;
	_address.port = CUBE_SERVINFO_PORT;

	return self;
}

- (OFComparisonResult)compare:(ServerInfo *)otherObject
{
	if (![otherObject isKindOfClass:ServerInfo.class])
		@throw [OFInvalidArgumentException exception];

	if (_ping > otherObject.ping)
		return OFOrderedDescending;
	if (_ping < otherObject.ping)
		return OFOrderedAscending;

	return [_name compare:otherObject.name];
}
@end
