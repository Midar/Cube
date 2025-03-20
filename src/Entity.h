#import "PersistentEntity.h"

@interface Entity: PersistentEntity
@property (nonatomic) bool spawned; // the only dynamic state of a map entity
@end
