#import "Identifier.h"

OF_ASSUME_NONNULL_BEGIN

@interface Variable : Identifier
@property (readonly, nonatomic) int min, max;
@property (readonly, nonatomic) int *storage;
@property (readonly, nonatomic) void (*function)();
@property (readonly, nonatomic) bool persisted;

- (instancetype)initWithName:(OFString *)name OF_UNAVAILABLE;
- (instancetype)initWithName:(OFString *)name
                         min:(int)min
                         max:(int)max
                     storage:(int *)storage
                    function:(void (*)())function
                   persisted:(bool)persisted;
@end

OF_ASSUME_NONNULL_END
