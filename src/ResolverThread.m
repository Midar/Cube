#import "ResolverThread.h"

#import "ResolverResult.h"

extern SDL_Semaphore *resolversem;
extern OFMutableArray<OFString *> *resolverqueries;
extern OFMutableArray<ResolverResult *> *resolverresults;

@implementation ResolverThread
- (id)main
{
	while (!_stop) {
		SDL_WaitSemaphore(resolversem);

		@synchronized(ResolverThread.class) {
			if (resolverqueries.count == 0)
				continue;

			_query = resolverqueries.lastObject;
			[resolverqueries removeLastObject];
			_starttime = lastmillis;
		}

		ENetAddress address = { ENET_HOST_ANY, CUBE_SERVINFO_PORT };
		enet_address_set_host(&address, _query.UTF8String);

		@synchronized(ResolverThread.class) {
			[resolverresults addObject:
			    [ResolverResult resultWithQuery: _query
						    address: address]];

			_query = NULL;
			_starttime = 0;
		}
	}

	return nil;
}

- (void)stop
{
	_stop = true;
}
@end
