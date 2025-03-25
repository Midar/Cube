#import <ObjFW/ObjFW.h>

OF_ASSUME_NONNULL_BEGIN

@interface Identifier: OFObject
@property (direct, readonly, copy, nonatomic) OFString *name;
@property (class, direct, readonly, nonatomic)
    OFMutableDictionary<OFString *, __kindof Identifier *> *identifiers;

- (instancetype)init OF_UNAVAILABLE;
- (instancetype)initWithName:(OFString *)name;
@end

OF_ASSUME_NONNULL_END
