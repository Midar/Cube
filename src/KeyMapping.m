#import "KeyMapping.h"

@implementation KeyMapping
+ (instancetype)mappingWithCode: (int)code name: (OFString *)name
{
	return [[self alloc] initWithCode: code name: name];
}

- (instancetype)initWithCode: (int)code name: (OFString *)name
{
	self = [super init];

	_code = code;
	_name = [name copy];

	return self;
}
@end
