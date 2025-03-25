#import <ObjFW/ObjFW.h>

// server side version of "entity" type
OF_DIRECT_MEMBERS
@interface ServerEntity: OFObject
@property (nonatomic) bool spawned;
@property (nonatomic) int spawnsecs;

+ (instancetype)entity;
@end
