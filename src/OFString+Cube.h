#import <ObjFW/ObjFW.h>

OF_DIRECT_MEMBERS
@interface
OFString (Cube)
@property (readonly, nonatomic) int cube_intValue;

- (int)cube_intValueWithBase:(unsigned char)base;
@end
