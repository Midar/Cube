#import <ObjFW/ObjFW.h>

@interface MenuItem: OFObject
@property (readonly, nonatomic) OFString *text, *action;

- (instancetype)initWithText:(OFString *)text action:(OFString *)action;
@end
