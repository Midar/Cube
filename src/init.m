#import "cube.h"

static void **queue;
static size_t queueCount;

void
enqueueInit(void (^init)(void))
{
	queue = realloc(queue, (queueCount + 1) * sizeof(void *));
	if (queue == NULL)
		fatal(@"cannot allocate init queue");

	queue[queueCount++] = (__bridge void *)init;
}

void
processInitQueue(void)
{
	for (size_t i = 0; i < queueCount; i++)
		((__bridge void (^)())queue[i])();

	free(queue);
	queueCount = 0;
}
