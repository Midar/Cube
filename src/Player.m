#import "Player.h"

static Player *player1;

@implementation Player
+ (void)initialize
{
	if (self == Player.class)
		player1 = [[Player alloc] init];
}

+ (instancetype)player
{
	return [[self alloc] init];
}

+ (void)setPlayer1:(Player *)player1_
{
	player1 = player1_;
}

+ (Player *)player1
{
	return player1;
}

- (instancetype)init
{
	self = [super init];

	_team = @"";

	return self;
}

- (id)copy
{
	Player *copy = [super copy];

	copy->_lifeSequence = _lifeSequence;
	copy->_frags = _frags;
	copy->_team = [_team copy];

	return copy;
}
@end
