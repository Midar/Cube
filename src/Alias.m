#import "Alias.h"

@implementation Alias
- (instancetype)initWithName:(OFString *)name
                      action:(OFString *)action
                   persisted:(bool)persisted
{
	self = [super initWithName:name];

	_action = [action copy];
	_persisted = persisted;

	return self;
}
@end
