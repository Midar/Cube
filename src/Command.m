#import "Command.h"
#import "OFString+Cube.h"

#include <cube.h>

static OFArray<OFString *> *
padArguments(OFArray<OFString *> *arguments, size_t count)
{
	OFMutableArray<OFString *> *copy;

	if (arguments.count >= count)
		return arguments;

	copy = [arguments mutableCopy];
	while (copy.count < count)
		[copy addObject:@""];

	[copy makeImmutable];
	return copy;
}

@implementation Command
+ (instancetype)commandWithName:(OFString *)name
                       function:(void (*)())function
                 argumentsTypes:(int)argumentsTypes
{
	return [[self alloc] initWithName:name
	                         function:function
	                   argumentsTypes:argumentsTypes];
}

- (instancetype)initWithName:(OFString *)name
                    function:(void (*)())function
              argumentsTypes:(int)argumentsTypes
{
	self = [super initWithName:name];

	_function = function;
	_argumentsTypes = argumentsTypes;

	return self;
}

- (int)callWithArguments:(OFArray<OFString *> *)arguments isDown:(bool)isDown
{
	switch (_argumentsTypes) {
	case ARG_1INT:
		if (isDown) {
			arguments = padArguments(arguments, 2);
			((void(__cdecl *)(int))_function)(
			    [arguments[1] cube_intValueWithBase:0]);
		}
		break;
	case ARG_2INT:
		if (isDown) {
			arguments = padArguments(arguments, 3);
			((void(__cdecl *)(int, int))_function)(
			    [arguments[1] cube_intValueWithBase:0],
			    [arguments[2] cube_intValueWithBase:0]);
		}
		break;
	case ARG_3INT:
		if (isDown) {
			arguments = padArguments(arguments, 4);
			((void(__cdecl *)(int, int, int))_function)(
			    [arguments[1] cube_intValueWithBase:0],
			    [arguments[2] cube_intValueWithBase:0],
			    [arguments[3] cube_intValueWithBase:0]);
		}
		break;
	case ARG_4INT:
		if (isDown) {
			arguments = padArguments(arguments, 5);
			((void(__cdecl *)(int, int, int, int))_function)(
			    [arguments[1] cube_intValueWithBase:0],
			    [arguments[2] cube_intValueWithBase:0],
			    [arguments[3] cube_intValueWithBase:0],
			    [arguments[4] cube_intValueWithBase:0]);
		}
		break;
	case ARG_NONE:
		if (isDown)
			((void(__cdecl *)())_function)();
		break;
	case ARG_1STR:
		if (isDown) {
			arguments = padArguments(arguments, 2);
			((void(__cdecl *)(OFString *))_function)(arguments[1]);
		}
		break;
	case ARG_2STR:
		if (isDown) {
			arguments = padArguments(arguments, 3);
			((void(__cdecl *)(OFString *, OFString *))_function)(
			    arguments[1], arguments[2]);
		}
		break;
	case ARG_3STR:
		if (isDown) {
			arguments = padArguments(arguments, 4);
			((void(__cdecl *)(
			    OFString *, OFString *, OFString *))_function)(
			    arguments[1], arguments[2], arguments[3]);
		}
		break;
	case ARG_5STR:
		if (isDown) {
			arguments = padArguments(arguments, 6);
			((void(__cdecl *)(OFString *, OFString *, OFString *,
			    OFString *, OFString *))_function)(arguments[1],
			    arguments[2], arguments[3], arguments[4],
			    arguments[5]);
		}
		break;
	case ARG_DOWN:
		((void(__cdecl *)(bool))_function)(isDown);
		break;
	case ARG_DWN1:
		arguments = padArguments(arguments, 2);
		((void(__cdecl *)(bool, OFString *))_function)(
		    isDown, arguments[1]);
		break;
	case ARG_1EXP:
		if (isDown) {
			arguments = padArguments(arguments, 2);
			return ((int(__cdecl *)(int))_function)(
			    execute(arguments[1], isDown));
		}
		break;
	case ARG_2EXP:
		if (isDown) {
			arguments = padArguments(arguments, 3);
			return ((int(__cdecl *)(int, int))_function)(
			    execute(arguments[1], isDown),
			    execute(arguments[2], isDown));
		}
		break;
	case ARG_1EST:
		if (isDown) {
			arguments = padArguments(arguments, 2);
			return ((int(__cdecl *)(OFString *))_function)(
			    arguments[1]);
		}
		break;
	case ARG_2EST:
		if (isDown) {
			arguments = padArguments(arguments, 3);
			return ((int(__cdecl *)(OFString *,
			    OFString *))_function)(arguments[1], arguments[2]);
		}
		break;
	case ARG_VARI:
		if (isDown)
			// limit, remove
			((void(__cdecl *)(OFString *))_function)([[arguments
			    objectsInRange:OFMakeRange(1, arguments.count - 1)]
			    componentsJoinedByString:@" "]);
		break;
	}

	return 0;
}
@end
