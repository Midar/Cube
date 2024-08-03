#include <vector>

#import "cube.h"
#import "protos.h"

static std::vector<void (^)(void)> *queue;

void
enqueueInit(const char *name, void (^init)(void))
{
	if (queue == NULL)
		queue = new std::vector<void (^)(void)>();

	queue->push_back(init);
}

void
processInitQueue(void)
{
	for (auto &init : *queue)
		init();

	queue->clear();
}
