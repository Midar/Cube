// entities.cpp: map entity related functions (pickup etc.)

#include "cube.h"

#import "DynamicEntity.h"
#import "Entity.h"
#import "MapModelInfo.h"

OFMutableArray<Entity *> *ents;

static OFString *entmdlnames[] = {
	@"shells",
	@"bullets",
	@"rockets",
	@"rrounds",
	@"health",
	@"boost",
	@"g_armour",
	@"y_armour",
	@"quad",
	@"teleporter",
};

int triggertime = 0;

void
initEntities()
{
	ents = [[OFMutableArray alloc] init];
}

void
renderent(Entity *e, OFString *mdlname, float z, float yaw, int frame = 0,
    int numf = 1, int basetime = 0, float speed = 10.0f)
{
	rendermodel(mdlname, frame, numf, 0, 1.1f,
	    OFMakeVector3D(e.x, z + S(e.x, e.y)->floor, e.y), yaw, 0, false,
	    1.0f, speed, 0, basetime);
}

void
renderentities()
{
	if (lastmillis > triggertime + 1000)
		triggertime = 0;

	for (Entity *e in ents) {
		if (e.type == MAPMODEL) {
			MapModelInfo *mmi = getmminfo(e.attr2);
			if (mmi == nil)
				continue;
			rendermodel(mmi.name, 0, 1, e.attr4, (float)mmi.rad,
			    OFMakeVector3D(e.x,
			        (float)S(e.x, e.y)->floor + mmi.zoff + e.attr3,
			        e.y),
			    (float)((e.attr1 + 7) - (e.attr1 + 7) % 15), 0,
			    false, 1.0f, 10.0f, mmi.snap);
		} else {
			if (OUTBORD(e.x, e.y))
				continue;
			if (e.type != CARROT) {
				if (!e.spawned && e.type != TELEPORT)
					continue;
				if (e.type < I_SHELLS || e.type > TELEPORT)
					continue;
				renderent(e, entmdlnames[e.type - I_SHELLS],
				    (float)(1 +
				        sin(lastmillis / 100.0 + e.x + e.y) /
				            20),
				    lastmillis / 10.0f);
			} else {
				switch (e.attr2) {
				case 1:
				case 3:
					continue;

				case 2:
				case 0:
					if (!e.spawned)
						continue;
					renderent(e, @"carrot",
					    (float)(1 +
					        sin(lastmillis / 100.0 + e.x +
					            e.y) /
					            20),
					    lastmillis /
					        (e.attr2 ? 1.0f : 10.0f));
					break;

				case 4:
					renderent(e, @"switch2", 3,
					    (float)e.attr3 * 90,
					    (!e.spawned && !triggertime) ? 1
					                                 : 0,
					    (e.spawned || !triggertime) ? 1 : 2,
					    triggertime, 1050.0f);
					break;
				case 5:
					renderent(e, @"switch1", -0.15f,
					    (float)e.attr3 * 90,
					    (!e.spawned && !triggertime) ? 30
					                                 : 0,
					    (e.spawned || !triggertime) ? 1
					                                : 30,
					    triggertime, 35.0f);
					break;
				}
			}
		}
	}
}

struct itemstat {
	int add, max, sound;
} itemstats[] = {
	{ 10, 50, S_ITEMAMMO },
	{ 20, 100, S_ITEMAMMO },
	{ 5, 25, S_ITEMAMMO },
	{ 5, 25, S_ITEMAMMO },
	{ 25, 100, S_ITEMHEALTH },
	{ 50, 200, S_ITEMHEALTH },
	{ 100, 100, S_ITEMARMOUR },
	{ 150, 150, S_ITEMARMOUR },
	{ 20000, 30000, S_ITEMPUP },
};

void
baseammo(int gun)
{
	player1.ammo[gun] = itemstats[gun - 1].add * 2;
}

// these two functions are called when the server acknowledges that you really
// picked up the item (in multiplayer someone may grab it before you).

static int
radditem(int i, int v)
{
	itemstat &is = itemstats[ents[i].type - I_SHELLS];
	ents[i].spawned = false;
	v += is.add;
	if (v > is.max)
		v = is.max;
	playsoundc(is.sound);
	return v;
}

void
realpickup(int n, DynamicEntity *d)
{
	switch (ents[n].type) {
	case I_SHELLS:
		d.ammo[1] = radditem(n, d.ammo[1]);
		break;
	case I_BULLETS:
		d.ammo[2] = radditem(n, d.ammo[2]);
		break;
	case I_ROCKETS:
		d.ammo[3] = radditem(n, d.ammo[3]);
		break;
	case I_ROUNDS:
		d.ammo[4] = radditem(n, d.ammo[4]);
		break;
	case I_HEALTH:
		d.health = radditem(n, d.health);
		break;
	case I_BOOST:
		d.health = radditem(n, d.health);
		break;

	case I_GREENARMOUR:
		d.armour = radditem(n, d.armour);
		d.armourtype = A_GREEN;
		break;

	case I_YELLOWARMOUR:
		d.armour = radditem(n, d.armour);
		d.armourtype = A_YELLOW;
		break;

	case I_QUAD:
		d.quadmillis = radditem(n, d.quadmillis);
		conoutf(@"you got the quad!");
		break;
	}
}

// these functions are called when the client touches the item

void
additem(int i, int v, int spawnsec)
{
	// don't pick up if not needed
	if (v < itemstats[ents[i].type - I_SHELLS].max) {
		// first ask the server for an ack even if someone else gets it
		// first
		addmsg(1, 3, SV_ITEMPICKUP, i, m_classicsp ? 100000 : spawnsec);
		ents[i].spawned = false;
	}
}

// also used by monsters
void
teleport(int n, DynamicEntity *d)
{
	int e = -1, tag = ents[n].attr1, beenhere = -1;
	for (;;) {
		e = findentity(TELEDEST, e + 1);
		if (e == beenhere || e < 0) {
			conoutf(@"no teleport destination for tag %d", tag);
			return;
		}
		if (beenhere < 0)
			beenhere = e;
		if (ents[e].attr2 == tag) {
			d.o = OFMakeVector3D(ents[e].x, ents[e].y, ents[e].z);
			d.yaw = ents[e].attr1;
			d.pitch = 0;
			d.vel = OFMakeVector3D(0, 0, 0);
			entinmap(d);
			playsoundc(S_TELEPORT);
			break;
		}
	}
}

void
pickup(int n, DynamicEntity *d)
{
	int np = 1;
	for (id player in players)
		if (player != [OFNull null])
			np++;
	// spawn times are dependent on number of players
	np = np < 3 ? 4 : (np > 4 ? 2 : 3);
	int ammo = np * 2;
	switch (ents[n].type) {
	case I_SHELLS:
		additem(n, d.ammo[1], ammo);
		break;
	case I_BULLETS:
		additem(n, d.ammo[2], ammo);
		break;
	case I_ROCKETS:
		additem(n, d.ammo[3], ammo);
		break;
	case I_ROUNDS:
		additem(n, d.ammo[4], ammo);
		break;
	case I_HEALTH:
		additem(n, d.health, np * 5);
		break;
	case I_BOOST:
		additem(n, d.health, 60);
		break;

	case I_GREENARMOUR:
		// (100h/100g only absorbs 166 damage)
		if (d.armourtype == A_YELLOW && d.armour > 66)
			break;
		additem(n, d.armour, 20);
		break;

	case I_YELLOWARMOUR:
		additem(n, d.armour, 20);
		break;

	case I_QUAD:
		additem(n, d.quadmillis, 60);
		break;

	case CARROT:
		ents[n].spawned = false;
		triggertime = lastmillis;
		trigger(ents[n].attr1, ents[n].attr2,
		    false); // needs to go over server for multiplayer
		break;

	case TELEPORT: {
		static int lastteleport = 0;
		if (lastmillis - lastteleport < 500)
			break;
		lastteleport = lastmillis;
		teleport(n, d);
		break;
	}

	case JUMPPAD: {
		static int lastjumppad = 0;
		if (lastmillis - lastjumppad < 300)
			break;
		lastjumppad = lastmillis;
		OFVector3D v = OFMakeVector3D((int)(char)ents[n].attr3 / 10.0f,
		    (int)(char)ents[n].attr2 / 10.0f, ents[n].attr1 / 10.0f);
		player1.vel = OFMakeVector3D(player1.vel.x, player1.vel.y, 0);
		vadd(player1.vel, v);
		playsoundc(S_JUMPPAD);
		break;
	}
	}
}

void
checkitems()
{
	if (editmode)
		return;

	[ents enumerateObjectsUsingBlock:^(Entity *e, size_t i, bool *stop) {
		if (e.type == NOTUSED)
			return;

		if (!e.spawned && e.type != TELEPORT && e.type != JUMPPAD)
			return;

		if (OUTBORD(e.x, e.y))
			return;

		OFVector3D v = OFMakeVector3D(
		    e.x, e.y, (float)S(e.x, e.y)->floor + player1.eyeheight);
		vdist(dist, t, player1.o, v);

		if (dist < (e.type == TELEPORT ? 4 : 2.5))
			pickup(i, player1);
	}];
}

void
checkquad(int time)
{
	if (player1.quadmillis && (player1.quadmillis -= time) < 0) {
		player1.quadmillis = 0;
		playsoundc(S_PUPOUT);
		conoutf(@"quad damage is over");
	}
}

void
putitems(uchar *&p) // puts items in network stream and also spawns them locally
{
	[ents enumerateObjectsUsingBlock:^(Entity *e, size_t i, bool *stop) {
		if ((e.type >= I_SHELLS && e.type <= I_QUAD) ||
		    e.type == CARROT) {
			putint(p, i);
			e.spawned = true;
		}
	}];
}

void
resetspawns()
{
	for (Entity *e in ents)
		e.spawned = false;
}
void
setspawn(uint i, bool on)
{
	if (i < (uint)ents.count)
		ents[i].spawned = on;
}
