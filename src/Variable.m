#import "Variable.h"

#include "cube.h"

@implementation Variable
{
	int *_storage;
}

+ (instancetype)variableWithName: (OFString *)name
			     min: (int)min
			     max: (int)max
			 storage: (int *)storage
		       persisted: (bool)persisted
			  getter: (int (^)(void))getter
			  setter: (void (^)(int))setter
{
	return [[self alloc] initWithName: name
				      min: min
				      max: max
				  storage: storage
				persisted: persisted
				   getter: getter
				   setter: setter];
}

- (instancetype)initWithName: (OFString *)name
			 min: (int)min
			 max: (int)max
		     storage: (int *)storage
		   persisted: (bool)persisted
		      getter: (int (^)(void))getter
		      setter: (void (^)(int))setter
{
	self = [super initWithName: name];

	_min = min;
	_max = max;
	_storage = storage;
	_persisted = persisted;
	_getter = [getter copy];
	_setter = [setter copy];

	return self;
}

- (void)printValue
{
	conoutf(@"%@ = %d", self.name, self.value);
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

	if (outOfRange) {
		conoutf(@"valid range for %@ is %d..%d", self.name, _min, _max);
		return;
	}

	if (_setter != NULL)
		_setter(value);
	else
		*_storage = value;
}

- (int)value
{
	if (_getter != NULL)
		return _getter();
	else
		return *_storage;
}
@end
