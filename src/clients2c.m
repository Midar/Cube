// client processing of the incoming network stream

#include "cube.h"

#import "DynamicEntity.h"
#import "Entity.h"

extern int clientnum;
extern bool c2sinit, senditemstoserver;
extern OFString *toservermap;
extern OFString *clientpassword;

void
neterr(OFString *s)
{
	conoutf(@"illegal network message (%@)", s);
	disconnect(false, false);
}

void
changemapserv(OFString *name, int mode) // forced map change from the server
{
	gamemode = mode;
	load_world(name);
}

void
changemap(OFString *name) // request map change, server may ignore
{
	toservermap = name;
}

// update the position of other clients in the game in our world
// don't care if he's in the scenery or other players,
// just don't overlap with our client

void
updatepos(DynamicEntity *d)
{
	const float r = player1.radius + d.radius;
	const float dx = player1.origin.x - d.origin.x;
	const float dy = player1.origin.y - d.origin.y;
	const float dz = player1.origin.z - d.origin.z;
	const float rz = player1.aboveEye + d.eyeHeight;
	const float fx = (float)fabs(dx), fy = (float)fabs(dy),
	            fz = (float)fabs(dz);
	if (fx < r && fy < r && fz < rz && d.state != CS_DEAD) {
		if (fx < fy)
			// push aside
			d.origin = OFAddVectors3D(d.origin,
			    OFMakeVector3D(
			        0, (dy < 0 ? r - fy : -(r - fy)), 0));
		else
			d.origin = OFAddVectors3D(d.origin,
			    OFMakeVector3D(
			        (dx < 0 ? r - fx : -(r - fx)), 0, 0));
	}
	int lagtime = lastmillis - d.lastUpdate;
	if (lagtime) {
		d.lag = (d.lag * 5 + lagtime) / 6;
		d.lastUpdate = lastmillis;
	}
}

// processes any updates from the server
void
localservertoclient(unsigned char *buf, int len)
{
	if (ENET_NET_TO_HOST_16(*(unsigned short *)buf) != len)
		neterr(@"packet length");
	incomingdemodata(buf, len, false);

	unsigned char *end = buf + len;
	unsigned char *p = buf + 2;
	char text[MAXTRANS];
	int cn = -1, type;
	DynamicEntity *d = nil;
	bool mapchanged = false;

	while (p < end)
		switch (type = getint(&p)) {
		case SV_INITS2C: // welcome messsage from the server
		{
			cn = getint(&p);
			int prot = getint(&p);
			if (prot != PROTOCOL_VERSION) {
				conoutf(@"you are using a different game "
				        @"protocol (you: %d, server: %d)",
				    PROTOCOL_VERSION, prot);
				disconnect(false, false);
				return;
			}
			toservermap = @"";
			clientnum = cn; // we are now fully connected
			if (!getint(&p))
				// we are the first client on this server, set
				// map
				toservermap = getclientmap();
			sgetstr();
			if (text[0] &&
			    strcmp(text, clientpassword.UTF8String)) {
				conoutf(@"you need to set the correct password "
				        @"to join this server!");
				disconnect(false, false);
				return;
			}
			if (getint(&p) == 1)
				conoutf(@"server is FULL, disconnecting..");
			break;
		}

		case SV_POS: {
			// position of another client
			cn = getint(&p);
			d = getclient(cn);
			if (d == nil)
				return;
			OFVector3D tmp;
			tmp.x = getint(&p) / DMF;
			tmp.y = getint(&p) / DMF;
			tmp.z = getint(&p) / DMF;
			d.origin = tmp;
			d.yaw = getint(&p) / DAF;
			d.pitch = getint(&p) / DAF;
			d.roll = getint(&p) / DAF;
			tmp.x = getint(&p) / DVF;
			tmp.y = getint(&p) / DVF;
			tmp.z = getint(&p) / DVF;
			d.velocity = tmp;
			int f = getint(&p);
			d.strafe = (f & 3) == 3 ? -1 : f & 3;
			f >>= 2;
			d.move = (f & 3) == 3 ? -1 : f & 3;
			d.onFloor = (f >> 2) & 1;
			int state = f >> 3;
			if (state == CS_DEAD && d.state != CS_DEAD)
				d.lastAction = lastmillis;
			d.state = state;
			if (!demoplayback)
				updatepos(d);
			break;
		}

		case SV_SOUND: {
			OFVector3D loc = d.origin;
			playsound(getint(&p), &loc);
			break;
		}

		case SV_TEXT:
			sgetstr();
			conoutf(@"%@:\f %s", d.name, text);
			break;

		case SV_MAPCHANGE:
			sgetstr();
			changemapserv(@(text), getint(&p));
			mapchanged = true;
			break;

		case SV_ITEMLIST: {
			int n;
			if (mapchanged) {
				senditemstoserver = false;
				resetspawns();
			}
			while ((n = getint(&p)) != -1)
				if (mapchanged)
					setspawn(n, true);
			break;
		}
		// server requests next map
		case SV_MAPRELOAD: {
			getint(&p);
			OFString *nextmapalias = [OFString
			    stringWithFormat:@"nextmap_%@", getclientmap()];
			OFString *map =
			    getalias(nextmapalias); // look up map in the cycle
			changemap(map != nil ? map : getclientmap());
			break;
		}

		// another client either connected or changed name/team
		case SV_INITC2S: {
			sgetstr();
			if (d.name.length > 0) {
				// already connected
				if (![d.name isEqual:@(text)])
					conoutf(@"%@ is now known as %s",
					    d.name, text);
			} else {
				// new client

				// send new players my info again
				c2sinit = false;
				conoutf(@"connected: %s", text);
			}
			d.name = @(text);
			sgetstr();
			d.team = @(text);
			d.lifeSequence = getint(&p);
			break;
		}

		case SV_CDIS:
			cn = getint(&p);
			if ((d = getclient(cn)) == nil)
				break;
			conoutf(@"player %@ disconnected",
			    d.name.length ? d.name : @"[incompatible client]");
			players[cn] = [OFNull null];
			break;

		case SV_SHOT: {
			int gun = getint(&p);
			OFVector3D s, e;
			s.x = getint(&p) / DMF;
			s.y = getint(&p) / DMF;
			s.z = getint(&p) / DMF;
			e.x = getint(&p) / DMF;
			e.y = getint(&p) / DMF;
			e.z = getint(&p) / DMF;
			if (gun == GUN_SG)
				createrays(&s, &e);
			shootv(gun, &s, &e, d, false);
			break;
		}

		case SV_DAMAGE: {
			int target = getint(&p);
			int damage = getint(&p);
			int ls = getint(&p);
			if (target == clientnum) {
				if (ls == player1.lifeSequence)
					selfdamage(damage, cn, d);
			} else {
				OFVector3D loc = getclient(target).origin;
				playsound(S_PAIN1 + rnd(5), &loc);
			}
			break;
		}

		case SV_DIED: {
			int actor = getint(&p);
			if (actor == cn) {
				conoutf(@"%@ suicided", d.name);
			} else if (actor == clientnum) {
				int frags;
				if (isteam(player1.team, d.team)) {
					frags = -1;
					conoutf(@"you fragged a teammate (%@)",
					    d.name);
				} else {
					frags = 1;
					conoutf(@"you fragged %@", d.name);
				}
				addmsg(
				    1, 2, SV_FRAGS, (player1.frags += frags));
			} else {
				DynamicEntity *a = getclient(actor);
				if (a != nil) {
					if (isteam(a.team, d.name))
						conoutf(@"%@ fragged his "
						        @"teammate (%@)",
						    a.name, d.name);
					else
						conoutf(@"%@ fragged %@",
						    a.name, d.name);
				}
			}
			OFVector3D loc = d.origin;
			playsound(S_DIE1 + rnd(2), &loc);
			d.lifeSequence++;
			break;
		}

		case SV_FRAGS:
			[players[cn] setFrags:getint(&p)];
			break;

		case SV_ITEMPICKUP:
			setspawn(getint(&p), false);
			getint(&p);
			break;

		case SV_ITEMSPAWN: {
			unsigned int i = getint(&p);
			setspawn(i, true);
			if (i >= ents.count)
				break;
			OFVector3D v =
			    OFMakeVector3D(ents[i].x, ents[i].y, ents[i].z);
			playsound(S_ITEMSPAWN, &v);
			break;
		}
		// server acknowledges that I picked up this item
		case SV_ITEMACC:
			realpickup(getint(&p), player1);
			break;

		case SV_EDITH: // coop editing messages, should be extended to
		               // include all possible editing ops
		case SV_EDITT:
		case SV_EDITS:
		case SV_EDITD:
		case SV_EDITE: {
			int x = getint(&p);
			int y = getint(&p);
			int xs = getint(&p);
			int ys = getint(&p);
			int v = getint(&p);
			struct block b = { x, y, xs, ys };
			switch (type) {
			case SV_EDITH:
				editheightxy(v != 0, getint(&p), &b);
				break;
			case SV_EDITT:
				edittexxy(v, getint(&p), &b);
				break;
			case SV_EDITS:
				edittypexy(v, &b);
				break;
			case SV_EDITD:
				setvdeltaxy(v, &b);
				break;
			case SV_EDITE:
				editequalisexy((v != 0), &b);
				break;
			}
			break;
		}

		case SV_EDITENT: // coop edit of ent
		{
			unsigned int i = getint(&p);

			while (ents.count <= i) {
				Entity *e = [Entity entity];
				e.type = NOTUSED;
				[ents addObject:e];
			}

			int to = ents[i].type;
			ents[i].type = getint(&p);
			ents[i].x = getint(&p);
			ents[i].y = getint(&p);
			ents[i].z = getint(&p);
			ents[i].attr1 = getint(&p);
			ents[i].attr2 = getint(&p);
			ents[i].attr3 = getint(&p);
			ents[i].attr4 = getint(&p);
			ents[i].spawned = false;
			if (ents[i].type == LIGHT || to == LIGHT)
				calclight();
			break;
		}

		case SV_PING:
			getint(&p);
			break;

		case SV_PONG:
			addmsg(0, 2, SV_CLIENTPING,
			    player1.ping =
			        (player1.ping * 5 + lastmillis - getint(&p)) /
			        6);
			break;

		case SV_CLIENTPING:
			[players[cn] setPing:getint(&p)];
			break;

		case SV_GAMEMODE:
			nextmode = getint(&p);
			break;

		case SV_TIMEUP:
			timeupdate(getint(&p));
			break;

		case SV_RECVMAP: {
			sgetstr();
			conoutf(@"received map \"%s\" from server, reloading..",
			    text);
			int mapsize = getint(&p);
			OFString *string = @(text);
			writemap(string, mapsize, p);
			p += mapsize;
			changemapserv(string, gamemode);
			break;
		}

		case SV_SERVMSG:
			sgetstr();
			conoutf(@"%s", text);
			break;

		case SV_EXT: // so we can messages without breaking previous
		             // clients/servers, if necessary
		{
			for (int n = getint(&p); n; n--)
				getint(&p);
			break;
		}

		default:
			neterr(@"type");
			return;
		}
}
