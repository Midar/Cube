#import <ObjFW/ObjFW.h>

// map entity
@interface PersistentEntity: OFObject
@property (nonatomic) short x, y, z; // cube aligned position
@property (nonatomic) short attr1;
@property (nonatomic) unsigned char type; // type is one of the above
@property (nonatomic) unsigned char attr2, attr3, attr4;

+ (instancetype)entity;
@end
