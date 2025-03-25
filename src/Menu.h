#import <ObjFW/ObjFW.h>

OF_ASSUME_NONNULL_BEGIN

@class MenuItem;

OF_DIRECT_MEMBERS
@interface Menu: OFObject
@property (readonly, nonatomic) OFString *name;
@property (readonly) OFMutableArray<MenuItem *> *items;
@property (nonatomic) int mwidth;
@property (nonatomic) int menusel;

+ (instancetype)menuWithName:(OFString *)name;
- (instancetype)init OF_UNAVAILABLE;
- (instancetype)initWithName:(OFString *)name;
@end

OF_ASSUME_NONNULL_END
