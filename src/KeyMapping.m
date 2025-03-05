#import "KeyMapping.h"

@implementation KeyMapping
- (instancetype)initWithCode:(int)code name:(OFString *)name
{
	self = [super init];

	_code = code;
	_name = [name copy];

	return self;
}
@end
