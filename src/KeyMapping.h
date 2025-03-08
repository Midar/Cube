#import <ObjFW/ObjFW.h>

OF_ASSUME_NONNULL_BEGIN

@interface KeyMapping: OFObject
@property (readonly) int code;
@property (readonly, nonatomic) OFString *name;
@property (copy, nonatomic) OFString *action;

- (instancetype)initWithCode:(int)code name:(OFString *)name;
@end

OF_ASSUME_NONNULL_END
