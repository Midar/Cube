#import "Alias.h"

@implementation Alias
+ (instancetype)aliasWithName: (OFString *)name
                       action: (OFString *)action
                    persisted: (bool)persisted;
{
	return [[self alloc] initWithName: name
	                           action: action
	                        persisted: persisted];
}

- (instancetype)initWithName: (OFString *)name
                      action: (OFString *)action
                   persisted: (bool)persisted
{
	self = [super initWithName: name];

	_action = [action copy];
	_persisted = persisted;

	return self;
}
@end
