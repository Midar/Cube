#import <ObjFW/ObjFW.h>

@class DynamicEntity;

OF_DIRECT_MEMBERS
@interface Projectile: OFObject
@property (nonatomic) OFVector3D o, to;
@property (nonatomic) float speed;
@property (nonatomic) DynamicEntity *owner;
@property (nonatomic) int gun;
@property (nonatomic) bool inuse, local;

+ (instancetype)projectile;
@end
