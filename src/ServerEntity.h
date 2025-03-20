#import <ObjFW/ObjFW.h>

// server side version of "entity" type
@interface ServerEntity: OFObject
@property (nonatomic) bool spawned;
@property (nonatomic) int spawnsecs;

+ (instancetype)entity;
@end
