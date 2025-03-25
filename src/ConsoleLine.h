#import <ObjFW/ObjFW.h>

OF_DIRECT_MEMBERS
@interface ConsoleLine: OFObject
@property (readonly, copy) OFString *text;
@property (readonly) int outtime;

+ (instancetype)lineWithText:(OFString *)text outtime:(int)outtime;
- (instancetype)initWithText:(OFString *)text outtime:(int)outtime;
@end
