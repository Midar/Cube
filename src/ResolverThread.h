#import <ObjFW/ObjFW.h>

@interface ResolverThread: OFThread
{
	volatile bool _stop;
}

@property (copy, nonatomic) OFString *query;
@property (nonatomic) int starttime;

- (void)stop;
@end
