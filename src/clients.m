// client.cpp, mostly network related client game code

#include "cube.h"

#import "Command.h"
#import "Player.h"

static ENetHost *clienthost = NULL;
static int connecting = 0;
static int connattempts = 0;
static int disconnecting = 0;
// our client id in the game
int clientnum = -1;
// whether we need to tell the other clients our stats
bool c2sinit = false;

int
getclientnum()
{
	return clientnum;
}

bool
multiplayer()
{
	// check not correct on listen server?
	if (clienthost)
		conoutf(@"operation not available in multiplayer");

	return clienthost != NULL;
}

bool
allowedittoggle()
{
	bool allow = !clienthost || gamemode == 1;

	if (!allow)
		conoutf(@"editing in multiplayer requires coopedit mode (1)");

	return allow;
}

VARF(rate, 0, 0, 25000,
    if (clienthost && (!rate || rate > 1000))
        enet_host_bandwidth_limit(clienthost, rate, rate));

void throttle();

VARF(throttle_interval, 0, 5, 30, throttle());
VARF(throttle_accel, 0, 2, 32, throttle());
VARF(throttle_decel, 0, 2, 32, throttle());

void
throttle()
{
	if (!clienthost || connecting)
		return;
	assert(ENET_PEER_PACKET_THROTTLE_SCALE == 32);
	enet_peer_throttle_configure(clienthost->peers,
	    throttle_interval * 1000, throttle_accel, throttle_decel);
}

static void
newname(OFString *name)
{
	c2sinit = false;

	if (name.length > 16)
		name = [name substringToIndex:16];

	Player.player1.name = name;
}

COMMAND(name, ARG_1STR, ^(OFString *name) {
	newname(name);
})

static void
newteam(OFString *name)
{
	c2sinit = false;

	if (name.length > 5)
		name = [name substringToIndex:5];

	Player.player1.team = name;
}

COMMAND(team, ARG_1STR, ^(OFString *name) {
	newteam(name);
})

void
writeclientinfo(OFStream *stream)
{
	[stream writeFormat:@"name \"%@\"\nteam \"%@\"\n", Player.player1.name,
	        Player.player1.team];
}

void
connects(OFString *servername)
{
	disconnect(true, false); // reset state
	addserver(servername);

	conoutf(@"attempting to connect to %@", servername);
	ENetAddress address = { ENET_HOST_ANY, CUBE_SERVER_PORT };
	if (enet_address_set_host(&address, servername.UTF8String) < 0) {
		conoutf(@"could not resolve server %@", servername);
		return;
	}

	clienthost = enet_host_create(NULL, 1, rate, rate);

	if (clienthost) {
		enet_host_connect(clienthost, &address, 1);
		enet_host_flush(clienthost);
		connecting = lastmillis;
		connattempts = 0;
	} else {
		conoutf(@"could not connect to server");
		disconnect(false, false);
	}
}

void
disconnect(bool onlyclean, bool async)
{
	if (clienthost) {
		if (!connecting && !disconnecting) {
			enet_peer_disconnect(clienthost->peers);
			enet_host_flush(clienthost);
			disconnecting = lastmillis;
		}
		if (clienthost->peers->state != ENET_PEER_STATE_DISCONNECTED) {
			if (async)
				return;
			enet_peer_reset(clienthost->peers);
		}
		enet_host_destroy(clienthost);
	}

	if (clienthost && !connecting)
		conoutf(@"disconnected");
	clienthost = NULL;
	connecting = 0;
	connattempts = 0;
	disconnecting = 0;
	clientnum = -1;
	c2sinit = false;
	Player.player1.lifeSequence = 0;
	[players removeAllObjects];

	localdisconnect();

	if (!onlyclean) {
		stop();
		localconnect();
	}
}

void
trydisconnect()
{
	if (!clienthost) {
		conoutf(@"not connected");
		return;
	}
	if (connecting) {
		conoutf(@"aborting connection attempt");
		disconnect(false, false);
		return;
	}
	conoutf(@"attempting to disconnect...");
	disconnect(0, !disconnecting);
}

static OFString *ctext;
void
toserver(OFString *text)
{
	conoutf(@"%@:\f %@", Player.player1.name, text);
	ctext = text;
}

COMMAND(echo, ARG_VARI, ^(OFString *text) {
	conoutf(@"%@", text);
})
COMMAND(say, ARG_VARI, ^(OFString *text) {
	toserver(text);
})
COMMAND(connect, ARG_1STR, ^(OFString *servername) {
	connects(servername);
})
COMMAND(disconnect, ARG_NONE, ^{
	trydisconnect();
})

// collect c2s messages conveniently

static OFMutableArray<OFData *> *messages;

void
addmsg(int rel, int num, int type, ...)
{
	if (demoplayback)
		return;
	if (num != msgsizelookup(type))
		fatal(@"inconsistant msg size for %d (%d != %d)", type, num,
		    msgsizelookup(type));
	if (messages.count == 100) {
		conoutf(@"command flood protection (type %d)", type);
		return;
	}

	OFMutableData *msg = [OFMutableData dataWithItemSize:sizeof(int)
	                                            capacity:num + 2];
	[msg addItem:&num];
	[msg addItem:&rel];
	[msg addItem:&type];

	va_list marker;
	va_start(marker, type);
	for (int i = 0; i < num - 1; i++) {
		int tmp = va_arg(marker, int);
		[msg addItem:&tmp];
	}
	va_end(marker);
	[msg makeImmutable];

	if (messages == nil)
		messages = [[OFMutableArray alloc] init];

	[messages addObject:msg];
}

void
server_err()
{
	conoutf(@"server network error, disconnecting...");
	disconnect(false, false);
}

int lastupdate = 0, lastping = 0;
OFString *toservermap;
bool senditemstoserver =
    false; // after a map change, since server doesn't have map data

OFString *clientpassword;
COMMAND(password, ARG_1STR, ^(OFString *p) {
	clientpassword = p;
})

bool
netmapstart()
{
	senditemstoserver = true;
	return clienthost != NULL;
}

void
initclientnet()
{
	ctext = @"";
	toservermap = @"";
	clientpassword = @"";
	newname(@"unnamed");
	newteam(@"red");
}

void
sendpackettoserv(void *packet)
{
	if (clienthost) {
		enet_host_broadcast(clienthost, 0, (ENetPacket *)packet);
		enet_host_flush(clienthost);
	} else
		localclienttoserver((ENetPacket *)packet);
}

// send update to the server
void
c2sinfo(Player *d)
{
	if (clientnum < 0)
		return; // we haven't had a welcome message from the server yet
	if (lastmillis - lastupdate < 40)
		return; // don't update faster than 25fps
	ENetPacket *packet = enet_packet_create(NULL, MAXTRANS, 0);
	unsigned char *start = packet->data;
	unsigned char *p = start + 2;
	bool serveriteminitdone = false;
	// suggest server to change map
	if (toservermap.length > 0) {
		// do this exclusively as map change may invalidate rest of
		// update
		packet->flags = ENET_PACKET_FLAG_RELIABLE;
		putint(&p, SV_MAPCHANGE);
		sendstring(toservermap, &p);
		toservermap = @"";
		putint(&p, nextmode);
	} else {
		putint(&p, SV_POS);
		putint(&p, clientnum);
		// quantize coordinates to 1/16th of a cube, between 1 and 3
		// bytes
		putint(&p, (int)(d.origin.x * DMF));
		putint(&p, (int)(d.origin.y * DMF));
		putint(&p, (int)(d.origin.z * DMF));
		putint(&p, (int)(d.yaw * DAF));
		putint(&p, (int)(d.pitch * DAF));
		putint(&p, (int)(d.roll * DAF));
		// quantize to 1/100, almost always 1 byte
		putint(&p, (int)(d.velocity.x * DVF));
		putint(&p, (int)(d.velocity.y * DVF));
		putint(&p, (int)(d.velocity.z * DVF));
		// pack rest in 1 byte: strafe:2, move:2, onFloor:1, state:3
		putint(&p,
		    (d.strafe & 3) | ((d.move & 3) << 2) |
		        (((int)d.onFloor) << 4) |
		        ((editmode ? CS_EDITING : d.state) << 5));

		if (senditemstoserver) {
			packet->flags = ENET_PACKET_FLAG_RELIABLE;
			putint(&p, SV_ITEMLIST);
			if (!m_noitems)
				putitems(&p);
			putint(&p, -1);
			senditemstoserver = false;
			serveriteminitdone = true;
		}
		// player chat, not flood protected for now
		if (ctext.length > 0) {
			packet->flags = ENET_PACKET_FLAG_RELIABLE;
			putint(&p, SV_TEXT);
			sendstring(ctext, &p);
			ctext = @"";
		}
		// tell other clients who I am
		if (!c2sinit) {
			packet->flags = ENET_PACKET_FLAG_RELIABLE;
			c2sinit = true;
			putint(&p, SV_INITC2S);
			sendstring(Player.player1.name, &p);
			sendstring(Player.player1.team, &p);
			putint(&p, Player.player1.lifeSequence);
		}
		for (OFData *msg in messages) {
			// send messages collected during the previous frames
			if (*(int *)[msg itemAtIndex:1])
				packet->flags = ENET_PACKET_FLAG_RELIABLE;
			for (int i = 0; i < *(int *)[msg itemAtIndex:0]; i++)
				putint(&p, *(int *)[msg itemAtIndex:i + 2]);
		}
		[messages removeAllObjects];
		if (lastmillis - lastping > 250) {
			putint(&p, SV_PING);
			putint(&p, lastmillis);
			lastping = lastmillis;
		}
	}
	*(unsigned short *)start = ENET_HOST_TO_NET_16(p - start);
	enet_packet_resize(packet, p - start);
	incomingdemodata(start, p - start, true);
	if (clienthost) {
		enet_host_broadcast(clienthost, 0, packet);
		enet_host_flush(clienthost);
	} else
		localclienttoserver(packet);
	lastupdate = lastmillis;
	if (serveriteminitdone)
		loadgamerest(); // hack
}

void
gets2c() // get updates from the server
{
	ENetEvent event;

	if (!clienthost)
		return;

	if (connecting && lastmillis / 3000 > connecting / 3000) {
		conoutf(@"attempting to connect...");
		connecting = lastmillis;

		if (++connattempts > 3) {
			conoutf(@"could not connect to server");
			disconnect(false, false);
			return;
		}
	}

	while (clienthost != NULL &&
	    enet_host_service(clienthost, &event, 0) > 0) {
		switch (event.type) {
		case ENET_EVENT_TYPE_CONNECT:
			conoutf(@"connected to server");
			connecting = 0;
			throttle();
			break;
		case ENET_EVENT_TYPE_RECEIVE:
			if (disconnecting)
				conoutf(@"attempting to disconnect...");
			else
				localservertoclient(event.packet->data,
				    event.packet->dataLength);
			enet_packet_destroy(event.packet);
			break;
		case ENET_EVENT_TYPE_DISCONNECT:
			if (disconnecting)
				disconnect(false, false);
			else
				server_err();
			return;
		case ENET_EVENT_TYPE_NONE:
			break;
		}
	}
}
