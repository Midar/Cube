#import "Identifier.h"

// contains ALL vars/commands/aliases
static OFMutableDictionary<OFString *, __kindof Identifier *> *identifiers;

@implementation Identifier
+ (void)initialize
{
	if (self == Identifier.class)
		identifiers = [[OFMutableDictionary alloc] init];
}

+ (OFMutableDictionary<OFString *, __kindof Identifier *> *)identifiers
{
	return identifiers;
}

- (instancetype)initWithName:(OFString *)name
{
	self = [super init];

	_name = [name copy];

	return self;
}
@end
