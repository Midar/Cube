#import "ConsoleLine.h"

@implementation ConsoleLine
+ (instancetype)lineWithText: (OFString *)text outtime: (int)outtime
{
	return [[self alloc] initWithText: text outtime: outtime];
}

- (instancetype)initWithText: (OFString *)text outtime: (int)outtime
{
	self = [super init];

	_text = [text copy];
	_outtime = outtime;

	return self;
}
@end
