#import "Identifier.h"

OF_ASSUME_NONNULL_BEGIN

#define COMMAND(name, nargs, block_)                          \
	OF_CONSTRUCTOR()                                      \
	{                                                     \
		enqueueInit(^{                                \
			Identifier.identifiers[@ #name] =     \
			    [Command commandWithName:@ #name  \
			              argumentsTypes:nargs    \
			                       block:block_]; \
		});                                           \
	}

@interface Command: Identifier
@property (readonly, nonatomic) int argumentsTypes;

+ (instancetype)commandWithName:(OFString *)name
                 argumentsTypes:(int)argumentsTypes
                          block:(id)block;
- (instancetype)initWithName:(OFString *)name OF_UNAVAILABLE;
- (instancetype)initWithName:(OFString *)name
              argumentsTypes:(int)argumentsTypes
                       block:(id)block;
- (int)callWithArguments:(OFArray<OFString *> *)arguments isDown:(bool)isDown;
@end

OF_ASSUME_NONNULL_END
