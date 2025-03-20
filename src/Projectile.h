#import <ObjFW/ObjFW.h>

@class DynamicEntity;

@interface Projectile: OFObject
@property (nonatomic) OFVector3D o, to;
@property (nonatomic) float speed;
@property (nonatomic) DynamicEntity *owner;
@property (nonatomic) int gun;
@property (nonatomic) bool inuse, local;

+ (instancetype)projectile;
@end
