// serverbrowser.cpp: eihrul's concurrent resolver, and server browser window
// management

#include "SDL_thread.h"
#include "cube.h"

#import "ResolverResult.h"
#import "ResolverThread.h"
#import "ServerInfo.h"

static OFMutableArray<ResolverThread *> *resolverthreads;
OFMutableArray<OFString *> *resolverqueries;
OFMutableArray<ResolverResult *> *resolverresults;
SDL_sem *resolversem;
static int resolverlimit = 1000;

void
resolverinit(int threads, int limit)
{
	resolverthreads = [[OFMutableArray alloc] init];
	resolverqueries = [[OFMutableArray alloc] init];
	resolverresults = [[OFMutableArray alloc] init];
	resolverlimit = limit;
	resolversem = SDL_CreateSemaphore(0);

	while (threads > 0) {
		ResolverThread *rt = [ResolverThread thread];
		rt.name = @"resolverthread";
		[resolverthreads addObject:rt];
		[rt start];
		--threads;
	}
}

void
resolverstop(size_t i, bool restart)
{
	@synchronized(ResolverThread.class) {
		ResolverThread *rt = resolverthreads[i];
		[rt stop];

		if (restart) {
			rt = [ResolverThread thread];
			rt.name = @"resolverthread";

			resolverthreads[i] = rt;

			[rt start];
		} else
			[resolverthreads removeObjectAtIndex:i];
	}
}

void
resolverclear()
{
	@synchronized(ResolverThread.class) {
		[resolverqueries removeAllObjects];
		[resolverresults removeAllObjects];

		while (SDL_SemTryWait(resolversem) == 0)
			;

		for (size_t i = 0; i < resolverthreads.count; i++)
			resolverstop(i, true);
	}
}

void
resolverquery(OFString *name)
{
	@synchronized(ResolverThread.class) {
		[resolverqueries addObject:name];
		SDL_SemPost(resolversem);
	}
}

bool
resolvercheck(OFString **name, ENetAddress *address)
{
	@synchronized(ResolverThread.class) {
		if (resolverresults.count > 0) {
			ResolverResult *rr = resolverresults.lastObject;
			*name = rr.query;
			*address = rr.address;
			[resolverresults removeLastObject];
			return true;
		}

		for (size_t i = 0; i < resolverthreads.count; i++) {
			ResolverThread *rt = resolverthreads[i];

			if (rt.query) {
				if (lastmillis - rt.starttime > resolverlimit) {
					resolverstop(i, true);
					*name = rt.query;
					return true;
				}
			}
		}
	}

	return false;
}

static OFMutableArray<ServerInfo *> *servers;
static ENetSocket pingsock = ENET_SOCKET_NULL;
static int lastinfo = 0;

OFString *
getservername(int n)
{
	return servers[n].name;
}

void
addserver(OFString *servername)
{
	for (ServerInfo *si in servers)
		if ([si.name isEqual:servername])
			return;

	if (servers == nil)
		servers = [[OFMutableArray alloc] init];

	[servers addObject:[ServerInfo infoWithName:servername]];
}

void
pingservers()
{
	ENetBuffer buf;
	uchar ping[MAXTRANS];
	uchar *p;

	for (ServerInfo *si in servers) {
		if (si.address.host == ENET_HOST_ANY)
			continue;

		p = ping;
		putint(&p, lastmillis);
		buf.data = ping;
		buf.dataLength = p - ping;
		ENetAddress address = si.address;
		enet_socket_send(pingsock, &address, &buf, 1);
	}

	lastinfo = lastmillis;
}

void
checkresolver()
{
	OFString *name = nil;
	ENetAddress addr = { ENET_HOST_ANY, CUBE_SERVINFO_PORT };
	while (resolvercheck(&name, &addr)) {
		if (addr.host == ENET_HOST_ANY)
			continue;

		for (ServerInfo *si in servers) {
			if ([name isEqual:si.name]) {
				si.address = addr;
				addr.host = ENET_HOST_ANY;
				break;
			}
		}
	}
}

void
checkpings()
{
	enet_uint32 events = ENET_SOCKET_WAIT_RECEIVE;
	ENetBuffer buf;
	ENetAddress addr;
	uchar ping[MAXTRANS], *p;
	char text[MAXTRANS];
	buf.data = ping;
	buf.dataLength = sizeof(ping);

	while (enet_socket_wait(pingsock, &events, 0) >= 0 && events) {
		if (enet_socket_receive(pingsock, &addr, &buf, 1) <= 0)
			return;

		for (ServerInfo *si in servers) {
			if (addr.host == si.address.host) {
				p = ping;
				si.ping = lastmillis - getint(&p);
				si.protocol = getint(&p);
				if (si.protocol != PROTOCOL_VERSION)
					si.ping = 9998;
				si.mode = getint(&p);
				si.numplayers = getint(&p);
				si.minremain = getint(&p);
				sgetstr();
				si.map = @(text);
				sgetstr();
				si.sdesc = @(text);
				break;
			}
		}
	}
}

void
refreshservers()
{
	checkresolver();
	checkpings();
	if (lastmillis - lastinfo >= 5000)
		pingservers();
	[servers sort];

	__block int maxmenu = 16;
	[servers enumerateObjectsUsingBlock:^(
	    ServerInfo *si, size_t i, bool *stop) {
		if (si.address.host != ENET_HOST_ANY && si.ping != 9999) {
			if (si.protocol != PROTOCOL_VERSION)
				si.full = [OFString
				    stringWithFormat:
				        @"%@ [different cube protocol]",
				    si.name];
			else
				si.full = [OFString
				    stringWithFormat:@"%d\t%d\t%@, %@: %@ %@",
				    si.ping, si.numplayers,
				    si.map.length > 0 ? si.map : @"[unknown]",
				    modestr(si.mode), si.name, si.sdesc];
		} else
			si.full = [OFString
			    stringWithFormat:
			        (si.address.host != ENET_HOST_ANY
			                ? @"%@ [waiting for server response]"
			                : @"%@ [unknown host]\t"),
			    si.name];

		// cut off too long server descriptions
		if (si.full.length > 50)
			si.full = [si.full substringToIndex:50];

		menumanual(1, i, si.full);

		if (!--maxmenu)
			return;
	}];
}

void
servermenu()
{
	if (pingsock == ENET_SOCKET_NULL) {
		pingsock = enet_socket_create(ENET_SOCKET_TYPE_DATAGRAM, NULL);
		resolverinit(1, 1000);
	}

	resolverclear();

	for (ServerInfo *si in servers)
		resolverquery(si.name);

	refreshservers();
	menuset(1);
}

void
updatefrommaster()
{
	const int MAXUPD = 32000;
	uchar buf[MAXUPD];
	uchar *reply = retrieveservers(buf, MAXUPD);
	if (!*reply || strstr((char *)reply, "<html>") ||
	    strstr((char *)reply, "<HTML>"))
		conoutf(@"master server not replying");
	else {
		[servers removeAllObjects];
		execute(@((char *)reply), true);
	}
	servermenu();
}

COMMAND(addserver, ARG_1STR)
COMMAND(servermenu, ARG_NONE)
COMMAND(updatefrommaster, ARG_NONE)

void
writeservercfg()
{
	FILE *f = fopen("servers.cfg", "w");
	if (!f)
		return;
	fprintf(f, "// servers connected to are added here automatically\n\n");
	for (ServerInfo *si in servers.reversedArray)
		fprintf(f, "addserver %s\n", si.name.UTF8String);
	fclose(f);
}
