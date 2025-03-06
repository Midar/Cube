#import "Menu.h"

@implementation Menu
- (instancetype)initWithName:(OFString *)name
{
	self = [super init];

	_name = [name copy];
	_items = [[OFMutableArray alloc] init];

	return self;
}
@end
