#import <ObjFW/ObjFW.h>

OF_ASSUME_NONNULL_BEGIN

@class MapModelInfo;

@interface MD2: OFObject
@property (nonatomic) MapModelInfo *mmi;
@property (copy, nonatomic) OFString *loadname;
@property (nonatomic) int mdlnum;
@property (nonatomic) bool loaded;

- (bool)loadWithIRI:(OFIRI *)IRI;
- (void)renderWithLight:(OFVector3D)light
                  frame:(int)frame
                  range:(int)range
                      x:(float)x
                      y:(float)y
                      z:(float)z
                    yaw:(float)yaw
                  pitch:(float)pitch
                  scale:(float)scale
                  speed:(float)speed
                   snap:(int)snap
               basetime:(int)basetime;
- (void)scaleWithFrame:(int)frame scale:(float)scale snap:(int)snap;
@end

OF_ASSUME_NONNULL_END
