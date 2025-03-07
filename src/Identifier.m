#import "Identifier.h"

@implementation Identifier
- (instancetype)initWithName:(OFString *)name
{
	self = [super init];

	_name = [name copy];

	return self;
}
@end
