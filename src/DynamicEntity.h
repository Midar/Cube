#import <ObjFW/ObjFW.h>

// players & monsters
@interface DynamicEntity: OFObject <OFCopying>
@property (class, direct, readonly, nonatomic) size_t serializedSize;

@property (direct, nonatomic) OFVector3D origin, velocity;
// used as OFVector3D in one place
@property (direct, nonatomic) float yaw, pitch, roll;
// cubes per second, 24 for player
@property (direct, nonatomic) float maxSpeed;
// from his eyes
@property (direct, nonatomic) bool outsideMap;
@property (direct, nonatomic) bool inWater;
@property (direct, nonatomic) bool onFloor, jumpNext;
@property (direct, nonatomic) int move, strafe;
// see input code
@property (direct, nonatomic) bool k_left, k_right, k_up, k_down;
// used for fake gravity
@property (direct, nonatomic) int timeInAir;
// bounding box size
@property (direct, nonatomic) float radius, eyeHeight, aboveEye;
@property (direct, nonatomic) int lastUpdate, lag, ping;
// one of CS_* below
@property (direct, nonatomic) int state;
@property (direct, nonatomic) int health, armour, armourType, quadMillis;
@property (direct, nonatomic) int gunSelect, gunWait;
@property (direct, nonatomic) int lastAction, lastAttackGun, lastMove;
@property (direct, readonly, nonatomic) int *ammo;
@property (direct, nonatomic) bool attacking;
// used by physics to signal ai
@property (direct, nonatomic) bool blocked, moving;
@property (direct, copy, nonatomic) OFString *name;

- (OFData *)dataBySerializing;
- (void)setFromSerializedData: (OFData *)data;
- (void)resetMovement;
// reset player state not persistent accross spawns
- (void)resetToSpawnState;
@end
