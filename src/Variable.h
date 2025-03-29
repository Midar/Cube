#import "Identifier.h"

OF_ASSUME_NONNULL_BEGIN

#define VAR(name, min_, cur, max_)					\
	int name = cur;							\
									\
	OF_CONSTRUCTOR()						\
	{								\
		enqueueInit(^ {						\
			Variable *variable = [Variable			\
			    variableWithName: @#name			\
					 min: min_			\
					 max: max_			\
				     storage: &name			\
				   persisted: false			\
				      getter: NULL			\
				      setter: NULL];			\
			Identifier.identifiers[@#name] = variable;	\
		});							\
	}
#define VARP(name, min_, cur, max_)					\
	int name = cur;							\
									\
	OF_CONSTRUCTOR()						\
	{								\
		enqueueInit(^ {						\
			Variable *variable = [Variable			\
			    variableWithName: @#name			\
					 min: min_			\
					 max: max_			\
				     storage: &name			\
				   persisted: true			\
				      getter: NULL			\
				      setter: NULL];			\
			Identifier.identifiers[@#name] = variable;	\
		});							\
	}
#define VARB(name, min_, max_, getter_, setter_)			\
	OF_CONSTRUCTOR()						\
	{								\
		enqueueInit(^ {						\
			Variable *variable = [Variable			\
			    variableWithName: @#name			\
					 min: min_			\
					 max: max_			\
				     storage: NULL			\
				   persisted: false			\
				      getter: getter_			\
				      setter: setter_];			\
			Identifier.identifiers[@#name] = variable;	\
		});							\
	}
#define VARBP(name, min_, max_, getter_, setter_)			\
	OF_CONSTRUCTOR()						\
	{								\
		enqueueInit(^ {						\
			Variable *variable = [Variable			\
			    variableWithName: @#name			\
					 min: min_			\
					 max: max_			\
				     storage: NULL			\
				   persisted: true			\
				      getter: getter_			\
				      setter: setter_];			\
			Identifier.identifiers[@#name] = variable;	\
		});							\
	}

@interface Variable: Identifier
@property (direct, readonly, nonatomic) int min, max;
@property (readonly, nonatomic) bool persisted;
@property (direct, readonly, nullable, nonatomic) int (^getter)(void);
@property (direct, readonly, nullable, nonatomic) void (^setter)(int);
@property (direct, nonatomic) int value;

+ (instancetype)variableWithName: (OFString *)name
			     min: (int)min
			     max: (int)max
			 storage: (nullable int *)storage
		       persisted: (bool)persisted
			  getter: (int (^_Nullable)(void))getter
			  setter: (void (^_Nullable)(int))setter OF_DIRECT;
- (instancetype)initWithName: (OFString *)name OF_UNAVAILABLE;
- (instancetype)initWithName: (OFString *)name
			 min: (int)min
			 max: (int)max
		     storage: (nullable int *)storage
		   persisted: (bool)persisted
		      getter: (int (^_Nullable)(void))getter
		      setter: (void (^_Nullable)(int))setter
    OF_DESIGNATED_INITIALIZER OF_DIRECT;
- (void)printValue OF_DIRECT;
@end

OF_ASSUME_NONNULL_END
