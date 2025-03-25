#import <ObjFW/ObjFW.h>

#include <enet/enet.h>

OF_DIRECT_MEMBERS
@interface ServerInfo: OFObject <OFComparing>
@property (readonly, nonatomic) OFString *name;
@property (copy, nonatomic) OFString *full;
@property (copy, nonatomic) OFString *map;
@property (copy, nonatomic) OFString *sdesc;
@property (nonatomic) int mode, numplayers, ping, protocol, minremain;
@property (nonatomic) ENetAddress address;

+ (instancetype)infoWithName:(OFString *)name;
- (instancetype)init OF_UNAVAILABLE;
- (instancetype)initWithName:(OFString *)name;
@end
