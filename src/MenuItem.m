#import "MenuItem.h"

@implementation MenuItem
+ (instancetype)itemWithText: (OFString *)text action: (OFString *)action
{
	return [[self alloc] initWithText: text action: action];
}

- (instancetype)initWithText: (OFString *)text action: (OFString *)action
{
	self = [super init];

	_text = [text copy];
	_action = [action copy];

	return self;
}

- (OFComparisonResult)compare: (id)otherObject
{
	if (![otherObject isKindOfClass: MenuItem.class])
		@throw [OFInvalidArgumentException exception];

	int x, y;
	@try {
		OFString *text = _text;
		size_t pos = [text rangeOfString: @"\t"].location;
		if (pos != OFNotFound)
			text = [text substringToIndex: pos];

		x = text.intValue;
	} @catch (OFInvalidFormatException *e) {
		x = 0;
	} @catch (OFOutOfRangeException *e) {
		x = 0;
	}

	MenuItem *otherItem = otherObject;
	@try {
		OFString *text = otherItem.text;
		size_t pos = [text rangeOfString: @"\t"].location;
		if (pos != OFNotFound)
			text = [text substringToIndex: pos];

		y = text.intValue;
	} @catch (OFInvalidFormatException *e) {
		y = 0;
	} @catch (OFOutOfRangeException *e) {
		y = 0;
	}

	if (x > y)
		return OFOrderedAscending;
	if (x < y)
		return OFOrderedDescending;

	return OFOrderedSame;
}
@end
