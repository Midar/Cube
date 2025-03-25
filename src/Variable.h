#import "Identifier.h"

OF_ASSUME_NONNULL_BEGIN

#define VARP(name, min_, cur, max_)                                 \
	int name = cur;                                             \
                                                                    \
	OF_CONSTRUCTOR()                                            \
	{                                                           \
		enqueueInit(^{                                      \
			Variable *variable =                        \
			    [Variable variableWithName:@ #name      \
			                           min:min_         \
			                           max:max_         \
			                       storage:&name        \
			                      function:NULL         \
			                     persisted:true];       \
			Identifier.identifiers[@ #name] = variable; \
		});                                                 \
	}
#define VAR(name, min_, cur, max_)                                  \
	int name = cur;                                             \
                                                                    \
	OF_CONSTRUCTOR()                                            \
	{                                                           \
		enqueueInit(^{                                      \
			Variable *variable =                        \
			    [Variable variableWithName:@ #name      \
			                           min:min_         \
			                           max:max_         \
			                       storage:&name        \
			                      function:NULL         \
			                     persisted:false];      \
			Identifier.identifiers[@ #name] = variable; \
		});                                                 \
	}
#define VARF(name, min_, cur, max_, body)                           \
	static void var_##name();                                   \
	static int name = cur;                                      \
                                                                    \
	OF_CONSTRUCTOR()                                            \
	{                                                           \
		enqueueInit(^{                                      \
			Variable *variable =                        \
			    [Variable variableWithName:@ #name      \
			                           min:min_         \
			                           max:max_         \
			                       storage:&name        \
			                      function:var_##name   \
			                     persisted:false];      \
			Identifier.identifiers[@ #name] = variable; \
		});                                                 \
	}                                                           \
                                                                    \
	static void var_##name() { body; }
#define VARFP(name, min_, cur, max_, body)                          \
	static void var_##name();                                   \
	static int name = cur;                                      \
                                                                    \
	OF_CONSTRUCTOR()                                            \
	{                                                           \
		enqueueInit(^{                                      \
			Variable *variable =                        \
			    [Variable variableWithName:@ #name      \
			                           min:min_         \
			                           max:max_         \
			                       storage:&name        \
			                      function:var_##name   \
			                     persisted:true];       \
			Identifier.identifiers[@ #name] = variable; \
		});                                                 \
	}                                                           \
                                                                    \
	static void var_##name() { body; }

@interface Variable: Identifier
@property (readonly, nonatomic) int min, max;
@property (readonly, nonatomic) int *storage;
@property (readonly, nullable, nonatomic) void (*function)();
@property (readonly, nonatomic) bool persisted;

+ (instancetype)variableWithName:(OFString *)name
                             min:(int)min
                             max:(int)max
                         storage:(int *)storage
                        function:(void (*_Nullable)())function
                       persisted:(bool)persisted;
- (instancetype)initWithName:(OFString *)name OF_UNAVAILABLE;
- (instancetype)initWithName:(OFString *)name
                         min:(int)min
                         max:(int)max
                     storage:(int *)storage
                    function:(void (*_Nullable)())function
                   persisted:(bool)persisted;
- (void)printValue;
- (void)setValue:(int)value;
@end

OF_ASSUME_NONNULL_END
