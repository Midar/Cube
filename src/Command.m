#import "Command.h"
#import "OFString+Cube.h"

#include "cube.h"

static OFArray<OFString *> *
padArguments(OFArray<OFString *> *arguments, size_t count)
{
	OFMutableArray<OFString *> *copy;

	if (arguments.count >= count)
		return arguments;

	copy = [arguments mutableCopy];
	while (copy.count < count)
		[copy addObject: @""];

	[copy makeImmutable];
	return copy;
}

@implementation Command
{
	id _block;
}

+ (instancetype)commandWithName: (OFString *)name
		 argumentsTypes: (int)argumentsTypes
			  block: (id)block
{
	return [[self alloc] initWithName: name
			   argumentsTypes: argumentsTypes
				    block: block];
}

- (instancetype)initWithName: (OFString *)name
	      argumentsTypes: (int)argumentsTypes
		       block: (id)block
{
	self = [super initWithName: name];

	_argumentsTypes = argumentsTypes;
	_block = block;

	return self;
}

- (int)callWithArguments: (OFArray<OFString *> *)arguments isDown: (bool)isDown
{
	switch (_argumentsTypes) {
	case ARG_1INT:
		if (isDown) {
			arguments = padArguments(arguments, 2);
			((void (^)(int))_block)(
			    [arguments[1] cube_intValueWithBase: 0]);
		}
		break;
	case ARG_2INT:
		if (isDown) {
			arguments = padArguments(arguments, 3);
			((void (^)(int, int))_block)(
			    [arguments[1] cube_intValueWithBase: 0],
			    [arguments[2] cube_intValueWithBase: 0]);
		}
		break;
	case ARG_3INT:
		if (isDown) {
			arguments = padArguments(arguments, 4);
			((void (^)(int, int, int))_block)(
			    [arguments[1] cube_intValueWithBase: 0],
			    [arguments[2] cube_intValueWithBase: 0],
			    [arguments[3] cube_intValueWithBase: 0]);
		}
		break;
	case ARG_4INT:
		if (isDown) {
			arguments = padArguments(arguments, 5);
			((void (^)(int, int, int, int))_block)(
			    [arguments[1] cube_intValueWithBase: 0],
			    [arguments[2] cube_intValueWithBase: 0],
			    [arguments[3] cube_intValueWithBase: 0],
			    [arguments[4] cube_intValueWithBase: 0]);
		}
		break;
	case ARG_NONE:
		if (isDown)
			((void (^)())_block)();
		break;
	case ARG_1STR:
		if (isDown) {
			arguments = padArguments(arguments, 2);
			((void (^)(OFString *))_block)(arguments[1]);
		}
		break;
	case ARG_2STR:
		if (isDown) {
			arguments = padArguments(arguments, 3);
			((void (^)(OFString *, OFString *))_block)(
			    arguments[1], arguments[2]);
		}
		break;
	case ARG_3STR:
		if (isDown) {
			arguments = padArguments(arguments, 4);
			((void (^)(OFString *, OFString *, OFString *))_block)(
			    arguments[1], arguments[2], arguments[3]);
		}
		break;
	case ARG_5STR:
		if (isDown) {
			arguments = padArguments(arguments, 6);
			((void (^)(OFString *, OFString *, OFString *,
			    OFString *, OFString *))_block)(arguments[1],
			    arguments[2], arguments[3], arguments[4],
			    arguments[5]);
		}
		break;
	case ARG_DOWN:
		((void (^)(bool))_block)(isDown);
		break;
	case ARG_DWN1:
		arguments = padArguments(arguments, 2);
		((void (^)(bool, OFString *))_block)(isDown, arguments[1]);
		break;
	case ARG_1EXP:
		if (isDown) {
			arguments = padArguments(arguments, 2);
			return ((int (^)(int))_block)(
			    execute(arguments[1], isDown));
		}
		break;
	case ARG_2EXP:
		if (isDown) {
			arguments = padArguments(arguments, 3);
			return ((int (^)(int, int))_block)(
			    execute(arguments[1], isDown),
			    execute(arguments[2], isDown));
		}
		break;
	case ARG_1EST:
		if (isDown) {
			arguments = padArguments(arguments, 2);
			return ((int (^)(OFString *))_block)(arguments[1]);
		}
		break;
	case ARG_2EST:
		if (isDown) {
			arguments = padArguments(arguments, 3);
			return ((int (^)(OFString *, OFString *))_block)(
			    arguments[1], arguments[2]);
		}
		break;
	case ARG_VARI:
		if (isDown)
			// limit, remove
			((void (^)(OFString *))_block)([[arguments
			    objectsInRange: OFMakeRange(1, arguments.count - 1)]
			    componentsJoinedByString: @" "]);
		break;
	}

	return 0;
}
@end
