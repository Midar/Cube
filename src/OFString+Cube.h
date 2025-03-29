#import <ObjFW/ObjFW.h>

@interface OFString (Cube)
@property (readonly, nonatomic) int cube_intValue;

- (int)cube_intValueWithBase: (unsigned char)base;
@end
