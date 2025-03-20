#import "Menu.h"

@implementation Menu
+ (instancetype)menuWithName:(OFString *)name
{
	return [[self alloc] initWithName:name];
}

- (instancetype)initWithName:(OFString *)name
{
	self = [super init];

	_name = [name copy];
	_items = [[OFMutableArray alloc] init];

	return self;
}
@end
