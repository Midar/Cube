#import <ObjFW/ObjFW.h>

#import "cube.h"

@interface ResolverResult: OFObject
@property (readonly, nonatomic) OFString *query;
@property (readonly, nonatomic) ENetAddress address;

+ (instancetype)resultWithQuery:(OFString *)query address:(ENetAddress)address;
- (instancetype)init OF_UNAVAILABLE;
- (instancetype)initWithQuery:(OFString *)query address:(ENetAddress)address;
@end
