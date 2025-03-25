#import <ObjFW/ObjFW.h>

#import "cube.h"

// server side version of "dynent" type
OF_DIRECT_MEMBERS
@interface Client: OFObject
@property (nonatomic) int type;
@property (nonatomic) ENetPeer *peer;
@property (copy, nonatomic) OFString *hostname;
@property (copy, nonatomic) OFString *mapvote;
@property (copy, nonatomic) OFString *name;
@property (nonatomic) int modevote;

+ (instancetype)client;
@end
