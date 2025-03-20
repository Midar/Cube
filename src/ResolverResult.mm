#import "ResolverResult.h"

@implementation ResolverResult
+ (instancetype)resultWithQuery:(OFString *)query address:(ENetAddress)address
{
	return [[self alloc] initWithQuery:query address:address];
}

- (instancetype)initWithQuery:(OFString *)query address:(ENetAddress)address
{
	self = [super init];

	_query = query;
	_address = address;

	return self;
}
@end
