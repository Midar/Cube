#import <ObjFW/ObjFW.h>

OF_ASSUME_NONNULL_BEGIN

OF_DIRECT_MEMBERS
@interface MapModelInfo: OFObject
@property (nonatomic) int rad, h, zoff, snap;
@property (copy, nonatomic) OFString *name;

+ (instancetype)infoWithRad: (int)rad
                          h: (int)h
                       zoff: (int)zoff
                       snap: (int)snap
                       name: (OFString *)name;
- (instancetype)init OF_UNAVAILABLE;
- (instancetype)initWithRad: (int)rad
                          h: (int)h
                       zoff: (int)zoff
                       snap: (int)snap
                       name: (OFString *)name;
@end

OF_ASSUME_NONNULL_END
