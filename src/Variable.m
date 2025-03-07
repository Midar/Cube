#import "Variable.h"

@implementation Variable
- (instancetype)initWithName:(OFString *)name
                         min:(int)min
                         max:(int)max
                     storage:(int *)storage
                    function:(void (*)())function
                   persisted:(bool)persisted
{
	self = [super initWithName:name];

	_min = min;
	_max = max;
	_storage = storage;
	_function = function;
	_persisted = persisted;

	return self;
}
@end
