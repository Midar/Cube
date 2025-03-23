// clientgame.cpp: core game related stuff

#include "cube.h"

#import "Command.h"
#import "DynamicEntity.h"
#import "Entity.h"
#import "Monster.h"
#import "OFString+Cube.h"

int nextmode = 0; // nextmode becomes gamemode after next map load
VAR(gamemode, 1, 0, 0);

COMMAND(mode, ARG_1INT, ^(int n) {
	addmsg(1, 2, SV_GAMEMODE, nextmode = n);
})

bool intermission = false;

DynamicEntity *player1;  // our client
OFMutableArray *players; // other clients

void
initPlayers()
{
	player1 = [[DynamicEntity alloc] init];
	players = [[OFMutableArray alloc] init];
}

VARP(sensitivity, 0, 10, 10000);
VARP(sensitivityscale, 1, 1, 10000);
VARP(invmouse, 0, 0, 1);

int lastmillis = 0;
int curtime = 10;
OFString *clientmap;

OFString *
getclientmap()
{
	return clientmap;
}

void
respawnself()
{
	spawnplayer(player1);
	showscores(false);
}

static void
arenacount(
    DynamicEntity *d, int *alive, int *dead, OFString **lastteam, bool *oneteam)
{
	if (d.state != CS_DEAD) {
		(*alive)++;
		if (![*lastteam isEqual:d.team])
			*oneteam = false;
		*lastteam = d.team;
	} else
		(*dead)++;
}

int arenarespawnwait = 0;
int arenadetectwait = 0;

void
arenarespawn()
{
	if (arenarespawnwait) {
		if (arenarespawnwait < lastmillis) {
			arenarespawnwait = 0;
			conoutf(@"new round starting... fight!");
			respawnself();
		}
	} else if (arenadetectwait == 0 || arenadetectwait < lastmillis) {
		arenadetectwait = 0;
		int alive = 0, dead = 0;
		OFString *lastteam = nil;
		bool oneteam = true;
		for (id player in players)
			if (player != [OFNull null])
				arenacount(
				    player, &alive, &dead, &lastteam, &oneteam);
		arenacount(player1, &alive, &dead, &lastteam, &oneteam);
		if (dead > 0 && (alive <= 1 || (m_teammode && oneteam))) {
			conoutf(
			    @"arena round is over! next round in 5 seconds...");
			if (alive)
				conoutf(
				    @"team %s is last man standing", lastteam);
			else
				conoutf(@"everyone died!");
			arenarespawnwait = lastmillis + 5000;
			arenadetectwait = lastmillis + 10000;
			player1.roll = 0;
		}
	}
}

extern int democlientnum;

void
otherplayers()
{
	[players enumerateObjectsUsingBlock:^(id player, size_t i, bool *stop) {
		if (player == [OFNull null])
			return;

		const int lagtime = lastmillis - [player lastUpdate];
		if (lagtime > 1000 && [player state] == CS_ALIVE) {
			[player setState:CS_LAGGED];
			return;
		}

		if (lagtime && [player state] != CS_DEAD &&
		    (!demoplayback || i != democlientnum))
			// use physics to extrapolate player position
			moveplayer(player, 2, false);
	}];
}

void
respawn()
{
	if (player1.state == CS_DEAD) {
		player1.attacking = false;
		if (m_arena) {
			conoutf(@"waiting for new round to start...");
			return;
		}
		if (m_sp) {
			nextmode = gamemode;
			changemap(clientmap);
			return;
		} // if we die in SP we try the same map again
		respawnself();
	}
}

int sleepwait = 0;
static OFString *sleepcmd = nil;
COMMAND(sleep, ARG_2STR, ^(OFString *msec, OFString *cmd) {
	sleepwait = msec.cube_intValue + lastmillis;
	sleepcmd = cmd;
})

void
updateworld(int millis) // main game update loop
{
	if (lastmillis) {
		curtime = millis - lastmillis;
		if (sleepwait && lastmillis > sleepwait) {
			sleepwait = 0;
			execute(sleepcmd, true);
		}
		physicsframe();
		checkquad(curtime);
		if (m_arena)
			arenarespawn();
		moveprojectiles((float)curtime);
		demoplaybackstep();
		if (!demoplayback) {
			if (getclientnum() >= 0)
				// only shoot when connected to server
				shoot(player1, &worldpos);
			// do this first, so we have most accurate information
			// when our player moves
			gets2c();
		}
		otherplayers();
		if (!demoplayback) {
			[Monster thinkAll];
			if (player1.state == CS_DEAD) {
				if (lastmillis - player1.lastAction < 2000) {
					player1.move = player1.strafe = 0;
					moveplayer(player1, 10, false);
				} else if (!m_arena && !m_sp &&
				    lastmillis - player1.lastAction > 10000)
					respawn();
			} else if (!intermission) {
				moveplayer(player1, 20, true);
				checkitems();
			}
			// do this last, to reduce the effective frame lag
			c2sinfo(player1);
		}
	}
	lastmillis = millis;
}

// brute force but effective way to find a free spawn spot in the map
void
entinmap(DynamicEntity *d)
{
	// try max 100 times
	for (int i = 0; i < 100; i++) {
		float dx = (rnd(21) - 10) / 10.0f * i; // increasing distance
		float dy = (rnd(21) - 10) / 10.0f * i;
		OFVector3D old = d.origin;
		d.origin = OFAddVectors3D(d.origin, OFMakeVector3D(dx, dy, 0));
		if (collide(d, true, 0, 0))
			return;
		d.origin = old;
	}
	conoutf(@"can't find entity spawn spot! (%d, %d)", (int)d.origin.x,
	    (int)d.origin.y);
	// leave ent at original pos, possibly stuck
}

int spawncycle = -1;
int fixspawn = 2;

// place at random spawn. also used by monsters!
void
spawnplayer(DynamicEntity *d)
{
	int r = fixspawn-- > 0 ? 4 : rnd(10) + 1;
	for (int i = 0; i < r; i++)
		spawncycle = findentity(PLAYERSTART, spawncycle + 1);
	if (spawncycle != -1) {
		d.origin = OFMakeVector3D(
		    ents[spawncycle].x, ents[spawncycle].y, ents[spawncycle].z);
		d.yaw = ents[spawncycle].attr1;
		d.pitch = 0;
		d.roll = 0;
	} else
		d.origin =
		    OFMakeVector3D((float)ssize / 2, (float)ssize / 2, 4);
	entinmap(d);
	[d resetToSpawnState];
	d.state = CS_ALIVE;
}

// movement input code

#define dir(name, v, d, s, os)                                    \
	COMMAND(name, ARG_DOWN, ^(bool isDown) {                  \
		player1.s = isDown;                               \
		player1.v = isDown ? d : (player1.os ? -(d) : 0); \
		player1.lastMove = lastmillis;                    \
	})

dir(backward, move, -1, k_down, k_up);
dir(forward, move, 1, k_up, k_down);
dir(left, strafe, 1, k_left, k_right);
dir(right, strafe, -1, k_right, k_left);

COMMAND(attack, ARG_DOWN, ^(bool on) {
	if (intermission)
		return;
	if (editmode)
		editdrag(on);
	else if ((player1.attacking = on))
		respawn();
})

COMMAND(jump, ARG_DOWN, ^(bool on) {
	if (!intermission && (player1.jumpNext = on))
		respawn();
})

COMMAND(showscores, ARG_DOWN, ^(bool isDown) {
	showscores(isDown);
})

void
fixplayer1range()
{
	const float MAXPITCH = 90.0f;
	if (player1.pitch > MAXPITCH)
		player1.pitch = MAXPITCH;
	if (player1.pitch < -MAXPITCH)
		player1.pitch = -MAXPITCH;
	while (player1.yaw < 0.0f)
		player1.yaw += 360.0f;
	while (player1.yaw >= 360.0f)
		player1.yaw -= 360.0f;
}

void
mousemove(int dx, int dy)
{
	if (player1.state == CS_DEAD || intermission)
		return;
	const float SENSF = 33.0f; // try match quake sens
	player1.yaw += (dx / SENSF) * (sensitivity / (float)sensitivityscale);
	player1.pitch -= (dy / SENSF) *
	    (sensitivity / (float)sensitivityscale) * (invmouse ? -1 : 1);
	fixplayer1range();
}

// damage arriving from the network, monsters, yourself, all ends up here.

void
selfdamage(int damage, int actor, DynamicEntity *act)
{
	if (player1.state != CS_ALIVE || editmode || intermission)
		return;
	damageblend(damage);
	demoblend(damage);
	// let armour absorb when possible
	int ad = damage * (player1.armourType + 1) * 20 / 100;
	if (ad > player1.armour)
		ad = player1.armour;
	player1.armour -= ad;
	damage -= ad;
	float droll = damage / 0.5f;
	player1.roll += player1.roll > 0
	    ? droll
	    : (player1.roll < 0
	              ? -droll
	              : (rnd(2) ? droll
	                        : -droll)); // give player a kick depending
	                                    // on amount of damage
	if ((player1.health -= damage) <= 0) {
		if (actor == -2) {
			conoutf(@"you got killed by %@!", act.name);
		} else if (actor == -1) {
			actor = getclientnum();
			conoutf(@"you suicided!");
			addmsg(1, 2, SV_FRAGS, --player1.frags);
		} else {
			DynamicEntity *a = getclient(actor);
			if (a != nil) {
				if (isteam(a.team, player1.team))
					conoutf(@"you got fragged by a "
					        @"teammate (%@)",
					    a.name);
				else
					conoutf(
					    @"you got fragged by %@", a.name);
			}
		}
		showscores(true);
		addmsg(1, 2, SV_DIED, actor);
		player1.lifeSequence++;
		player1.attacking = false;
		player1.state = CS_DEAD;
		player1.pitch = 0;
		player1.roll = 60;
		playsound(S_DIE1 + rnd(2), NULL);
		[player1 resetToSpawnState];
		player1.lastAction = lastmillis;
	} else
		playsound(S_PAIN6, NULL);
}

void
timeupdate(int timeremain)
{
	if (!timeremain) {
		intermission = true;
		player1.attacking = false;
		conoutf(@"intermission:");
		conoutf(@"game has ended!");
		showscores(true);
	} else {
		conoutf(@"time remaining: %d minutes", timeremain);
	}
}

DynamicEntity *
getclient(int cn) // ensure valid entity
{
	if (cn < 0 || cn >= MAXCLIENTS) {
		neterr(@"clientnum");
		return nil;
	}

	while (cn >= players.count)
		[players addObject:[OFNull null]];

	id player = players[cn];
	if (player == [OFNull null]) {
		player = [DynamicEntity entity];
		players[cn] = player;
	}

	return player;
}

void
setclient(int cn, id client)
{
	if (cn < 0 || cn >= MAXCLIENTS)
		neterr(@"clientnum");
	while (cn >= players.count)
		[players addObject:[OFNull null]];
	players[cn] = client;
}

void
initclient()
{
	clientmap = @"";
	initclientnet();
}

void
startmap(OFString *name) // called just after a map load
{
	if (netmapstart() && m_sp) {
		gamemode = 0;
		conoutf(@"coop sp not supported yet");
	}
	sleepwait = 0;
	[Monster resetAll];
	projreset();
	spawncycle = -1;
	spawnplayer(player1);
	player1.frags = 0;
	for (id player in players)
		if (player != [OFNull null])
			[player setFrags:0];
	resetspawns();
	clientmap = name;
	if (editmode)
		toggleedit();
	setvar(@"gamespeed", 100);
	setvar(@"fog", 180);
	setvar(@"fogcolour", 0x8099B3);
	showscores(false);
	intermission = false;
	Cube.sharedInstance.framesInMap = 0;
	conoutf(@"game mode is %@", modestr(gamemode));
}

COMMAND(map, ARG_1STR, ^(OFString *name) {
	changemap(name);
})
