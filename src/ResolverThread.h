#import <ObjFW/ObjFW.h>

OF_DIRECT_MEMBERS
@interface ResolverThread: OFThread
{
	volatile bool _stop;
}

@property (copy, nonatomic) OFString *query;
@property (nonatomic) int starttime;

- (void)stop;
@end
