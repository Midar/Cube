#import "Identifier.h"

OF_ASSUME_NONNULL_BEGIN

@interface Command : Identifier
@property (readonly, nonatomic) void (*function)();
@property (readonly, nonatomic) int argumentsTypes;

- (instancetype)initWithName:(OFString *)name OF_UNAVAILABLE;
- (instancetype)initWithName:(OFString *)name
                    function:(void (*)())function
              argumentsTypes:(int)argumentsTypes;
- (int)callWithArguments:(char *_Nonnull *_Nonnull)arguments
            numArguments:(size_t)numArguments
                  isDown:(bool)isDown;
@end

OF_ASSUME_NONNULL_END
