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
// sequence id for each respawn, used in damage test
@property (nonatomic) int lifeSequence;
// one of CS_* below
@property (nonatomic) int state;
@property (nonatomic) int frags;
@property (nonatomic) int health, armour, armourType, quadMillis;
@property (nonatomic) int gunSelect, gunWait;
@property (nonatomic) int lastAction, lastAttackGun, lastMove;
@property (nonatomic) bool attacking;
@property (readonly, nonatomic) int *ammo;
// one of M_* below, M_NONE means human
@property (nonatomic) int monsterState;
// see monster.m
@property (nonatomic) int monsterType;
// monster wants to kill this entity
@property (nonatomic) DynamicEntity *enemy;
// monster wants to look in this direction
@property (nonatomic) float targetYaw;
// used by physics to signal ai
@property (nonatomic) bool blocked, moving;
// millis at which transition to another monsterstate takes place
@property (nonatomic) int trigger;
// delayed attacks
@property (nonatomic) OFVector3D attackTarget;
// how many times already hit by fellow monster
@property (nonatomic) int anger;
@property (copy, nonatomic) OFString *name, *team;

+ (instancetype)entity;
- (OFData *)dataBySerializing;
- (void)setFromSerializedData:(OFData *)data;
- (void)resetMovement;
// reset player state not persistent accross spawns
- (void)resetToSpawnState;
@end
