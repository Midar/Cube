#import <ObjFW/ObjFW.h>

OF_ASSUME_NONNULL_BEGIN

OF_DIRECT_MEMBERS
@interface KeyMapping: OFObject
@property (readonly) int code;
@property (readonly, nonatomic) OFString *name;
@property (copy, nonatomic) OFString *action;

+ (instancetype)mappingWithCode: (int)code name: (OFString *)name;
- (instancetype)init OF_UNAVAILABLE;
- (instancetype)initWithCode: (int)code name: (OFString *)name;
@end

OF_ASSUME_NONNULL_END
