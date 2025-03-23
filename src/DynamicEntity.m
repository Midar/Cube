#import "DynamicEntity.h"

#include "cube.h"

#import "Monster.h"

struct dynent {
	OFVector3D origin, velocity;
	float yaw, pitch, roll;
	float maxSpeed;
	bool outsideMap;
	bool inWater;
	bool onFloor, jumpNext;
	int move, strafe;
	bool k_left, k_right, k_up, k_down;
	int timeInAir;
	float radius, eyeHeight, aboveEye;
	int lastUpdate, lag, ping;
	int lifeSequence;
	int state;
	int frags;
	int health, armour, armourType, quadMillis;
	int gunSelect, gunWait;
	int lastAction, lastAttackGun, lastMove;
	bool attacking;
	int ammo[NUMGUNS];
	int monsterState;
	int monsterType;
	void *enemy;
	float targetYaw;
	bool blocked, moving;
	int trigger;
	OFVector3D attackTarget;
	int anger;
	char name[260], team[260];
};

@implementation DynamicEntity
+ (instancetype)entity
{
	return [[self alloc] init];
}

+ (size_t)serializedSize
{
	return sizeof(struct dynent);
}

- (instancetype)init
{
	self = [super init];

	_ammo = (int *)OFAllocZeroedMemory(NUMGUNS, sizeof(int));

	_yaw = 270;
	_maxSpeed = 22;
	_radius = 1.1f;
	_eyeHeight = 3.2f;
	_aboveEye = 0.7f;
	_lastUpdate = lastmillis;
	_name = _team = @"";
	_state = CS_ALIVE;

	[self resetToSpawnState];

	return self;
}

- (void)dealloc
{
	OFFreeMemory(_ammo);
}

- (id)copy
{
	DynamicEntity *copy = [[self.class alloc] init];

	copy->_origin = _origin;
	copy->_velocity = _velocity;
	copy->_yaw = _yaw;
	copy->_pitch = _pitch;
	copy->_roll = _roll;
	copy->_maxSpeed = _maxSpeed;
	copy->_outsideMap = _outsideMap;
	copy->_inWater = _inWater;
	copy->_onFloor = _onFloor;
	copy->_jumpNext = _jumpNext;
	copy->_move = _move;
	copy->_strafe = _strafe;
	copy->_k_left = _k_left;
	copy->_k_right = _k_right;
	copy->_k_up = _k_up;
	copy->_k_down = _k_down;
	copy->_timeInAir = _timeInAir;
	copy->_radius = _radius;
	copy->_eyeHeight = _eyeHeight;
	copy->_aboveEye = _aboveEye;
	copy->_lastUpdate = _lastUpdate;
	copy->_lag = _lag;
	copy->_ping = _ping;
	copy->_lifeSequence = _lifeSequence;
	copy->_state = _state;
	copy->_frags = _frags;
	copy->_health = _health;
	copy->_armour = _armour;
	copy->_armourType = _armourType;
	copy->_quadMillis = _quadMillis;
	copy->_gunSelect = _gunSelect;
	copy->_gunWait = _gunWait;
	copy->_lastAction = _lastAction;
	copy->_lastAttackGun = _lastAttackGun;
	copy->_lastMove = _lastMove;
	copy->_attacking = _attacking;

	for (size_t i = 0; i < NUMGUNS; i++)
		copy->_ammo[i] = _ammo[i];

	copy->_blocked = _blocked;
	copy->_moving = _moving;
	copy->_name = [_name copy];
	copy->_team = [_team copy];

	return copy;
}

- (OFData *)dataBySerializing
{
	// This is frighteningly *TERRIBLE*, but the format used by existing
	// savegames.
	struct dynent data = { .origin = _origin,
		.velocity = _velocity,
		.yaw = _yaw,
		.pitch = _pitch,
		.roll = _roll,
		.maxSpeed = _maxSpeed,
		.outsideMap = _outsideMap,
		.inWater = _inWater,
		.onFloor = _onFloor,
		.jumpNext = _jumpNext,
		.move = _move,
		.strafe = _strafe,
		.k_left = _k_left,
		.k_right = _k_right,
		.k_up = _k_up,
		.k_down = _k_down,
		.timeInAir = _timeInAir,
		.radius = _radius,
		.eyeHeight = _eyeHeight,
		.aboveEye = _aboveEye,
		.lastUpdate = _lastUpdate,
		.lag = _lag,
		.ping = _ping,
		.lifeSequence = _lifeSequence,
		.state = _state,
		.frags = _frags,
		.health = _health,
		.armour = _armour,
		.armourType = _armourType,
		.quadMillis = _quadMillis,
		.gunSelect = _gunSelect,
		.gunWait = _gunWait,
		.lastAction = _lastAction,
		.lastAttackGun = _lastAttackGun,
		.lastMove = _lastMove,
		.attacking = _attacking,
		.blocked = _blocked,
		.moving = _moving };

	if ([self isKindOfClass:Monster.class]) {
		Monster *monster = (Monster *)self;
		data.monsterState = monster.monsterState;
		data.monsterType = monster.monsterType;
		data.targetYaw = monster.targetYaw;
		data.trigger = monster.trigger;
		data.attackTarget = monster.attackTarget;
		data.anger = monster.anger;
	}

	for (int i = 0; i < NUMGUNS; i++)
		data.ammo[i] = _ammo[i];

	memcpy(data.name, _name.UTF8String, min(_name.UTF8StringLength, 259));
	memcpy(data.team, _team.UTF8String, min(_team.UTF8StringLength, 259));

	return [OFData dataWithItems:&data count:sizeof(data)];
}

- (void)setFromSerializedData:(OFData *)data
{
	struct dynent d;

	if (data.count != sizeof(struct dynent))
		@throw [OFOutOfRangeException exception];

	memcpy(&d, data.items, data.count);

	_origin = d.origin;
	_velocity = d.velocity;
	_yaw = d.yaw;
	_pitch = d.pitch;
	_roll = d.roll;
	_maxSpeed = d.maxSpeed;
	_outsideMap = d.outsideMap;
	_inWater = d.inWater;
	_onFloor = d.onFloor;
	_jumpNext = d.jumpNext;
	_move = d.move;
	_strafe = d.strafe;
	_k_left = d.k_left;
	_k_right = d.k_right;
	_k_up = d.k_up;
	_k_down = d.k_down;
	_timeInAir = d.timeInAir;
	_radius = d.radius;
	_eyeHeight = d.eyeHeight;
	_aboveEye = d.aboveEye;
	_lastUpdate = d.lastUpdate;
	_lag = d.lag;
	_ping = d.ping;
	_lifeSequence = d.lifeSequence;
	_state = d.state;
	_frags = d.frags;
	_health = d.health;
	_armour = d.armour;
	_armourType = d.armourType;
	_quadMillis = d.quadMillis;
	_gunSelect = d.gunSelect;
	_gunWait = d.gunWait;
	_lastAction = d.lastAction;
	_lastAttackGun = d.lastAttackGun;
	_lastMove = d.lastMove;
	_attacking = d.attacking;

	for (int i = 0; i < NUMGUNS; i++)
		_ammo[i] = d.ammo[i];

	_blocked = d.blocked;
	_moving = d.moving;

	if ([self isKindOfClass:Monster.class]) {
		Monster *monster = (Monster *)self;
		monster.monsterState = d.monsterState;
		monster.monsterType = d.monsterType;
		monster.targetYaw = d.targetYaw;
		monster.trigger = d.trigger;
		monster.attackTarget = d.attackTarget;
		monster.anger = d.anger;
	}

	_name = [[OFString alloc] initWithUTF8String:d.name];
	_team = [[OFString alloc] initWithUTF8String:d.team];
}

- (void)resetMovement
{
	_k_left = false;
	_k_right = false;
	_k_up = false;
	_k_down = false;
	_jumpNext = false;
	_strafe = 0;
	_move = 0;
}

- (void)resetToSpawnState
{
	[self resetMovement];

	_velocity = OFMakeVector3D(0, 0, 0);
	_onFloor = false;
	_timeInAir = 0;
	_health = 100;
	_armour = 50;
	_armourType = A_BLUE;
	_quadMillis = 0;
	_lastAttackGun = _gunSelect = GUN_SG;
	_gunWait = 0;
	_attacking = false;
	_lastAction = 0;

	for (size_t i = 0; i < NUMGUNS; i++)
		_ammo[i] = 0;
	_ammo[GUN_FIST] = 1;

	if (m_noitems) {
		_gunSelect = GUN_RIFLE;
		_armour = 0;

		if (m_noitemsrail) {
			_health = 1;
			_ammo[GUN_RIFLE] = 100;
		} else {
			if (gamemode == 12) {
				// eihrul's secret "instafist" mode
				_gunSelect = GUN_FIST;
				return;
			}

			_health = 256;

			if (m_tarena) {
				_gunSelect = rnd(4) + 1;
				baseammo(_gunSelect);

				int gun2;
				do {
					gun2 = rnd(4) + 1;
				} while (gun2 != _gunSelect);

				baseammo(gun2);
			} else if (m_arena) {
				// insta arena
				_ammo[GUN_RIFLE] = 100;
			} else {
				// efficiency
				for (size_t i = 0; i < 4; i++)
					baseammo(i + 1);

				_gunSelect = GUN_CG;
			}

			_ammo[GUN_CG] /= 2;
		}
	} else
		_ammo[GUN_SG] = 5;
}
@end
