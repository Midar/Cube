#import <ObjFW/ObjFW.h>

OF_ASSUME_NONNULL_BEGIN

@class MenuItem;

@interface Menu: OFObject
@property (readonly, nonatomic) OFString *name;
@property (readonly) OFMutableArray<MenuItem *> *items;
@property (nonatomic) int mwidth;
@property (nonatomic) int menusel;

- (instancetype)initWithName:(OFString *)name;
@end

OF_ASSUME_NONNULL_END
