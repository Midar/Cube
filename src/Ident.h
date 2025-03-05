#import <ObjFW/ObjFW.h>

OF_ASSUME_NONNULL_BEGIN

enum IdentType { ID_VAR, ID_COMMAND, ID_ALIAS };

@interface Ident : OFObject
@property (nonatomic) enum IdentType type;
@property (copy, nonatomic) OFString *name;
@property (nonatomic) int min, max;           // ID_VAR
@property (nonatomic) int *storage;           // ID_VAR
@property (nonatomic) void (*fun)();          // ID_VAR, ID_COMMAND
@property (nonatomic) int narg;               // ID_VAR, ID_COMMAND
@property (copy, nonatomic) OFString *action; // ID_ALIAS
@property (nonatomic) bool persist;
@end

OF_ASSUME_NONNULL_END
