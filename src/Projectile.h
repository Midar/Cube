#import <ObjFW/ObjFW.h>

typedef struct dynent dynent;

@interface Projectile: OFObject
@property (nonatomic) OFVector3D o, to;
@property (nonatomic) float speed;
@property (nonatomic) dynent *owner;
@property (nonatomic) int gun;
@property (nonatomic) bool inuse, local;
@end
