// physics.cpp: no physics books were hurt nor consulted in the construction of
// this code. All physics computations and constants were invented on the fly
// and simply tweaked until they "felt right", and have no basis in reality.
// Collision detection is simplistic but very robust (uses discrete steps at
// fixed fps).

#include "cube.h"

#import "DynamicEntity.h"
#import "Entity.h"
#import "MapModelInfo.h"

// collide with player or monster
static bool
plcollide(
    DynamicEntity *d, DynamicEntity *o, float *headspace, float *hi, float *lo)
{
	if (o.state != CS_ALIVE)
		return true;

	const float r = o.radius + d.radius;
	if (fabs(o.origin.x - d.origin.x) < r &&
	    fabs(o.origin.y - d.origin.y) < r) {
		if (d.origin.z - d.eyeHeight < o.origin.z - o.eyeHeight) {
			if (o.origin.z - o.eyeHeight < *hi)
				*hi = o.origin.z - o.eyeHeight - 1;
		} else if (o.origin.z + o.aboveEye > *lo)
			*lo = o.origin.z + o.aboveEye + 1;

		if (fabs(o.origin.z - d.origin.z) < o.aboveEye + d.eyeHeight)
			return false;
		if (d.monsterState)
			return false; // hack
			              //
		*headspace = d.origin.z - o.origin.z - o.aboveEye - d.eyeHeight;
		if (*headspace < 0)
			*headspace = 10;
	}

	return true;
}

// recursively collide with a mipmapped corner cube
static bool
cornertest(int mip, int x, int y, int dx, int dy, int *bx, int *by, int *bs)
{
	struct sqr *w = wmip[mip];
	int sz = ssize >> mip;
	bool stest =
	    SOLID(SWS(w, x + dx, y, sz)) && SOLID(SWS(w, x, y + dy, sz));
	mip++;
	x /= 2;
	y /= 2;
	if (SWS(wmip[mip], x, y, ssize >> mip)->type == CORNER) {
		*bx = x << mip;
		*by = y << mip;
		*bs = 1 << mip;
		return cornertest(mip, x, y, dx, dy, bx, by, bs);
	}
	return stest;
}

// collide with a mapmodel
static void
mmcollide(DynamicEntity *d, float *hi, float *lo)
{
	for (Entity *e in ents) {
		if (e.type != MAPMODEL)
			continue;

		MapModelInfo *mmi = getmminfo(e.attr2);
		if (mmi == nil || !mmi.h)
			continue;

		const float r = mmi.rad + d.radius;
		if (fabs(e.x - d.origin.x) < r && fabs(e.y - d.origin.y) < r) {
			float mmz =
			    (float)(S(e.x, e.y)->floor + mmi.zoff + e.attr3);

			if (d.origin.z - d.eyeHeight < mmz) {
				if (mmz < *hi)
					*hi = mmz;
			} else if (mmz + mmi.h > *lo)
				*lo = mmz + mmi.h;
		}
	}
}

// all collision happens here
// spawn is a dirty side effect used in spawning
// drop & rise are supplied by the physics below to indicate gravity/push for
// current mini-timestep

bool
collide(DynamicEntity *d, bool spawn, float drop, float rise)
{
	// figure out integer cube rectangle this entity covers in map
	const float fx1 = d.origin.x - d.radius;
	const float fy1 = d.origin.y - d.radius;
	const float fx2 = d.origin.x + d.radius;
	const float fy2 = d.origin.y + d.radius;
	const int x1 = fast_f2nat(fx1);
	const int y1 = fast_f2nat(fy1);
	const int x2 = fast_f2nat(fx2);
	const int y2 = fast_f2nat(fy2);
	float hi = 127, lo = -128;
	// big monsters are afraid of heights, unless angry :)
	float minfloor = (d.monsterState && !spawn && d.health > 100)
	    ? d.origin.z - d.eyeHeight - 4.5f
	    : -1000.0f;

	for (int x = x1; x <= x2; x++) {
		for (int y = y1; y <= y2; y++) {
			// collide with map
			if (OUTBORD(x, y))
				return false;
			struct sqr *s = S(x, y);
			float ceil = s->ceil;
			float floor = s->floor;

			switch (s->type) {
			case SOLID:
				return false;
			case CORNER: {
				int bx = x, by = y, bs = 1;
				if ((x == x1 && y == y1 &&
				        cornertest(
				            0, x, y, -1, -1, &bx, &by, &bs) &&
				        fx1 - bx + fy1 - by <= bs) ||
				    (x == x2 && y == y1 &&
				        cornertest(
				            0, x, y, 1, -1, &bx, &by, &bs) &&
				        fx2 - bx >= fy1 - by) ||
				    (x == x1 && y == y2 &&
				        cornertest(
				            0, x, y, -1, 1, &bx, &by, &bs) &&
				        fx1 - bx <= fy2 - by) ||
				    (x == x2 && y == y2 &&
				        cornertest(
				            0, x, y, 1, 1, &bx, &by, &bs) &&
				        fx2 - bx + fy2 - by >= bs))
					return false;
				break;
			}
			// FIXME: too simplistic collision with slopes, makes
			// it feels like tiny stairs
			case FHF:
				floor -= (s->vdelta + S(x + 1, y)->vdelta +
				             S(x, y + 1)->vdelta +
				             S(x + 1, y + 1)->vdelta) /
				    16.0f;
				break;
			case CHF:
				ceil += (s->vdelta + S(x + 1, y)->vdelta +
				            S(x, y + 1)->vdelta +
				            S(x + 1, y + 1)->vdelta) /
				    16.0f;
			}

			if (ceil < hi)
				hi = ceil;
			if (floor > lo)
				lo = floor;
			if (floor < minfloor)
				return false;
		}
	}

	if (hi - lo < d.eyeHeight + d.aboveEye)
		return false;

	float headspace = 10;
	for (id player in players) {
		if (player == [OFNull null] || player == d)
			continue;
		if (!plcollide(d, player, &headspace, &hi, &lo))
			return false;
	}

	if (d != player1)
		if (!plcollide(d, player1, &headspace, &hi, &lo))
			return false;

	// this loop can be a performance bottleneck with many monster on a slow
	// cpu, should replace with a blockmap but seems mostly fast enough
	for (DynamicEntity *monster in getmonsters())
		if (!vreject(d.origin, monster.origin, 7.0f) && d != monster &&
		    !plcollide(d, monster, &headspace, &hi, &lo))
			return false;

	headspace -= 0.01f;

	mmcollide(d, &hi, &lo); // collide with map models

	if (spawn) {
		// just drop to floor (sideeffect)
		d.origin =
		    OFMakeVector3D(d.origin.x, d.origin.y, lo + d.eyeHeight);
		d.onFloor = true;
	} else {
		const float space = d.origin.z - d.eyeHeight - lo;
		if (space < 0) {
			if (space > -0.01)
				// stick on step
				d.origin = OFMakeVector3D(
				    d.origin.x, d.origin.y, lo + d.eyeHeight);
			else if (space > -1.26f)
				// rise thru stair
				d.origin = OFAddVector3D(
				    d.origin, OFMakeVector3D(0, 0, rise));
			else
				return false;
		} else
			// gravity
			d.origin = OFSubtractVector3D(d.origin,
			    OFMakeVector3D(
			        0, 0, min(min(drop, space), headspace)));

		const float space2 = hi - (d.origin.z + d.aboveEye);
		if (space2 < 0) {
			if (space2 < -0.1)
				return false; // hack alert!
			// glue to ceiling
			d.origin = OFMakeVector3D(
			    d.origin.x, d.origin.y, hi - d.aboveEye);
			// cancel out jumping velocity
			d.velocity =
			    OFMakeVector3D(d.velocity.x, d.velocity.y, 0);
		}

		d.onFloor = (d.origin.z - d.eyeHeight - lo < 0.001f);
	}

	return true;
}

float
rad(float x)
{
	return x * 3.14159f / 180;
}

VARP(maxroll, 0, 3, 20);

int physicsfraction = 0, physicsrepeat = 0;
const int MINFRAMETIME = 20; // physics always simulated at 50fps or better

void
physicsframe() // optimally schedule physics frames inside the graphics frames
{
	if (curtime >= MINFRAMETIME) {
		int faketime = curtime + physicsfraction;
		physicsrepeat = faketime / MINFRAMETIME;
		physicsfraction = faketime - physicsrepeat * MINFRAMETIME;
	} else {
		physicsrepeat = 1;
	}
}

// main physics routine, moves a player/monster for a curtime step
// moveres indicated the physics precision (which is lower for monsters and
// multiplayer prediction) local is false for multiplayer prediction

static void
moveplayer4(DynamicEntity *pl, int moveres, bool local, int curtime)
{
	const bool water = (hdr.waterlevel > pl.origin.z - 0.5f);
	const bool floating = (editmode && local) || pl.state == CS_EDITING;

	OFVector3D d; // vector of direction we ideally want to move in

	d.x = (float)(pl.move * cos(rad(pl.yaw - 90)));
	d.y = (float)(pl.move * sin(rad(pl.yaw - 90)));
	d.z = 0;

	if (floating || water) {
		d.x *= (float)cos(rad(pl.pitch));
		d.y *= (float)cos(rad(pl.pitch));
		d.z = (float)(pl.move * sin(rad(pl.pitch)));
	}

	d.x += (float)(pl.strafe * cos(rad(pl.yaw - 180)));
	d.y += (float)(pl.strafe * sin(rad(pl.yaw - 180)));

	const float speed = curtime / (water ? 2000.0f : 1000.0f) * pl.maxSpeed;
	const float friction =
	    water ? 20.0f : (pl.onFloor || floating ? 6.0f : 30.0f);

	const float fpsfric = friction / curtime * 20.0f;

	// slowly apply friction and direction to
	// velocity, gives a smooth movement
	vmul(pl.velocity, fpsfric - 1);
	vadd(pl.velocity, d);
	vdiv(pl.velocity, fpsfric);
	d = pl.velocity;
	vmul(d, speed); // d is now frametime based velocity vector

	pl.blocked = false;
	pl.moving = true;

	if (floating) {
		// just apply velocity
		vadd(pl.origin, d);
		if (pl.jumpNext) {
			pl.jumpNext = false;
			pl.velocity =
			    OFMakeVector3D(pl.velocity.x, pl.velocity.y, 2);
		}
	} else {
		// apply velocity with collision
		if (pl.onFloor || water) {
			if (pl.jumpNext) {
				pl.jumpNext = false;
				// physics impulse upwards
				pl.velocity = OFMakeVector3D(
				    pl.velocity.x, pl.velocity.y, 1.7);
				// dampen velocity change even harder, gives
				// correct water feel
				if (water)
					pl.velocity = OFMakeVector3D(
					    pl.velocity.x / 8,
					    pl.velocity.y / 8, pl.velocity.z);
				if (local)
					playsoundc(S_JUMP);
				else if (pl.monsterState) {
					OFVector3D loc = pl.origin;
					playsound(S_JUMP, &loc);
				}
			} else if (pl.timeInAir > 800) {
				// if we land after long time must have been a
				// high jump, make thud sound
				if (local)
					playsoundc(S_LAND);
				else if (pl.monsterState) {
					OFVector3D loc = pl.origin;
					playsound(S_LAND, &loc);
				}
			}

			pl.timeInAir = 0;
		} else
			pl.timeInAir += curtime;

		const float gravity = 20;
		const float f = 1.0f / moveres;
		// incorrect, but works fine
		float dropf = ((gravity - 1) + pl.timeInAir / 15.0f);
		// float slowly down in water
		if (water) {
			dropf = 5;
			pl.timeInAir = 0;
		}
		// at high fps, gravity kicks in too fast
		const float drop = dropf * curtime / gravity / 100 / moveres;
		// extra smoothness when lifting up stairs
		const float rise = speed / moveres / 1.2f;

		loopi(moveres) // discrete steps collision detection & sliding
		{
			// try move forward
			pl.origin = OFAddVector3D(pl.origin,
			    OFMakeVector3D(f * d.x, f * d.y, f * d.z));
			if (collide(pl, false, drop, rise))
				continue;

			// player stuck, try slide along y axis
			pl.blocked = true;
			pl.origin = OFSubtractVector3D(
			    pl.origin, OFMakeVector3D(f * d.x, 0, 0));
			if (collide(pl, false, drop, rise)) {
				d.x = 0;
				continue;
			}

			// still stuck, try x axis
			pl.origin = OFAddVector3D(
			    pl.origin, OFMakeVector3D(f * d.x, -f * d.y, 0));
			if (collide(pl, false, drop, rise)) {
				d.y = 0;
				continue;
			}

			// try just dropping down
			pl.moving = false;
			pl.origin = OFSubtractVector3D(
			    pl.origin, OFMakeVector3D(f * d.x, 0, 0));
			if (collide(pl, false, drop, rise)) {
				d.y = d.x = 0;
				continue;
			}

			pl.origin = OFSubtractVector3D(
			    pl.origin, OFMakeVector3D(0, 0, f * d.z));
			break;
		}
	}

	// detect wether player is outside map, used for skipping zbuffer clear
	// mostly

	if (pl.origin.x < 0 || pl.origin.x >= ssize || pl.origin.y < 0 ||
	    pl.origin.y > ssize)
		pl.outsideMap = true;
	else {
		struct sqr *s = S((int)pl.origin.x, (int)pl.origin.y);
		pl.outsideMap = SOLID(s) ||
		    pl.origin.z <
		        s->floor - (s->type == FHF ? s->vdelta / 4 : 0) ||
		    pl.origin.z >
		        s->ceil + (s->type == CHF ? s->vdelta / 4 : 0);
	}

	// automatically apply smooth roll when strafing

	if (pl.strafe == 0)
		pl.roll = pl.roll / (1 + (float)sqrt((float)curtime) / 25);
	else {
		pl.roll += pl.strafe * curtime / -30.0f;
		if (pl.roll > maxroll)
			pl.roll = (float)maxroll;
		if (pl.roll < -maxroll)
			pl.roll = (float)-maxroll;
	}

	// play sounds on water transitions

	if (!pl.inWater && water) {
		OFVector3D loc = pl.origin;
		playsound(S_SPLASH2, &loc);
		pl.velocity = OFMakeVector3D(pl.velocity.x, pl.velocity.y, 0);
	} else if (pl.inWater && !water) {
		OFVector3D loc = pl.origin;
		playsound(S_SPLASH1, &loc);
	}
	pl.inWater = water;
}

void
moveplayer(DynamicEntity *pl, int moveres, bool local)
{
	loopi(physicsrepeat) moveplayer4(pl, moveres, local,
	    i ? curtime / physicsrepeat
	      : curtime - curtime / physicsrepeat * (physicsrepeat - 1));
}
