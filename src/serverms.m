// all server side masterserver and pinging functionality

#include "cube.h"

static ENetSocket mssock = ENET_SOCKET_NULL;

static void
httpgetsend(ENetAddress *ad, OFString *hostname, OFString *req, OFString *ref,
    OFString *agent)
{
	if (ad->host == ENET_HOST_ANY) {
		[OFStdOut writeFormat:@"looking up %@...\n", hostname];
		enet_address_set_host(ad, hostname.UTF8String);
		if (ad->host == ENET_HOST_ANY)
			return;
	}
	if (mssock != ENET_SOCKET_NULL)
		enet_socket_destroy(mssock);
	mssock = enet_socket_create(ENET_SOCKET_TYPE_STREAM, NULL);
	if (mssock == ENET_SOCKET_NULL) {
		printf("could not open socket\n");
		return;
	}
	if (enet_socket_connect(mssock, ad) < 0) {
		printf("could not connect\n");
		return;
	}
	ENetBuffer buf;
	OFString *httpget = [OFString stringWithFormat:@"GET %@ HTTP/1.0\n"
	                                               @"Host: %@\n"
	                                               @"Referer: %@\n"
	                                               @"User-Agent: %@\n\n",
	    req, hostname, ref, agent];
	buf.data = (void *)httpget.UTF8String;
	buf.dataLength = httpget.UTF8StringLength;
	[OFStdOut writeFormat:@"sending request to %@...\n", hostname];
	enet_socket_send(mssock, NULL, &buf, 1);
}

static void
httpgetrecieve(ENetBuffer *buf)
{
	if (mssock == ENET_SOCKET_NULL)
		return;
	enet_uint32 events = ENET_SOCKET_WAIT_RECEIVE;
	if (enet_socket_wait(mssock, &events, 0) >= 0 && events) {
		int len = enet_socket_receive(mssock, NULL, buf, 1);
		if (len <= 0) {
			enet_socket_destroy(mssock);
			mssock = ENET_SOCKET_NULL;
			return;
		}
		buf->data = ((char *)buf->data) + len;
		((char *)buf->data)[0] = 0;
		buf->dataLength -= len;
	}
}

static unsigned char *
stripheader(unsigned char *b)
{
	char *s = strstr((char *)b, "\n\r\n");
	if (!s)
		s = strstr((char *)b, "\n\n");
	return s ? (unsigned char *)s : b;
}

static ENetAddress masterserver = { ENET_HOST_ANY, 80 };
static int updmaster = 0;
static OFString *masterbase;
static OFString *masterpath;
static unsigned char masterrep[MAXTRANS];
static ENetBuffer masterb;

static void
updatemasterserver(int seconds)
{
	// send alive signal to masterserver every hour of uptime
	if (seconds > updmaster) {
		OFString *path = [OFString
		    stringWithFormat:@"%@register.do?action=add", masterpath];
		httpgetsend(&masterserver, masterbase, path, @"cubeserver",
		    @"Cube Server");
		masterrep[0] = 0;
		masterb.data = masterrep;
		masterb.dataLength = MAXTRANS - 1;
		updmaster = seconds + 60 * 60;
	}
}

static void
checkmasterreply()
{
	bool busy = mssock != ENET_SOCKET_NULL;
	httpgetrecieve(&masterb);
	if (busy && mssock == ENET_SOCKET_NULL)
		printf("masterserver reply: %s\n", stripheader(masterrep));
}

unsigned char *
retrieveservers(unsigned char *buf, int buflen)
{
	OFString *path =
	    [OFString stringWithFormat:@"%@retrieve.do?item=list", masterpath];
	httpgetsend(
	    &masterserver, masterbase, path, @"cubeserver", @"Cube Server");
	ENetBuffer eb;
	buf[0] = 0;
	eb.data = buf;
	eb.dataLength = buflen - 1;
	while (mssock != ENET_SOCKET_NULL)
		httpgetrecieve(&eb);
	return stripheader(buf);
}

static ENetSocket pongsock = ENET_SOCKET_NULL;
static OFString *serverdesc;

void
serverms(int mode, int numplayers, int minremain, OFString *smapname,
    int seconds, bool isfull)
{
	checkmasterreply();
	updatemasterserver(seconds);

	// reply all server info requests
	ENetBuffer buf;
	ENetAddress addr;
	unsigned char pong[MAXTRANS], *p;
	int len;
	enet_uint32 events = ENET_SOCKET_WAIT_RECEIVE;
	buf.data = pong;
	while (enet_socket_wait(pongsock, &events, 0) >= 0 && events) {
		buf.dataLength = sizeof(pong);
		len = enet_socket_receive(pongsock, &addr, &buf, 1);
		if (len < 0)
			return;
		p = &pong[len];
		putint(&p, PROTOCOL_VERSION);
		putint(&p, mode);
		putint(&p, numplayers);
		putint(&p, minremain);
		OFString *mname = [OFString stringWithFormat:@"%@%@",
		    (isfull ? @"[FULL] " : @""), smapname];
		sendstring(mname, &p);
		sendstring(serverdesc, &p);
		buf.dataLength = p - pong;
		enet_socket_send(pongsock, &addr, &buf, 1);
	}
}

void
servermsinit(OFString *master_, OFString *sdesc, bool listen)
{
	const char *master = master_.UTF8String;
	const char *mid = strstr(master, "/");
	if (!mid)
		mid = master;
	masterpath = @(mid);
	masterbase = [OFString stringWithUTF8String:master length:mid - master];
	serverdesc = sdesc;

	if (listen) {
		ENetAddress address = { ENET_HOST_ANY, CUBE_SERVINFO_PORT };
		pongsock =
		    enet_socket_create(ENET_SOCKET_TYPE_DATAGRAM, &address);
		if (pongsock == ENET_SOCKET_NULL)
			fatal(@"could not create server info socket\n");
	}
}
