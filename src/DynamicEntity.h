#import <ObjFW/ObjFW.h>

// players & monsters
@interface DynamicEntity: OFObject <OFCopying>
@property (class, readonly, nonatomic) size_t serializedSize;

@property (nonatomic) OFVector3D origin, velocity;
// used as OFVector3D in one place
@property (nonatomic) float yaw, pitch, roll;
// cubes per second, 24 for player
@property (nonatomic) float maxSpeed;
// from his eyes
@property (nonatomic) bool outsideMap;
@property (nonatomic) bool inWater;
@property (nonatomic) bool onFloor, jumpNext;
@property (nonatomic) int move, strafe;
// see input code
@property (nonatomic) bool k_left, k_right, k_up, k_down;
// used for fake gravity
@property (nonatomic) int timeInAir;
// bounding box size
@property (nonatomic) float radius, eyeHeight, aboveEye;
@property (nonatomic) int lastUpdate, lag, ping;
// one of CS_* below
@property (nonatomic) int state;
@property (nonatomic) int health, armour, armourType, quadMillis;
@property (nonatomic) int gunSelect, gunWait;
@property (nonatomic) int lastAction, lastAttackGun, lastMove;
@property (readonly, nonatomic) int *ammo;
@property (nonatomic) bool attacking;
// used by physics to signal ai
@property (nonatomic) bool blocked, moving;
@property (copy, nonatomic) OFString *name;

+ (instancetype)entity;
- (OFData *)dataBySerializing;
- (void)setFromSerializedData:(OFData *)data;
- (void)resetMovement;
// reset player state not persistent accross spawns
- (void)resetToSpawnState;
@end
