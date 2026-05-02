#import <ObjFW/ObjFW.h>

@interface OFString (Cube)
@property (readonly, nonatomic) int _intValue;

- (int)_intValueWithBase: (unsigned char)base;
@end
