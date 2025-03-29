#import "Identifier.h"

OF_ASSUME_NONNULL_BEGIN

@interface Alias: Identifier
@property (direct, copy, nonatomic) OFString *action;
@property (readonly, nonatomic) bool persisted;

+ (instancetype)aliasWithName: (OFString *)name
		       action: (OFString *)action
		    persisted: (bool)persisted OF_DIRECT;
- (instancetype)initWithName: (OFString *)name OF_UNAVAILABLE;
- (instancetype)initWithName: (OFString *)name
		      action: (OFString *)action
		   persisted: (bool)persisted OF_DESIGNATED_INITIALIZER
    OF_DIRECT;
@end

OF_ASSUME_NONNULL_END
