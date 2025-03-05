#import <ObjFW/ObjFW.h>

OF_ASSUME_NONNULL_BEGIN

@interface MapModelInfo : OFObject
@property (nonatomic) int rad, h, zoff, snap;
@property (copy, nonatomic) OFString *name;

- (instancetype)initWithRad:(int)rad
                          h:(int)h
                       zoff:(int)zoff
                       snap:(int)snap
                       name:(OFString *)name;
@end

OF_ASSUME_NONNULL_END
