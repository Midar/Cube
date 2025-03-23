// weapon.cpp: all shooting and effects code

#include "cube.h"

#import "DynamicEntity.h"
#import "Monster.h"
#import "OFString+Cube.h"
#import "Projectile.h"

static const int MONSTERDAMAGEFACTOR = 4;
#define SGRAYS 20
static const float SGSPREAD = 2;
static OFVector3D sg[SGRAYS];

static const struct {
	short sound, attackdelay, damage, projspeed, part, kickamount;
	OFString *name;
} guns[NUMGUNS] = {
	{ S_PUNCH1, 250, 50, 0, 0, 1, @"fist" },
	{ S_SG, 1400, 10, 0, 0, 20, @"shotgun" }, // *SGRAYS
	{ S_CG, 100, 30, 0, 0, 7, @"chaingun" },
	{ S_RLFIRE, 800, 120, 80, 0, 10, @"rocketlauncher" },
	{ S_RIFLE, 1500, 100, 0, 0, 30, @"rifle" },
	{ S_FLAUNCH, 200, 20, 50, 4, 1, @"fireball" },
	{ S_ICEBALL, 200, 40, 30, 6, 1, @"iceball" },
	{ S_SLIMEBALL, 200, 30, 160, 7, 1, @"slimeball" },
	{ S_PIGR1, 250, 50, 0, 0, 1, @"bite" },
};

void
selectgun(int a, int b, int c)
{
	if (a < -1 || b < -1 || c < -1 || a >= NUMGUNS || b >= NUMGUNS ||
	    c >= NUMGUNS)
		return;
	int s = player1.gunSelect;
	if (a >= 0 && s != a && player1.ammo[a])
		s = a;
	else if (b >= 0 && s != b && player1.ammo[b])
		s = b;
	else if (c >= 0 && s != c && player1.ammo[c])
		s = c;
	else if (s != GUN_RL && player1.ammo[GUN_RL])
		s = GUN_RL;
	else if (s != GUN_CG && player1.ammo[GUN_CG])
		s = GUN_CG;
	else if (s != GUN_SG && player1.ammo[GUN_SG])
		s = GUN_SG;
	else if (s != GUN_RIFLE && player1.ammo[GUN_RIFLE])
		s = GUN_RIFLE;
	else
		s = GUN_FIST;
	if (s != player1.gunSelect)
		playsoundc(S_WEAPLOAD);
	player1.gunSelect = s;
	// conoutf(@"%@ selected", (int)guns[s].name);
}

int
reloadtime(int gun)
{
	return guns[gun].attackdelay;
}

void
weapon(OFString *a1, OFString *a2, OFString *a3)
{
	selectgun((a1.length > 0 ? a1.cube_intValue : -1),
	    (a2.length > 0 ? a2.cube_intValue : -1),
	    (a3.length > 0 ? a3.cube_intValue : -1));
}
COMMAND(weapon, ARG_3STR)

// create random spread of rays for the shotgun
void
createrays(const OFVector3D *from, const OFVector3D *to)
{
	vdist(dist, dvec, *from, *to);
	float f = dist * SGSPREAD / 1000;
	for (int i = 0; i < SGRAYS; i++)
#define RNDD (rnd(101) - 50) * f
		sg[i] = OFAddVectors3D(*to, OFMakeVector3D(RNDD, RNDD, RNDD));
}

// if lineseg hits entity bounding box
static bool
intersect(DynamicEntity *d, const OFVector3D *from, const OFVector3D *to)
{
	OFVector3D v = *to, w = d.origin;
	const OFVector3D *p;
	v = OFSubtractVectors3D(v, *from);
	w = OFSubtractVectors3D(w, *from);
	float c1 = dotprod(w, v);

	if (c1 <= 0)
		p = from;
	else {
		float c2 = dotprod(v, v);
		if (c2 <= c1)
			p = to;
		else {
			v = OFMultiplyVector3D(v, c1 / c2);
			v = OFAddVectors3D(v, *from);
			p = &v;
		}
	}

	return (p->x <= d.origin.x + d.radius &&
	    p->x >= d.origin.x - d.radius && p->y <= d.origin.y + d.radius &&
	    p->y >= d.origin.y - d.radius && p->z <= d.origin.z + d.aboveEye &&
	    p->z >= d.origin.z - d.eyeHeight);
}

OFString *
playerincrosshair()
{
	if (demoplayback)
		return NULL;

	for (id player in players) {
		if (player == [OFNull null])
			continue;

		OFVector3D o = player1.origin;
		if (intersect(player, &o, &worldpos))
			return [player name];
	}

	return nil;
}

#define MAXPROJ 100
static Projectile *projs[MAXPROJ];

void
projreset()
{
	for (size_t i = 0; i < MAXPROJ; i++)
		projs[i].inuse = false;
}

void
newprojectile(const OFVector3D *from, const OFVector3D *to, float speed,
    bool local, DynamicEntity *owner, int gun)
{
	for (size_t i = 0; i < MAXPROJ; i++) {
		Projectile *p = projs[i];

		if (p == nil)
			projs[i] = p = [Projectile projectile];

		if (p.inuse)
			continue;

		p.inuse = true;
		p.o = *from;
		p.to = *to;
		p.speed = speed;
		p.local = local;
		p.owner = owner;
		p.gun = gun;
		return;
	}
}

static void
hit(int target, int damage, __kindof DynamicEntity *d, DynamicEntity *at)
{
	OFVector3D o = d.origin;
	if (d == player1)
		selfdamage(damage, at == player1 ? -1 : -2, at);
	else if ([d isKindOfClass:Monster.class])
		[d incurDamage:damage fromEntity:at];
	else {
		addmsg(1, 4, SV_DAMAGE, target, damage, d.lifeSequence);
		playsound(S_PAIN1 + rnd(5), &o);
	}
	particle_splash(3, damage, 1000, &o);
	demodamage(damage, &o);
}

const float RL_RADIUS = 5;
const float RL_DAMRAD = 7; // hack

static void
radialeffect(
    DynamicEntity *o, const OFVector3D *v, int cn, int qdam, DynamicEntity *at)
{
	if (o.state != CS_ALIVE)
		return;
	vdist(dist, temp, *v, o.origin);
	dist -= 2; // account for eye distance imprecision
	if (dist < RL_DAMRAD) {
		if (dist < 0)
			dist = 0;
		int damage = (int)(qdam * (1 - (dist / RL_DAMRAD)));
		hit(cn, damage, o, at);
		temp =
		    OFMultiplyVector3D(temp, (RL_DAMRAD - dist) * damage / 800);
		o.velocity = OFAddVectors3D(o.velocity, temp);
	}
}

static void
splash(Projectile *p, const OFVector3D *v, const OFVector3D *vold,
    int notthisplayer, int notthismonster, int qdam)
{
	particle_splash(0, 50, 300, v);
	p.inuse = false;

	if (p.gun != GUN_RL) {
		playsound(S_FEXPLODE, v);
		// no push?
	} else {
		playsound(S_RLHIT, v);
		newsphere(v, RL_RADIUS, 0);
		dodynlight(vold, v, 0, 0, p.owner);

		if (!p.local)
			return;

		radialeffect(player1, v, -1, qdam, p.owner);

		[players enumerateObjectsUsingBlock:^(
		    id player, size_t i, bool *stop) {
			if (i == notthisplayer)
				return;

			if (player == [OFNull null])
				return;

			radialeffect(player, v, i, qdam, p.owner);
		}];

		[Monster.monsters enumerateObjectsUsingBlock:^(
		    Monster *monster, size_t i, bool *stop) {
			if (i != notthismonster)
				radialeffect(monster, v, i, qdam, p.owner);
		}];
	}
}

static inline void
projdamage(DynamicEntity *o, Projectile *p, const OFVector3D *v, int i, int im,
    int qdam)
{
	if (o.state != CS_ALIVE)
		return;

	OFVector3D po = p.o;
	if (intersect(o, &po, v)) {
		splash(p, v, &po, i, im, qdam);
		hit(i, qdam, o, p.owner);
	}
}

void
moveprojectiles(float time)
{
	for (size_t i = 0; i < MAXPROJ; i++) {
		Projectile *p = projs[i];

		if (!p.inuse)
			continue;

		int qdam = guns[p.gun].damage * (p.owner.quadMillis ? 4 : 1);
		if ([p.owner isKindOfClass:Monster.class])
			qdam /= MONSTERDAMAGEFACTOR;
		vdist(dist, v, p.o, p.to);
		float dtime = dist * 1000 / p.speed;
		if (time > dtime)
			dtime = time;
		v = OFMultiplyVector3D(v, time / dtime);
		v = OFAddVectors3D(v, p.o);
		if (p.local) {
			for (id player in players)
				if (player != [OFNull null])
					projdamage(player, p, &v, i, -1, qdam);

			if (p.owner != player1)
				projdamage(player1, p, &v, -1, -1, qdam);

			for (Monster *monster in Monster.monsters)
				if (!vreject(monster.origin, v, 10.0f) &&
				    monster != p.owner)
					projdamage(monster, p, &v, -1, i, qdam);
		}
		if (p.inuse) {
			OFVector3D po = p.o;

			if (time == dtime)
				splash(p, &v, &po, -1, -1, qdam);
			else {
				if (p.gun == GUN_RL) {
					dodynlight(&po, &v, 0, 255, p.owner);
					particle_splash(5, 2, 200, &v);
				} else {
					particle_splash(1, 1, 200, &v);
					particle_splash(
					    guns[p.gun].part, 1, 1, &v);
				}
			}
		}
		p.o = v;
	}
}

// create visual effect from a shot
void
shootv(int gun, const OFVector3D *from, const OFVector3D *to, DynamicEntity *d,
    bool local)
{
	OFVector3D loc = d.origin;
	playsound(guns[gun].sound, d == player1 ? NULL : &loc);
	int pspeed = 25;
	switch (gun) {
	case GUN_FIST:
		break;

	case GUN_SG: {
		for (int i = 0; i < SGRAYS; i++)
			particle_splash(0, 5, 200, &sg[i]);
		break;
	}

	case GUN_CG:
		particle_splash(0, 100, 250, to);
		// particle_trail(1, 10, from, to);
		break;

	case GUN_RL:
	case GUN_FIREBALL:
	case GUN_ICEBALL:
	case GUN_SLIMEBALL:
		pspeed = guns[gun].projspeed;
		if ([d isKindOfClass:Monster.class])
			pspeed /= 2;
		newprojectile(from, to, (float)pspeed, local, d, gun);
		break;

	case GUN_RIFLE:
		particle_splash(0, 50, 200, to);
		particle_trail(1, 500, from, to);
		break;
	}
}

void
hitpush(int target, int damage, DynamicEntity *d, DynamicEntity *at,
    const OFVector3D *from, const OFVector3D *to)
{
	hit(target, damage, d, at);
	vdist(dist, v, *from, *to);
	v = OFMultiplyVector3D(v, damage / dist / 50);
	d.velocity = OFAddVectors3D(d.velocity, v);
}

void
raydamage(DynamicEntity *o, const OFVector3D *from, const OFVector3D *to,
    DynamicEntity *d, int i)
{
	if (o.state != CS_ALIVE)
		return;
	int qdam = guns[d.gunSelect].damage;
	if (d.quadMillis)
		qdam *= 4;
	if ([d isKindOfClass:Monster.class])
		qdam /= MONSTERDAMAGEFACTOR;
	if (d.gunSelect == GUN_SG) {
		int damage = 0;
		for (int r = 0; r < SGRAYS; r++)
			if (intersect(o, from, &sg[r]))
				damage += qdam;
		if (damage)
			hitpush(i, damage, o, d, from, to);
	} else if (intersect(o, from, to))
		hitpush(i, qdam, o, d, from, to);
}

void
shoot(DynamicEntity *d, const OFVector3D *targ)
{
	int attacktime = lastmillis - d.lastAction;
	if (attacktime < d.gunWait)
		return;
	d.gunWait = 0;
	if (!d.attacking)
		return;
	d.lastAction = lastmillis;
	d.lastAttackGun = d.gunSelect;
	if (!d.ammo[d.gunSelect]) {
		playsoundc(S_NOAMMO);
		d.gunWait = 250;
		d.lastAttackGun = -1;
		return;
	}
	if (d.gunSelect)
		d.ammo[d.gunSelect]--;
	OFVector3D from = d.origin;
	OFVector3D to = *targ;
	from.z -= 0.2f; // below eye

	vdist(dist, unitv, from, to);
	unitv = OFMultiplyVector3D(unitv, 1.0f / dist);
	OFVector3D kickback =
	    OFMultiplyVector3D(unitv, guns[d.gunSelect].kickamount * -0.01f);
	d.velocity = OFAddVectors3D(d.velocity, kickback);
	if (d.pitch < 80.0f)
		d.pitch += guns[d.gunSelect].kickamount * 0.05f;

	if (d.gunSelect == GUN_FIST || d.gunSelect == GUN_BITE) {
		unitv = OFMultiplyVector3D(unitv, 3); // punch range
		to = OFAddVectors3D(from, unitv);
	}
	if (d.gunSelect == GUN_SG)
		createrays(&from, &to);

	if (d.quadMillis && attacktime > 200)
		playsoundc(S_ITEMPUP);
	shootv(d.gunSelect, &from, &to, d, true);
	if (![d isKindOfClass:Monster.class])
		addmsg(1, 8, SV_SHOT, d.gunSelect, (int)(from.x * DMF),
		    (int)(from.y * DMF), (int)(from.z * DMF), (int)(to.x * DMF),
		    (int)(to.y * DMF), (int)(to.z * DMF));
	d.gunWait = guns[d.gunSelect].attackdelay;

	if (guns[d.gunSelect].projspeed)
		return;

	[players enumerateObjectsUsingBlock:^(id player, size_t i, bool *stop) {
		if (player != [OFNull null])
			raydamage(player, &from, &to, d, i);
	}];

	for (Monster *monster in Monster.monsters)
		if (monster != d)
			raydamage(monster, &from, &to, d, -2);

	if ([d isKindOfClass:Monster.class])
		raydamage(player1, &from, &to, d, -1);
}
