#import "Identifier.h"

OF_ASSUME_NONNULL_BEGIN

@interface Command: Identifier
@property (readonly, nonatomic) void (*function)();
@property (readonly, nonatomic) int argumentsTypes;

+ (instancetype)commandWithName:(OFString *)name
                       function:(void (*)())function
                 argumentsTypes:(int)argumentsTypes;
- (instancetype)initWithName:(OFString *)name OF_UNAVAILABLE;
- (instancetype)initWithName:(OFString *)name
                    function:(void (*)())function
              argumentsTypes:(int)argumentsTypes;
- (int)callWithArguments:(OFArray<OFString *> *)arguments isDown:(bool)isDown;
@end

OF_ASSUME_NONNULL_END
