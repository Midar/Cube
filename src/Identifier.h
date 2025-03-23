#import <ObjFW/ObjFW.h>

OF_ASSUME_NONNULL_BEGIN

@interface Identifier: OFObject
@property (readonly, copy, nonatomic) OFString *name;

+ (void)addIdentifier:(__kindof Identifier *)identifier;
+ (__kindof Identifier *)identifierForName:(OFString *)name;
+ (void)enumerateIdentifiersUsingBlock:(void (^)(__kindof Identifier *))block;
- (instancetype)init OF_UNAVAILABLE;
- (instancetype)initWithName:(OFString *)name;
@end

OF_ASSUME_NONNULL_END
