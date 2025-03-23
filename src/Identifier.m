#import "Identifier.h"

// contains ALL vars/commands/aliases
static OFMutableDictionary<OFString *, __kindof Identifier *> *identifiers;

@implementation Identifier
+ (void)initialize
{
	if (self == Identifier.class)
		identifiers = [[OFMutableDictionary alloc] init];
}

+ (void)addIdentifier:(__kindof Identifier *)identifier
{
	identifiers[identifier.name] = identifier;
}

+ (__kindof Identifier *)identifierForName:(OFString *)name
{
	return identifiers[name];
}

+ (void)enumerateIdentifiersUsingBlock:(void (^)(__kindof Identifier *))block
{
	[identifiers enumerateKeysAndObjectsUsingBlock:^(
	    OFString *name, __kindof Identifier *identifier, bool *stop) {
		block(identifier);
	}];
}

- (instancetype)initWithName:(OFString *)name
{
	self = [super init];

	_name = [name copy];

	return self;
}
@end
