#import <ObjFW/ObjFW.h>

OF_ASSUME_NONNULL_BEGIN

@interface Identifier: OFObject
@property (readonly, copy, nonatomic) OFString *name;
@property (class, readonly, nonatomic)
    OFMutableDictionary<OFString *, __kindof Identifier *> *identifiers;

- (instancetype)init OF_UNAVAILABLE;
- (instancetype)initWithName:(OFString *)name;
@end

OF_ASSUME_NONNULL_END
