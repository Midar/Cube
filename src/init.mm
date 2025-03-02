#include <vector>

#import "cube.h"
#import "protos.h"

static OFMutableArray<void (^)(void)> *queue;

void
enqueueInit(void (^init)(void))
{
	if (queue == nil)
		queue = [[OFMutableArray alloc] init];

	[queue addObject:init];
}

void
processInitQueue(void)
{
	for (void (^init)(void) in queue)
		init();

	[queue removeAllObjects];
}
