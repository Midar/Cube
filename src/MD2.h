#import <ObjFW/ObjFW.h>

OF_ASSUME_NONNULL_BEGIN

@class MapModelInfo;

OF_DIRECT_MEMBERS
@interface MD2: OFObject
@property (nonatomic) MapModelInfo *mmi;
@property (copy, nonatomic) OFString *loadname;
@property (nonatomic) int mdlnum;
@property (nonatomic) bool loaded;

+ (instancetype)md2;
- (bool)loadWithIRI: (OFIRI *)IRI;
- (void)renderWithLight: (OFColor *)light
                  frame: (int)frame
                  range: (int)range
               position: (OFVector3D)position
                    yaw: (float)yaw
                  pitch: (float)pitch
                  scale: (float)scale
                  speed: (float)speed
                   snap: (int)snap
               basetime: (int)basetime;
- (void)scaleWithFrame: (int)frame scale: (float)scale snap: (int)snap;
@end

OF_ASSUME_NONNULL_END
