#import "Command.h"

#include <cube.h>

@implementation Command
- (instancetype)initWithName:(OFString *)name
                    function:(void (*)())function
              argumentsTypes:(int)argumentsTypes
{
	self = [super initWithName:name];

	_function = function;
	_argumentsTypes = argumentsTypes;

	return self;
}

- (int)callWithArguments:(char **)arguments
            numArguments:(size_t)numArguments
                  isDown:(bool)isDown
{
	switch (_argumentsTypes) {
	case ARG_1INT:
		if (isDown)
			((void(__cdecl *)(int))_function)(ATOI(arguments[1]));
		break;
	case ARG_2INT:
		if (isDown)
			((void(__cdecl *)(int, int))_function)(
			    ATOI(arguments[1]), ATOI(arguments[2]));
		break;
	case ARG_3INT:
		if (isDown)
			((void(__cdecl *)(int, int, int))_function)(
			    ATOI(arguments[1]), ATOI(arguments[2]),
			    ATOI(arguments[3]));
		break;
	case ARG_4INT:
		if (isDown)
			((void(__cdecl *)(int, int, int, int))_function)(
			    ATOI(arguments[1]), ATOI(arguments[2]),
			    ATOI(arguments[3]), ATOI(arguments[4]));
		break;
	case ARG_NONE:
		if (isDown)
			((void(__cdecl *)())_function)();
		break;
	case ARG_1STR:
		if (isDown) {
			@autoreleasepool {
				((void(__cdecl *)(OFString *))_function)(
				    @(arguments[1]));
			}
		}
		break;
	case ARG_2STR:
		if (isDown) {
			@autoreleasepool {
				((void(__cdecl *)(
				    OFString *, OFString *))_function)(
				    @(arguments[1]), @(arguments[2]));
			}
		}
		break;
	case ARG_3STR:
		if (isDown) {
			@autoreleasepool {
				((void(__cdecl *)(OFString *, OFString *,
				    OFString *))_function)(@(arguments[1]),
				    @(arguments[2]), @(arguments[3]));
			}
		}
		break;
	case ARG_5STR:
		if (isDown) {
			@autoreleasepool {
				((void(__cdecl *)(OFString *, OFString *,
				    OFString *, OFString *,
				    OFString *))_function)(@(arguments[1]),
				    @(arguments[2]), @(arguments[3]),
				    @(arguments[4]), @(arguments[5]));
			}
		}
		break;
	case ARG_DOWN:
		((void(__cdecl *)(bool))_function)(isDown);
		break;
	case ARG_DWN1:
		((void(__cdecl *)(bool, char *))_function)(
		    isDown, arguments[1]);
		break;
	case ARG_1EXP:
		if (isDown)
			return ((int(__cdecl *)(int))_function)(
			    execute(arguments[1]));
		break;
	case ARG_2EXP:
		if (isDown)
			return ((int(__cdecl *)(int, int))_function)(
			    execute(arguments[1]), execute(arguments[2]));
		break;
	case ARG_1EST:
		if (isDown)
			return ((int(__cdecl *)(char *))_function)(
			    arguments[1]);
		break;
	case ARG_2EST:
		if (isDown)
			return ((int(__cdecl *)(char *, char *))_function)(
			    arguments[1], arguments[2]);
		break;
	case ARG_VARI:
		if (isDown) {
			// limit, remove
			string r;
			r[0] = 0;
			for (int i = 1; i < numArguments; i++) {
				// make string-list out of all arguments
				strcat_s(r, arguments[i]);
				if (i == numArguments - 1)
					break;
				strcat_s(r, " ");
			}
			((void(__cdecl *)(char *))_function)(r);
		}
		break;
	}

	return 0;
}
@end
