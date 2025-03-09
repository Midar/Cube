#import "DynamicEntity.h"

#include "cube.h"

struct dynent {
	OFVector3D o, vel;
	float yaw, pitch, roll;
	float maxspeed;
	bool outsidemap;
	bool inwater;
	bool onfloor, jumpnext;
	int move, strafe;
	bool k_left, k_right, k_up, k_down;
	int timeinair;
	float radius, eyeheight, aboveeye;
	int lastupdate, plag, ping;
	int lifesequence;
	int state;
	int frags;
	int health, armour, armourtype, quadmillis;
	int gunselect, gunwait;
	int lastaction, lastattackgun, lastmove;
	bool attacking;
	int ammo[NUMGUNS];
	int monsterstate;
	int mtype;
	void *enemy;
	float targetyaw;
	bool blocked, moving;
	int trigger;
	OFVector3D attacktarget;
	int anger;
	char name[260], team[260];
};

@implementation DynamicEntity
+ (size_t)serializedSize
{
	return sizeof(dynent);
}

- (instancetype)init
{
	self = [super init];

	_ammo = (int *)OFAllocZeroedMemory(NUMGUNS, sizeof(int));

	return self;
}

- (void)dealloc
{
	OFFreeMemory(_ammo);
}

- (id)copy
{
	DynamicEntity *copy = [[self.class alloc] init];

	copy->_o = _o;
	copy->_vel = _vel;
	copy->_yaw = _yaw;
	copy->_pitch = _pitch;
	copy->_roll = _roll;
	copy->_maxspeed = _maxspeed;
	copy->_outsidemap = _outsidemap;
	copy->_inwater = _inwater;
	copy->_onfloor = _onfloor;
	copy->_jumpnext = _jumpnext;
	copy->_move = _move;
	copy->_strafe = _strafe;
	copy->_k_left = _k_left;
	copy->_k_right = _k_right;
	copy->_k_up = _k_up;
	copy->_k_down = _k_down;
	copy->_timeinair = _timeinair;
	copy->_radius = _radius;
	copy->_eyeheight = _eyeheight;
	copy->_aboveeye = _aboveeye;
	copy->_lastupdate = _lastupdate;
	copy->_plag = _plag;
	copy->_ping = _ping;
	copy->_lifesequence = _lifesequence;
	copy->_state = _state;
	copy->_frags = _frags;
	copy->_health = _health;
	copy->_armour = _armour;
	copy->_armourtype = _armourtype;
	copy->_quadmillis = _quadmillis;
	copy->_gunselect = _gunselect;
	copy->_gunwait = _gunwait;
	copy->_lastaction = _lastaction;
	copy->_lastattackgun = _lastattackgun;
	copy->_lastmove = _lastmove;
	copy->_attacking = _attacking;

	for (size_t i = 0; i < NUMGUNS; i++)
		copy->_ammo[i] = _ammo[i];

	copy->_monsterstate = _monsterstate;
	copy->_mtype = _mtype;
	copy->_enemy = _enemy;
	copy->_targetyaw = _targetyaw;
	copy->_blocked = _blocked;
	copy->_moving = _moving;
	copy->_trigger = _trigger;
	copy->_attacktarget = _attacktarget;
	copy->_anger = _anger;

	copy->_name = [_name copy];
	copy->_team = [_team copy];

	return copy;
}

- (OFData *)dataBySerializing
{
	// This is frighteningly *TERRIBLE*, but the format used by existing
	// savegames.
	dynent data = { .o = _o,
		.vel = _vel,
		.yaw = _yaw,
		.pitch = _pitch,
		.roll = _roll,
		.maxspeed = _maxspeed,
		.outsidemap = _outsidemap,
		.inwater = _inwater,
		.onfloor = _onfloor,
		.jumpnext = _jumpnext,
		.move = _move,
		.strafe = _strafe,
		.k_left = _k_left,
		.k_right = _k_right,
		.k_up = _k_up,
		.k_down = _k_down,
		.timeinair = _timeinair,
		.radius = _radius,
		.eyeheight = _eyeheight,
		.aboveeye = _aboveeye,
		.lastupdate = _lastupdate,
		.plag = _plag,
		.ping = _ping,
		.lifesequence = _lifesequence,
		.state = _state,
		.frags = _frags,
		.health = _health,
		.armour = _armour,
		.armourtype = _armourtype,
		.quadmillis = _quadmillis,
		.gunselect = _gunselect,
		.gunwait = _gunwait,
		.lastaction = _lastaction,
		.lastattackgun = _lastattackgun,
		.lastmove = _lastmove,
		.attacking = _attacking,
		.monsterstate = _monsterstate,
		.mtype = _mtype,
		.targetyaw = _targetyaw,
		.blocked = _blocked,
		.moving = _moving,
		.trigger = _trigger,
		.attacktarget = _attacktarget,
		.anger = _anger };

	for (int i = 0; i < NUMGUNS; i++)
		data.ammo[i] = _ammo[i];

	memcpy(data.name, _name.UTF8String, min(_name.UTF8StringLength, 259));
	memcpy(data.team, _team.UTF8String, min(_team.UTF8StringLength, 259));

	return [OFData dataWithItems:&data count:sizeof(data)];
}

- (void)setFromSerializedData:(OFData *)data
{
	struct dynent d;

	if (data.count != sizeof(dynent))
		@throw [OFOutOfRangeException exception];

	memcpy(&d, data.items, data.count);

	_o = d.o;
	_vel = d.vel;
	_yaw = d.yaw;
	_pitch = d.pitch;
	_roll = d.roll;
	_maxspeed = d.maxspeed;
	_outsidemap = d.outsidemap;
	_inwater = d.inwater;
	_onfloor = d.onfloor;
	_jumpnext = d.jumpnext;
	_move = d.move;
	_strafe = d.strafe;
	_k_left = d.k_left;
	_k_right = d.k_right;
	_k_up = d.k_up;
	_k_down = d.k_down;
	_timeinair = d.timeinair;
	_radius = d.radius;
	_eyeheight = d.eyeheight;
	_aboveeye = d.aboveeye;
	_lastupdate = d.lastupdate;
	_plag = d.plag;
	_ping = d.ping;
	_lifesequence = d.lifesequence;
	_state = d.state;
	_frags = d.frags;
	_health = d.health;
	_armour = d.armour;
	_armourtype = d.armourtype;
	_quadmillis = d.quadmillis;
	_gunselect = d.gunselect;
	_gunwait = d.gunwait;
	_lastaction = d.lastaction;
	_lastattackgun = d.lastattackgun;
	_lastmove = d.lastmove;
	_attacking = d.attacking;

	for (int i = 0; i < NUMGUNS; i++)
		_ammo[i] = d.ammo[i];

	_monsterstate = d.monsterstate;
	_mtype = d.mtype;
	_targetyaw = d.targetyaw;
	_blocked = d.blocked;
	_moving = d.moving;
	_trigger = d.trigger;
	_attacktarget = d.attacktarget;
	_anger = d.anger;

	_name = [[OFString alloc] initWithUTF8String:d.name];
	_team = [[OFString alloc] initWithUTF8String:d.team];
}
@end
