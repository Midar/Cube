#import <ObjFW/ObjFW.h>

@interface MenuItem: OFObject
@property (readonly, nonatomic) OFString *text, *action;

+ (instancetype)itemWithText:(OFString *)text action:(OFString *)action;
- (instancetype)init OF_UNAVAILABLE;
- (instancetype)initWithText:(OFString *)text action:(OFString *)action;
@end
