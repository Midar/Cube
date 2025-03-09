#import <ObjFW/ObjFW.h>

// players & monsters
@interface DynamicEntity: OFObject <OFCopying>
@property (class, readonly, nonatomic) size_t serializedSize;

// origin, velocity
@property (nonatomic) OFVector3D o, vel;
// used as OFVector3D in one place
@property (nonatomic) float yaw, pitch, roll;
// cubes per second, 24 for player
@property (nonatomic) float maxspeed;
// from his eyes
@property (nonatomic) bool outsidemap;
@property (nonatomic) bool inwater;
@property (nonatomic) bool onfloor, jumpnext;
@property (nonatomic) int move, strafe;
// see input code
@property (nonatomic) bool k_left, k_right, k_up, k_down;
// used for fake gravity
@property (nonatomic) int timeinair;
// bounding box size
@property (nonatomic) float radius, eyeheight, aboveeye;
@property (nonatomic) int lastupdate, plag, ping;
// sequence id for each respawn, used in damage test
@property (nonatomic) int lifesequence;
// one of CS_* below
@property (nonatomic) int state;
@property (nonatomic) int frags;
@property (nonatomic) int health, armour, armourtype, quadmillis;
@property (nonatomic) int gunselect, gunwait;
@property (nonatomic) int lastaction, lastattackgun, lastmove;
@property (nonatomic) bool attacking;
@property (readonly, nonatomic) int *ammo;
// one of M_* below, M_NONE means human
@property (nonatomic) int monsterstate;
// see monster.cpp
@property (nonatomic) int mtype;
// monster wants to kill this entity
@property (nonatomic) DynamicEntity *enemy;
// monster wants to look in this direction
@property (nonatomic) float targetyaw;
// used by physics to signal ai
@property (nonatomic) bool blocked, moving;
// millis at which transition to another monsterstate takes place
@property (nonatomic) int trigger;
// delayed attacks
@property (nonatomic) OFVector3D attacktarget;
// how many times already hit by fellow monster
@property (nonatomic) int anger;
@property (copy, nonatomic) OFString *name, *team;

- (OFData *)dataBySerializing;
- (void)setFromSerializedData:(OFData *)data;
@end
