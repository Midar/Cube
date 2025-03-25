#import <ObjFW/ObjFW.h>

OF_DIRECT_MEMBERS
@interface MenuItem: OFObject
@property (readonly, nonatomic) OFString *text, *action;

+ (instancetype)itemWithText:(OFString *)text action:(OFString *)action;
- (instancetype)init OF_UNAVAILABLE;
- (instancetype)initWithText:(OFString *)text action:(OFString *)action;
@end
