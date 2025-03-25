#import "DynamicEntity.h"

OF_DIRECT_MEMBERS
@interface Monster: DynamicEntity
@property (class, readonly, nonatomic) OFMutableArray<Monster *> *monsters;
// one of M_*
@property (nonatomic) int monsterState;
// see Monster.m
@property (nonatomic) int monsterType;
// monster wants to kill this entity
@property (nonatomic) DynamicEntity *enemy;
// monster wants to look in this direction
@property (nonatomic) float targetYaw;
// millis at which transition to another monsterstate takes place
@property (nonatomic) int trigger;
// delayed attacks
@property (nonatomic) OFVector3D attackTarget;
// how many times already hit by fellow monster
@property (nonatomic) int anger;

// called after map start of when toggling edit mode to reset/spawn all
// monsters to initial state
+ (void)restoreAll;
+ (void)resetAll;
+ (void)thinkAll;
+ (void)renderAll;
// TODO: Move this somewhere else
+ (void)endSinglePlayerWithAllKilled:(bool)allKilled;
+ (instancetype)monsterWithType:(int)type
                            yaw:(int)yaw
                          state:(int)state
                        trigger:(int)trigger
                           move:(int)move;
- (instancetype)initWithType:(int)type
                         yaw:(int)yaw
                       state:(int)state
                     trigger:(int)trigger
                        move:(int)move;
- (void)incurDamage:(int)damage fromEntity:(__kindof DynamicEntity *)d;
@end
