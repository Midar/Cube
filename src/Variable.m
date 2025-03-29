#import "Variable.h"

#include "cube.h"

@implementation Variable
+ (instancetype)variableWithName: (OFString *)name
                             min: (int)min
                             max: (int)max
                         storage: (int *)storage
                        function: (void (*__cdecl)())function
                       persisted: (bool)persisted
{
	return [[self alloc] initWithName: name
	                              min: min
	                              max: max
	                          storage: storage
	                         function: function
	                        persisted: persisted];
}

- (instancetype)initWithName: (OFString *)name
                         min: (int)min
                         max: (int)max
                     storage: (int *)storage
                    function: (void (*__cdecl)())function
                   persisted: (bool)persisted
{
	self = [super initWithName: name];

	_min = min;
	_max = max;
	_storage = storage;
	_function = function;
	_persisted = persisted;

	return self;
}

- (void)printValue
{
	conoutf(@"%@ = %d", self.name, *_storage);
}

- (void)setValue: (int)value
{
	bool outOfRange = false;

	if (_min > _max) {
		conoutf(@"variable is read-only");
		return;
	}

	if (value < _min) {
		value = _min;
		outOfRange = true;
	}

	if (value > _max) {
		value = _max;
		outOfRange = true;
	}

	if (outOfRange)
		conoutf(@"valid range for %@ is %d..%d", self.name, _min, _max);

	*_storage = value;

	if (_function != NULL)
		// call trigger function if available
		_function();
}
@end
