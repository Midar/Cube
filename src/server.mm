// server.cpp: little more than enhanced multicaster
// runs dedicated or as client coroutine

#include "cube.h"

enum { ST_EMPTY, ST_LOCAL, ST_TCPIP };

// server side version of "dynent" type
@interface Client: OFObject
@property (nonatomic) int type;
@property (nonatomic) ENetPeer *peer;
@property (copy, nonatomic) OFString *hostname;
@property (copy, nonatomic) OFString *mapvote;
@property (copy, nonatomic) OFString *name;
@property (nonatomic) int modevote;
@end

@implementation Client
@end

static OFMutableArray<Client *> *clients;

int maxclients = 8;
static OFString *smapname;

// server side version of "entity" type
struct server_entity {
	bool spawned;
	int spawnsecs;
};

vector<server_entity> sents;

// true when map has changed and waiting for clients to send item
bool notgotitems = true;
int mode = 0;

void
restoreserverstate(
    vector<entity> &ents) // hack: called from savegame code, only works in SP
{
	loopv(sents)
	{
		sents[i].spawned = ents[i].spawned;
		sents[i].spawnsecs = 0;
	}
}

int interm = 0, minremain = 0, mapend = 0;
bool mapreload = false;

static OFString *serverpassword = @"";

bool isdedicated;
ENetHost *serverhost = NULL;
int bsend = 0, brec = 0, laststatus = 0, lastsec = 0;

#define MAXOBUF 100000

void process(ENetPacket *packet, int sender);
void multicast(ENetPacket *packet, int sender);
void disconnect_client(int n, OFString *reason);

void
send(int n, ENetPacket *packet)
{
	if (!packet)
		return;

	switch (clients[n].type) {
	case ST_TCPIP:
		enet_peer_send(clients[n].peer, 0, packet);
		bsend += packet->dataLength;
		break;
	case ST_LOCAL:
		localservertoclient(packet->data, packet->dataLength);
		break;
	}
}

void
send2(bool rel, int cn, int a, int b)
{
	ENetPacket *packet =
	    enet_packet_create(NULL, 32, rel ? ENET_PACKET_FLAG_RELIABLE : 0);
	uchar *start = packet->data;
	uchar *p = start + 2;
	putint(p, a);
	putint(p, b);
	*(ushort *)start = ENET_HOST_TO_NET_16(p - start);
	enet_packet_resize(packet, p - start);
	if (cn < 0)
		process(packet, -1);
	else
		send(cn, packet);
	if (packet->referenceCount == 0)
		enet_packet_destroy(packet);
}

void
sendservmsg(OFString *msg)
{
	ENetPacket *packet = enet_packet_create(
	    NULL, _MAXDEFSTR + 10, ENET_PACKET_FLAG_RELIABLE);
	uchar *start = packet->data;
	uchar *p = start + 2;
	putint(p, SV_SERVMSG);
	sendstring(msg, p);
	*(ushort *)start = ENET_HOST_TO_NET_16(p - start);
	enet_packet_resize(packet, p - start);
	multicast(packet, -1);
	if (packet->referenceCount == 0)
		enet_packet_destroy(packet);
}

void
disconnect_client(int n, OFString *reason)
{
	[OFStdOut writeFormat:@"disconnecting client (%@) [%@]\n",
	          clients[n].hostname, reason];
	enet_peer_disconnect(clients[n].peer);
	clients[n].type = ST_EMPTY;
	send2(true, -1, SV_CDIS, n);
}

void
resetitems()
{
	sents.setsize(0);
	notgotitems = true;
}

void
pickup(uint i, int sec, int sender) // server side item pickup, acknowledge
                                    // first client that gets it
{
	if (i >= (uint)sents.length())
		return;
	if (sents[i].spawned) {
		sents[i].spawned = false;
		sents[i].spawnsecs = sec;
		send2(true, sender, SV_ITEMACC, i);
	}
}

void
resetvotes()
{
	for (Client *client in clients)
		client.mapvote = @"";
}

bool
vote(OFString *map, int reqmode, int sender)
{
	clients[sender].mapvote = map;
	clients[sender].modevote = reqmode;

	int yes = 0, no = 0;
	for (Client *client in clients) {
		if (client.type != ST_EMPTY) {
			if (client.mapvote.length > 0) {
				if ([client.mapvote isEqual:map] &&
				    client.modevote == reqmode)
					yes++;
				else
					no++;
			} else
				no++;
		}
	}

	if (yes == 1 && no == 0)
		return true; // single player

	OFString *msg = [OFString
	    stringWithFormat:@"%@ suggests %@ on map %@ (set map to vote)",
	    clients[sender].name, modestr(reqmode), map];
	sendservmsg(msg);

	if (yes / (float)(yes + no) <= 0.5f)
		return false;

	sendservmsg(@"vote passed");
	resetvotes();
	return true;
}

// server side processing of updates: does very little and most state is tracked
// client only could be extended to move more gameplay to server (at expense of
// lag)

void
process(ENetPacket *packet, int sender) // sender may be -1
{
	if (ENET_NET_TO_HOST_16(*(ushort *)packet->data) !=
	    packet->dataLength) {
		disconnect_client(sender, @"packet length");
		return;
	}

	uchar *end = packet->data + packet->dataLength;
	uchar *p = packet->data + 2;
	char text[MAXTRANS];
	int cn = -1, type;

	while (p < end) {
		switch ((type = getint(p))) {
		case SV_TEXT:
			sgetstr();
			break;

		case SV_INITC2S:
			sgetstr();
			clients[cn].name = @(text);
			sgetstr();
			getint(p);
			break;

		case SV_MAPCHANGE: {
			sgetstr();
			int reqmode = getint(p);
			if (reqmode < 0)
				reqmode = 0;
			if (smapname.length > 0 && !mapreload &&
			    !vote(@(text), reqmode, sender))
				return;
			mapreload = false;
			mode = reqmode;
			minremain = mode & 1 ? 15 : 10;
			mapend = lastsec + minremain * 60;
			interm = 0;
			smapname = @(text);
			resetitems();
			sender = -1;
			break;
		}

		case SV_ITEMLIST: {
			int n;
			while ((n = getint(p)) != -1)
				if (notgotitems) {
					server_entity se = { false, 0 };
					while (sents.length() <= n)
						sents.add(se);
					sents[n].spawned = true;
				}
			notgotitems = false;
			break;
		}

		case SV_ITEMPICKUP: {
			int n = getint(p);
			pickup(n, getint(p), sender);
			break;
		}

		case SV_PING:
			send2(false, cn, SV_PONG, getint(p));
			break;

		case SV_POS: {
			cn = getint(p);
			if (cn < 0 || cn >= clients.count ||
			    clients[cn].type == ST_EMPTY) {
				disconnect_client(sender, @"client num");
				return;
			}
			int size = msgsizelookup(type);
			assert(size != -1);
			loopi(size - 2) getint(p);
			break;
		}

		case SV_SENDMAP: {
			sgetstr();
			int mapsize = getint(p);
			sendmaps(sender, @(text), mapsize, p);
			return;
		}

		case SV_RECVMAP:
			send(sender, recvmap(sender));
			return;

		// allows for new features that require no server updates
		case SV_EXT:
			for (int n = getint(p); n; n--)
				getint(p);
			break;

		default: {
			int size = msgsizelookup(type);
			if (size == -1) {
				disconnect_client(sender, @"tag type");
				return;
			}
			loopi(size - 1) getint(p);
		}
		}
	}

	if (p > end) {
		disconnect_client(sender, @"end of packet");
		return;
	}

	multicast(packet, sender);
}

void
send_welcome(int n)
{
	ENetPacket *packet =
	    enet_packet_create(NULL, MAXTRANS, ENET_PACKET_FLAG_RELIABLE);
	uchar *start = packet->data;
	uchar *p = start + 2;
	putint(p, SV_INITS2C);
	putint(p, n);
	putint(p, PROTOCOL_VERSION);
	putint(p, *smapname.UTF8String);
	sendstring(serverpassword, p);
	putint(p, clients.count > maxclients);
	if (smapname.length > 0) {
		putint(p, SV_MAPCHANGE);
		sendstring(smapname, p);
		putint(p, mode);
		putint(p, SV_ITEMLIST);
		loopv(sents) if (sents[i].spawned) putint(p, i);
		putint(p, -1);
	}
	*(ushort *)start = ENET_HOST_TO_NET_16(p - start);
	enet_packet_resize(packet, p - start);
	send(n, packet);
}

void
multicast(ENetPacket *packet, int sender)
{
	size_t count = clients.count;
	for (size_t i = 0; i < count; i++)
		if (i != sender)
			send(i, packet);
}

void
localclienttoserver(ENetPacket *packet)
{
	process(packet, 0);

	if (packet->referenceCount == 0)
		enet_packet_destroy(packet);
}

Client *
addclient()
{
	for (Client *client in clients)
		if (client.type == ST_EMPTY)
			return client;

	Client *client = [[Client alloc] init];

	if (clients == nil)
		clients = [[OFMutableArray alloc] init];

	[clients addObject:client];

	return client;
}

void
checkintermission()
{
	if (!minremain) {
		interm = lastsec + 10;
		mapend = lastsec + 1000;
	}
	send2(true, -1, SV_TIMEUP, minremain--);
}

void
startintermission()
{
	minremain = 0;
	checkintermission();
}

void
resetserverifempty()
{
	for (Client *client in clients)
		if (client.type != ST_EMPTY)
			return;

	[clients removeAllObjects];
	smapname = @"";
	resetvotes();
	resetitems();
	mode = 0;
	mapreload = false;
	minremain = 10;
	mapend = lastsec + minremain * 60;
	interm = 0;
}

int nonlocalclients = 0;
int lastconnect = 0;

void
serverslice(int seconds,
    unsigned int timeout) // main server update, called from cube main loop in
                          // sp, or dedicated server loop
{
	loopv(sents) // spawn entities when timer reached
	{
		if (sents[i].spawnsecs &&
		    (sents[i].spawnsecs -= seconds - lastsec) <= 0) {
			sents[i].spawnsecs = 0;
			sents[i].spawned = true;
			send2(true, -1, SV_ITEMSPAWN, i);
		}
	}

	lastsec = seconds;

	if ((mode > 1 || (mode == 0 && nonlocalclients)) &&
	    seconds > mapend - minremain * 60)
		checkintermission();
	if (interm && seconds > interm) {
		interm = 0;
		size_t i = 0;
		for (Client *client in clients) {
			if (client.type != ST_EMPTY) {
				// ask a client to trigger map reload
				send2(true, i, SV_MAPRELOAD, 0);
				mapreload = true;
				break;
			}

			i++;
		}
	}

	resetserverifempty();

	if (!isdedicated)
		return; // below is network only

	int numplayers = 0;
	for (Client *client in clients)
		if (client.type != ST_EMPTY)
			numplayers++;

	serverms(mode, numplayers, minremain, smapname, seconds,
	    clients.count >= maxclients);

	// display bandwidth stats, useful for server ops
	if (seconds - laststatus > 60) {
		nonlocalclients = 0;
		for (Client *client in clients)
			if (client.type == ST_TCPIP)
				nonlocalclients++;

		laststatus = seconds;
		if (nonlocalclients || bsend || brec)
			printf("status: %d remote clients, %.1f send, %.1f rec "
			       "(K/sec)\n",
			    nonlocalclients, bsend / 60.0f / 1024,
			    brec / 60.0f / 1024);
		bsend = brec = 0;
	}

	ENetEvent event;
	if (enet_host_service(serverhost, &event, timeout) > 0) {
		switch (event.type) {
		case ENET_EVENT_TYPE_CONNECT: {
			Client *c = addclient();
			c.type = ST_TCPIP;
			c.peer = event.peer;
			c.peer->data = (void *)(clients.count - 1);
			char hn[1024];
			c.hostname = (enet_address_get_host(
			                  &c.peer->address, hn, sizeof(hn)) == 0
			        ? @(hn)
			        : @"localhost");
			[OFStdOut
			    writeFormat:@"client connected (%@)\n", c.hostname];
			send_welcome(lastconnect = clients.count - 1);
			break;
		}
		case ENET_EVENT_TYPE_RECEIVE:
			brec += event.packet->dataLength;
			process(event.packet, (intptr_t)event.peer->data);
			if (event.packet->referenceCount == 0)
				enet_packet_destroy(event.packet);
			break;

		case ENET_EVENT_TYPE_DISCONNECT:
			if ((intptr_t)event.peer->data < 0)
				break;
			[OFStdOut writeFormat:@"disconnected client (%@)\n",
			          clients[(size_t)event.peer->data].hostname];
			clients[(size_t)event.peer->data].type = ST_EMPTY;
			send2(true, -1, SV_CDIS, (intptr_t)event.peer->data);
			event.peer->data = (void *)-1;
			break;
		}

		if (numplayers > maxclients)
			disconnect_client(lastconnect, @"maxclients reached");
	}
#ifndef _WIN32
	fflush(stdout);
#endif
}

void
cleanupserver()
{
	if (serverhost)
		enet_host_destroy(serverhost);
}

void
localdisconnect()
{
	for (Client *client in clients)
		if (client.type == ST_LOCAL)
			client.type = ST_EMPTY;
}

void
localconnect()
{
	Client *c = addclient();
	c.type = ST_LOCAL;
	c.hostname = @"local";
	send_welcome(clients.count - 1);
}

void
initserver(bool dedicated, int uprate, OFString *sdesc, OFString *ip,
    OFString *master, OFString *passwd, int maxcl)
{
	serverpassword = passwd;
	maxclients = maxcl;
	servermsinit(master ? master : @"wouter.fov120.com/cube/masterserver/",
	    sdesc, dedicated);

	if ((isdedicated = dedicated)) {
		ENetAddress address = { ENET_HOST_ANY, CUBE_SERVER_PORT };
		if (ip.length > 0 &&
		    enet_address_set_host(&address, ip.UTF8String) < 0)
			printf("WARNING: server ip not resolved");
		serverhost = enet_host_create(&address, MAXCLIENTS, 0, uprate);
		if (!serverhost)
			fatal(@"could not create server host\n");
		loopi(MAXCLIENTS) serverhost->peers[i].data = (void *)-1;
	}

	resetserverifempty();

	// do not return, this becomes main loop
	if (isdedicated) {
#ifdef _WIN32
		SetPriorityClass(GetCurrentProcess(), HIGH_PRIORITY_CLASS);
#endif
		printf("dedicated server started, waiting for "
		       "clients...\nCtrl-C to exit\n\n");
		atexit(cleanupserver);
		atexit(enet_deinitialize);
		for (;;)
			@autoreleasepool {
				serverslice(
				    /*enet_time_get_sec()*/ time(NULL), 5);
			}
	}
}
