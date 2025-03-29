// monster.cpp: implements AI for single player monsters, currently client only

#import "Monster.h"

#include "cube.h"

#import "Entity.h"
#import "Player.h"
#import "Variable.h"

static OFMutableArray<Monster *> *monsters;
static int nextmonster, spawnremain, numkilled, monstertotal, mtimestart;

@implementation Monster
+ (void)initialize
{
	monsters = [[OFMutableArray alloc] init];
}

+ (OFMutableArray<Monster *> *)monsters
{
	return monsters;
}

+ (instancetype)monsterWithType: (int)type
			    yaw: (int)yaw
			  state: (int)state
			trigger: (int)trigger
			   move: (int)move
{
	return [[self alloc] initWithType: type
				      yaw: yaw
				    state: state
				  trigger: trigger
				     move: move];
}

static int skill = 3;
VARB(skill, 1, 10, ^ { return skill; }, ^ (int value) {
	skill = value;
	conoutf(@"skill is now %d", skill);
})

// for savegames
+ (void)restoreAll
{
	for (Monster *monster in monsters)
		if (monster.state == CS_DEAD)
			numkilled++;
}

#define TOTMFREQ 13
#define NUMMONSTERTYPES 8

struct monstertype // see docs for how these values modify behaviour
{
	short gun, speed, health, freq, lag, rate, pain, loyalty, mscale,
	    bscale;
	short painsound, diesound;
	OFConstantString *name, *mdlname;
}

monstertypes[NUMMONSTERTYPES] = {
	{ GUN_FIREBALL, 15, 100, 3, 0, 100, 800, 1, 10, 10, S_PAINO, S_DIE1,
	    @"an ogre", @"monster/ogro" },
	{ GUN_CG, 18, 70, 2, 70, 10, 400, 2, 8, 9, S_PAINR, S_DEATHR,
	    @"a rhino", @"monster/rhino" },
	{ GUN_SG, 14, 120, 1, 100, 300, 400, 4, 14, 14, S_PAINE, S_DEATHE,
	    @"ratamahatta", @"monster/rat" },
	{ GUN_RIFLE, 15, 200, 1, 80, 300, 300, 4, 18, 18, S_PAINS, S_DEATHS,
	    @"a slith", @"monster/slith" },
	{ GUN_RL, 13, 500, 1, 0, 100, 200, 6, 24, 24, S_PAINB, S_DEATHB,
	    @"bauul", @"monster/bauul" },
	{ GUN_BITE, 22, 50, 3, 0, 100, 400, 1, 12, 15, S_PAINP, S_PIGGR2,
	    @"a hellpig", @"monster/hellpig" },
	{ GUN_ICEBALL, 12, 250, 1, 0, 10, 400, 6, 18, 18, S_PAINH, S_DEATHH,
	    @"a knight", @"monster/knight" },
	{ GUN_SLIMEBALL, 15, 100, 1, 0, 200, 400, 2, 13, 10, S_PAIND, S_DEATHD,
	    @"a goblin", @"monster/goblin" },
};

- (instancetype)initWithType: (int)type
			 yaw: (int)yaw
		       state: (int)state
		     trigger: (int)trigger
			move: (int)move
{
	self = [super init];

	if (type >= NUMMONSTERTYPES) {
		conoutf(@"warning: unknown monster in spawn: %d", type);
		type = 0;
	}

	struct monstertype *t = &monstertypes[(self.monsterType = type)];
	self.eyeHeight = 2.0f;
	self.aboveEye = 1.9f;
	self.radius *= t->bscale / 10.0f;
	self.eyeHeight *= t->bscale / 10.0f;
	self.aboveEye *= t->bscale / 10.0f;
	self.monsterState = state;

	if (state != M_SLEEP)
		spawnplayer(self);

	self.trigger = lastmillis + trigger;
	self.targetYaw = self.yaw = (float)yaw;
	self.move = move;
	self.enemy = Player.player1;
	self.gunSelect = t->gun;
	self.maxSpeed = (float)t->speed;
	self.health = t->health;
	self.armour = 0;

	for (size_t i = 0; i < NUMGUNS; i++)
		self.ammo[i] = 10000;

	self.pitch = 0;
	self.roll = 0;
	self.state = CS_ALIVE;
	self.anger = 0;
	self.name = t->name;

	return self;
}

- (id)copy
{
	Monster *copy = [super copy];

	copy->_monsterState = _monsterState;
	copy->_monsterType = _monsterType;
	copy->_enemy = _enemy;
	copy->_targetYaw = _targetYaw;
	copy->_trigger = _trigger;
	copy->_attackTarget = _attackTarget;
	copy->_anger = _anger;

	return copy;
}

static void
spawnmonster() // spawn a random monster according to freq distribution in DMSP
{
	int n = rnd(TOTMFREQ), type;
	for (int i = 0;; i++) {
		if ((n -= monstertypes[i].freq) < 0) {
			type = i;
			break;
		}
	}

	[monsters addObject: [Monster monsterWithType: type
						  yaw: rnd(360)
						state: M_SEARCH
					      trigger: 1000
						 move: 1]];
}

+ (void)resetAll
{
	[monsters removeAllObjects];

	numkilled = 0;
	monstertotal = 0;
	spawnremain = 0;

	if (m_dmsp) {
		nextmonster = mtimestart = lastmillis + 10000;
		monstertotal = spawnremain = gamemode < 0 ? skill * 10 : 0;
	} else if (m_classicsp) {
		mtimestart = lastmillis;

		for (Entity *e in ents) {
			if (e.type != MONSTER)
				continue;

			Monster *m = [Monster monsterWithType: e.attr2
							  yaw: e.attr1
							state: M_SLEEP
						      trigger: 100
							 move: 0];
			m.origin = OFMakeVector3D(e.x, e.y, e.z);
			[monsters addObject: m];
			entinmap(m);
			monstertotal++;
		}
	}
}

// height-correct line of sight for monster shooting/seeing
static bool
los(float lx, float ly, float lz, float bx, float by, float bz, OFVector3D *v)
{
	if (OUTBORD((int)lx, (int)ly) || OUTBORD((int)bx, (int)by))
		return false;
	float dx = bx - lx;
	float dy = by - ly;
	int steps = (int)(sqrt(dx * dx + dy * dy) / 0.9);
	if (!steps)
		return false;
	float x = lx;
	float y = ly;
	int i = 0;
	for (;;) {
		struct sqr *s = S((int)x, (int)y);
		if (SOLID(s))
			break;
		float floor = s->floor;
		if (s->type == FHF)
			floor -= s->vdelta / 4.0f;
		float ceil = s->ceil;
		if (s->type == CHF)
			ceil += s->vdelta / 4.0f;
		float rz = lz - ((lz - bz) * (i / (float)steps));
		if (rz < floor || rz > ceil)
			break;
		v->x = x;
		v->y = y;
		v->z = rz;
		x += dx / (float)steps;
		y += dy / (float)steps;
		i++;
	}
	return i >= steps;
}

static bool
enemylos(Monster *m, OFVector3D *v)
{
	*v = m.origin;
	return los(m.origin.x, m.origin.y, m.origin.z, m.enemy.origin.x,
	    m.enemy.origin.y, m.enemy.origin.z, v);
}

// monster AI is sequenced using transitions: they are in a particular state
// where they execute a particular behaviour until the trigger time is hit, and
// then they reevaluate their situation based on the current state, the
// environment etc., and transition to the next state. Transition timeframes are
// parametrized by difficulty level (skill), faster transitions means quicker
// decision making means tougher AI.

// n = at skill 0, n/2 = at skill 10, r = added random factor
- (void)transitionWithState: (int)state moving: (int)moving n: (int)n r: (int)r
{
	self.monsterState = state;
	self.move = moving;
	n = n * 130 / 100;
	self.trigger = lastmillis + n - skill * (n / 16) + rnd(r + 1);
}

- (void)normalizeWithAngle: (float)angle
{
	while (self.yaw < angle - 180.0f)
		self.yaw += 360.0f;
	while (self.yaw > angle + 180.0f)
		self.yaw -= 360.0f;
}

// main AI thinking routine, called every frame for every monster
- (void)performAction
{
	if (self.enemy.state == CS_DEAD) {
		self.enemy = Player.player1;
		self.anger = 0;
	}
	[self normalizeWithAngle: self.targetYaw];
	// slowly turn monster towards his target
	if (self.targetYaw > self.yaw) {
		self.yaw += curtime * 0.5f;
		if (self.targetYaw < self.yaw)
			self.yaw = self.targetYaw;
	} else {
		self.yaw -= curtime * 0.5f;
		if (self.targetYaw > self.yaw)
			self.yaw = self.targetYaw;
	}

	float disttoenemy =
	    OFDistanceOfVectors3D(self.enemy.origin, self.origin);
	self.pitch =
	    atan2(self.enemy.origin.z - self.origin.z, disttoenemy) * 180 / PI;

	// special case: if we run into scenery
	if (self.blocked) {
		self.blocked = false;
		// try to jump over obstackle (rare)
		if (!rnd(20000 / monstertypes[self.monsterType].speed))
			self.jumpNext = true;
		// search for a way around (common)
		else if (self.trigger < lastmillis &&
		    (self.monsterState != M_HOME || !rnd(5))) {
			// patented "random walk" AI pathfinding (tm) ;)
			self.targetYaw += 180 + rnd(180);
			[self transitionWithState: M_SEARCH
					   moving: 1
						n: 400
						r: 1000];
		}
	}

	float enemyYaw = -(float)atan2(self.enemy.origin.x - self.origin.x,
	    self.enemy.origin.y - self.origin.y) / PI * 180 + 180;

	switch (self.monsterState) {
	case M_PAIN:
	case M_ATTACKING:
	case M_SEARCH:
		if (self.trigger < lastmillis)
			[self transitionWithState: M_HOME
					   moving: 1
						n: 100
						r: 200];
		break;

		// state classic sp monster start in, wait for visual contact
	case M_SLEEP: {
		OFVector3D target;
		if (editmode || !enemylos(self, &target))
			return; // skip running physics
		[self normalizeWithAngle: enemyYaw];
		float angle = (float)fabs(enemyYaw - self.yaw);
		// the better the angle to the player, the further the monster
		// can see/hear
		if (disttoenemy < 8 || (disttoenemy < 16 && angle < 135) ||
		    (disttoenemy < 32 && angle < 90) ||
		    (disttoenemy < 64 && angle < 45) || angle < 10) {
			[self transitionWithState: M_HOME
					   moving: 1
						n: 500
						r: 200];
			OFVector3D loc = self.origin;
			playsound(S_GRUNT1 + rnd(2), &loc);
		}
		break;
	}

	case M_AIMING:
		// this state is the delay between wanting to shoot and actually
		// firing
		if (self.trigger < lastmillis) {
			self.lastAction = 0;
			self.attacking = true;
			shoot(self, self.attackTarget);
			[self transitionWithState: M_ATTACKING
					   moving: 0
						n: 600
						r: 0];
		}
		break;

	case M_HOME:
		// monster has visual contact, heads straight for player and
		// may want to shoot at any time
		self.targetYaw = enemyYaw;
		if (self.trigger < lastmillis) {
			OFVector3D target;
			if (!enemylos(self, &target)) {
				// no visual contact anymore, let monster get
				// as close as possible then search for player
				[self transitionWithState: M_HOME
						   moving: 1
							n: 800
							r: 500];
			} else {
				// the closer the monster is the more likely he
				// wants to shoot
				if (!rnd((int)disttoenemy / 3 + 1) &&
				    self.enemy.state == CS_ALIVE) {
					// get ready to fire
					self.attackTarget = target;
					int n =
					    monstertypes[self.monsterType].lag;
					[self transitionWithState: M_AIMING
							   moving: 0
								n: n
								r: 10];
				} else {
					// track player some more
					int n =
					    monstertypes[self.monsterType].rate;
					[self transitionWithState: M_HOME
							   moving: 1
								n: n
								r: 0];
				}
			}
		}
		break;
	}

	moveplayer(self, 1, false); // use physics to move monster
}

- (void)incurDamage: (int)damage fromEntity: (__kindof DynamicEntity *)d
{
	// a monster hit us
	if ([d isKindOfClass: Monster.class]) {
		Monster *m = (Monster *)d;

		// guard for RL guys shooting themselves :)
		if (self != m) {
			// don't attack straight away, first get angry
			self.anger++;
			int anger = (self.monsterType == m.monsterType
			    ? self.anger / 2 : self.anger);
			if (anger >= monstertypes[self.monsterType].loyalty)
				// monster infight if very angry
				self.enemy = m;
		}
	} else {
		// player hit us
		self.anger = 0;
		self.enemy = d;
	}

	// in this state monster won't attack
	[self transitionWithState: M_PAIN
			   moving: 0
				n: monstertypes[self.monsterType].pain
				r: 200];

	if ((self.health -= damage) <= 0) {
		self.state = CS_DEAD;
		self.lastAction = lastmillis;
		numkilled++;
		Player.player1.frags = numkilled;
		OFVector3D loc = self.origin;
		playsound(monstertypes[self.monsterType].diesound, &loc);
		int remain = monstertotal - numkilled;
		if (remain > 0 && remain <= 5)
			conoutf(@"only %d monster(s) remaining", remain);
	} else {
		OFVector3D loc = self.origin;
		playsound(monstertypes[self.monsterType].painsound, &loc);
	}
}

+ (void)endSinglePlayerWithAllKilled: (bool)allKilled
{
	conoutf(allKilled
	    ? @"you have cleared the map!" : @"you reached the exit!");
	conoutf(@"score: %d kills in %d seconds", numkilled,
	    (lastmillis - mtimestart) / 1000);
	monstertotal = 0;
	startintermission();
}

+ (void)thinkAll
{
	if (m_dmsp && spawnremain && lastmillis > nextmonster) {
		if (spawnremain-- == monstertotal)
			conoutf(@"The invasion has begun!");
		nextmonster = lastmillis + 1000;
		spawnmonster();
	}

	if (monstertotal && !spawnremain && numkilled == monstertotal)
		[self endSinglePlayerWithAllKilled: true];

	// equivalent of player entity touch, but only teleports are used
	[ents enumerateObjectsUsingBlock: ^ (Entity *e, size_t i, bool *stop) {
		if (e.type != TELEPORT)
			return;

		if (OUTBORD(e.x, e.y))
			return;

		OFVector3D v =
		    OFMakeVector3D(e.x, e.y, (float)S(e.x, e.y)->floor);
		for (Monster *monster in monsters) {
			if (monster.state == CS_DEAD) {
				if (lastmillis - monster.lastAction < 2000) {
					monster.move = 0;
					moveplayer(monster, 1, false);
				}
			} else {
				v.z += monster.eyeHeight;
				float dist =
				    OFDistanceOfVectors3D(v, monster.origin);
				v.z -= monster.eyeHeight;

				if (dist < 4)
					teleport(i, monster);
			}
		}
	}];

	for (Monster *monster in monsters)
		if (monster.state == CS_ALIVE)
			[monster performAction];
}

+ (void)renderAll
{
	for (Monster *monster in monsters)
		renderclient(monster, false,
		    monstertypes[monster.monsterType].mdlname,
		    monster.monsterType == 5,
		    monstertypes[monster.monsterType].mscale / 10.0f);
}
@end
