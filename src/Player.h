#import "DynamicEntity.h"

OF_DIRECT_MEMBERS
@interface Player: DynamicEntity
// special client ent that receives input and acts as camera
@property (class, nonatomic) Player *player1;
// sequence id for each respawn, used in damage test
@property (nonatomic) int lifeSequence;
@property (nonatomic) int frags;
@property (copy, nonatomic) OFString *team;

+ (instancetype)player;
@end
