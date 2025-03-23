// world.cpp: core map management stuff

#include "cube.h"

#import "Command.h"
#import "DynamicEntity.h"
#import "Entity.h"
#import "Monster.h"

extern OFString *entnames[]; // lookup from map entities above to strings

struct sqr *world = NULL;
int sfactor, ssize, cubicsize, mipsize;

struct header hdr;

// set all cubes with "tag" to space, if tag is 0 then reset ALL tagged cubes
// according to type
void
settag(int tag, int type)
{
	int maxx = 0, maxy = 0, minx = ssize, miny = ssize;
	for (int x = 0; x < ssize; x++) {
		for (int y = 0; y < ssize; y++) {
			struct sqr *s = S(x, y);

			if (s->tag) {
				if (tag) {
					if (tag == s->tag)
						s->type = SPACE;
					else
						continue;
				} else
					s->type = type ? SOLID : SPACE;

				if (x > maxx)
					maxx = x;
				if (y > maxy)
					maxy = y;
				if (x < minx)
					minx = x;
				if (y < miny)
					miny = y;
			}
		}
	}

	if (maxx) {
		// remip minimal area of changed geometry
		struct block b = { minx, miny, maxx - minx + 1,
			maxy - miny + 1 };
		remip(&b, 0);
	}
}

// reset for editing or map saving
void
resettagareas()
{
	settag(0, 0);
}

// set for playing
void
settagareas()
{
	settag(0, 1);

	[ents enumerateObjectsUsingBlock:^(Entity *e, size_t i, bool *stop) {
		if (ents[i].type == CARROT)
			setspawn(i, true);
	}];
}

void
trigger(int tag, int type, bool savegame)
{
	if (!tag)
		return;

	settag(tag, type);

	if (!savegame && type != 3)
		playsound(S_RUMBLE, NULL);

	OFString *aliasname =
	    [OFString stringWithFormat:@"level_trigger_%d", tag];

	if (identexists(aliasname))
		execute(aliasname, true);

	if (type == 2)
		[Monster endSinglePlayerWithAllKilled:false];
}

COMMAND(trigger, ARG_2INT, ^(int tag, int type, bool savegame) {
	trigger(tag, type, savegame);
})

// main geometric mipmapping routine, recursively rebuild mipmaps within block
// b. tries to produce cube out of 4 lower level mips as well as possible, sets
// defer to 0 if mipped cube is a perfect mip, i.e. can be rendered at this mip
// level indistinguishable from its constituent cubes (saves considerable
// rendering time if this is possible).

void
remip(const struct block *b, int level)
{
	if (level >= SMALLEST_FACTOR)
		return;

	int lighterr = getvar(@"lighterror") * 3;
	struct sqr *w = wmip[level];
	struct sqr *v = wmip[level + 1];
	int ws = ssize >> level;
	int vs = ssize >> (level + 1);
	struct block s = *b;
	if (s.x & 1) {
		s.x--;
		s.xs++;
	}
	if (s.y & 1) {
		s.y--;
		s.ys++;
	}
	s.xs = (s.xs + 1) & ~1;
	s.ys = (s.ys + 1) & ~1;
	for (int x = s.x; x < s.x + s.xs; x += 2)
		for (int y = s.y; y < s.y + s.ys; y += 2) {
			struct sqr *o[4];
			o[0] = SWS(w, x, y, ws); // the 4 constituent cubes
			o[1] = SWS(w, x + 1, y, ws);
			o[2] = SWS(w, x + 1, y + 1, ws);
			o[3] = SWS(w, x, y + 1, ws);
			// the target cube in the higher mip level
			struct sqr *r = SWS(v, x / 2, y / 2, vs);
			*r = *o[0];
			unsigned char nums[MAXTYPE];
			for (int i = 0; i < MAXTYPE; i++)
				nums[i] = 0;
			for (int j = 0; j < 4; j++)
				nums[o[j]->type]++;
			// cube contains both solid and space, treated
			// specially in the renderer
			r->type = SEMISOLID;
			for (int k = 0; k < MAXTYPE; k++)
				if (nums[k] == 4)
					r->type = k;
			if (!SOLID(r)) {
				int floor = 127, ceil = -128;
				for (int i = 0; i < 4; i++) {
					if (!SOLID(o[i])) {
						int fh = o[i]->floor;
						int ch = o[i]->ceil;
						if (r->type == SEMISOLID) {
							if (o[i]->type == FHF)
								// crap hack,
								// needed for
								// rendering
								// large mips
								// next to hfs
								fh -=
								    o[i]->vdelta /
								        4 +
								    2;
							if (o[i]->type == CHF)
								// FIXME: needs
								// to somehow
								// take into
								// account
								// middle
								// vertices on
								// higher mips
								ch +=
								    o[i]->vdelta /
								        4 +
								    2;
						}
						if (fh < floor)
							// take lowest floor and
							// highest ceil, so we
							// never have to see
							// missing lower/upper
							// from the side
							floor = fh;
						if (ch > ceil)
							ceil = ch;
					}
				}
				r->floor = floor;
				r->ceil = ceil;
			}
			if (r->type == CORNER)
				// special case: don't ever split even if
				// textures etc are different
				goto mip;
			r->defer = 1;
			if (SOLID(r)) {
				for (int i = 0; i < 3; i++) {
					if (o[i]->wtex != o[3]->wtex)
						// on an all solid cube, only
						// thing that needs to be equal
						// for a perfect mip is the
						// wall texture
						goto c;
				}
			} else {
				for (int i = 0; i < 3; i++) {
					// perfect mip even if light is not
					// exactly equal
					if (o[i]->type != o[3]->type ||
					    o[i]->floor != o[3]->floor ||
					    o[i]->ceil != o[3]->ceil ||
					    o[i]->ftex != o[3]->ftex ||
					    o[i]->ctex != o[3]->ctex ||
					    abs(o[i + 1]->r - o[0]->r) >
					        lighterr ||
					    abs(o[i + 1]->g - o[0]->g) >
					        lighterr ||
					    abs(o[i + 1]->b - o[0]->b) >
					        lighterr ||
					    o[i]->utex != o[3]->utex ||
					    o[i]->wtex != o[3]->wtex)
						goto c;
				}

				// can make a perfect mip out of a hf if slopes
				// lie on one line
				if (r->type == CHF || r->type == FHF) {
					if (o[0]->vdelta - o[1]->vdelta !=
					        o[1]->vdelta -
					            SWS(w, x + 2, y, ws)
					                ->vdelta ||
					    o[0]->vdelta - o[2]->vdelta !=
					        o[2]->vdelta -
					            SWS(w, x + 2, y + 2, ws)
					                ->vdelta ||
					    o[0]->vdelta - o[3]->vdelta !=
					        o[3]->vdelta -
					            SWS(w, x, y + 2, ws)
					                ->vdelta ||
					    o[3]->vdelta - o[2]->vdelta !=
					        o[2]->vdelta -
					            SWS(w, x + 2, y + 1, ws)
					                ->vdelta ||
					    o[1]->vdelta - o[2]->vdelta !=
					        o[2]->vdelta -
					            SWS(w, x + 1, y + 2, ws)
					                ->vdelta)
						goto c;
				}
			}
			{
				// if any of the constituents is not perfect,
				// then this one isn't either
				for (int i = 0; i < 4; i++)
					if (o[i]->defer)
						goto c;
			}
		mip:
			r->defer = 0;
		c:;
		}
	s.x /= 2;
	s.y /= 2;
	s.xs /= 2;
	s.ys /= 2;
	remip(&s, level + 1);
}

void
remipmore(const struct block *b, int level)
{
	struct block bb = *b;

	if (bb.x > 1)
		bb.x--;
	if (bb.y > 1)
		bb.y--;
	if (bb.xs < ssize - 3)
		bb.xs++;
	if (bb.ys < ssize - 3)
		bb.ys++;

	remip(&bb, level);
}

int
closestent() // used for delent and edit mode ent display
{
	if (noteditmode())
		return -1;

	__block int best;
	__block float bdist = 99999;
	[ents enumerateObjectsUsingBlock:^(Entity *e, size_t i, bool *stop) {
		if (e.type == NOTUSED)
			return;

		OFVector3D v = OFMakeVector3D(e.x, e.y, e.z);
		vdist(dist, t, player1.origin, v);
		if (dist < bdist) {
			best = i;
			bdist = dist;
		}
	}];

	return (bdist == 99999 ? -1 : best);
}

COMMAND(entproperty, ARG_2INT, ^(int prop, int amount) {
	int e = closestent();
	if (e < 0)
		return;
	switch (prop) {
	case 0:
		ents[e].attr1 += amount;
		break;
	case 1:
		ents[e].attr2 += amount;
		break;
	case 2:
		ents[e].attr3 += amount;
		break;
	case 3:
		ents[e].attr4 += amount;
		break;
	}
})

COMMAND(delent, ARG_NONE, ^{
	int e = closestent();
	if (e < 0) {
		conoutf(@"no more entities");
		return;
	}
	int t = ents[e].type;
	conoutf(@"%@ entity deleted", entnames[t]);
	ents[e].type = NOTUSED;
	addmsg(1, 10, SV_EDITENT, e, NOTUSED, 0, 0, 0, 0, 0, 0, 0);
	if (t == LIGHT)
		calclight();
})

int
findtype(OFString *what)
{
	for (int i = 0; i < MAXENTTYPES; i++)
		if ([what isEqual:entnames[i]])
			return i;
	conoutf(@"unknown entity type \"%@\"", what);
	return NOTUSED;
}

Entity *
newentity(int x, int y, int z, OFString *what, int v1, int v2, int v3, int v4)
{
	int type = findtype(what);

	Entity *e = [Entity entity];
	e.x = x;
	e.y = y;
	e.z = z;
	e.attr1 = v1;
	e.type = type;
	e.attr2 = v2;
	e.attr3 = v3;
	e.attr4 = v4;

	switch (type) {
	case LIGHT:
		if (v1 > 32)
			v1 = 32;
		if (!v1)
			e.attr1 = 16;
		if (!v2 && !v3 && !v4)
			e.attr2 = 255;
		break;
	case MAPMODEL:
		e.attr4 = e.attr3;
		e.attr3 = e.attr2;
	case MONSTER:
	case TELEDEST:
		e.attr2 = (unsigned char)e.attr1;
	case PLAYERSTART:
		e.attr1 = (int)player1.yaw;
		break;
	}
	addmsg(1, 10, SV_EDITENT, ents.count, type, e.x, e.y, e.z, e.attr1,
	    e.attr2, e.attr3, e.attr4);

	[ents addObject:e];

	if (type == LIGHT)
		calclight();

	return e;
}

COMMAND(clearents, ARG_1STR, ^(OFString *name) {
	int type = findtype(name);

	if (noteditmode() || multiplayer())
		return;

	for (Entity *e in ents)
		if (e.type == type)
			e.type = NOTUSED;

	if (type == LIGHT)
		calclight();
})

static unsigned char
scalecomp(unsigned char c, int intens)
{
	int n = c * intens / 100;
	if (n > 255)
		n = 255;
	return n;
}

COMMAND(scalelights, ARG_2INT, ^(int f, int intens) {
	for (Entity *e in ents) {
		if (e.type != LIGHT)
			continue;

		e.attr1 = e.attr1 * f / 100;
		if (e.attr1 < 2)
			e.attr1 = 2;
		if (e.attr1 > 32)
			e.attr1 = 32;

		if (intens) {
			e.attr2 = scalecomp(e.attr2, intens);
			e.attr3 = scalecomp(e.attr3, intens);
			e.attr4 = scalecomp(e.attr4, intens);
		}
	}

	calclight();
})

int
findentity(int type, int index)
{
	for (int i = index; i < ents.count; i++)
		if (ents[i].type == type)
			return i;
	for (int j = 0; j < index; j++)
		if (ents[j].type == type)
			return j;
	return -1;
}

struct sqr *wmip[LARGEST_FACTOR * 2];

void
setupworld(int factor)
{
	ssize = 1 << (sfactor = factor);
	cubicsize = ssize * ssize;
	mipsize = cubicsize * 134 / 100;
	struct sqr *w = world =
	    OFAllocZeroedMemory(mipsize, sizeof(struct sqr));
	for (int i = 0; i < LARGEST_FACTOR * 2; i++) {
		wmip[i] = w;
		w += cubicsize >> (i * 2);
	}
}

// main empty world creation routine, if passed factor -1 will enlarge old
// world by 1
void
empty_world(int factor, bool force)
{
	if (!force && noteditmode())
		return;
	cleardlights();
	pruneundos(0);
	struct sqr *oldworld = world;
	bool copy = false;
	if (oldworld && factor < 0) {
		factor = sfactor + 1;
		copy = true;
	}
	if (factor < SMALLEST_FACTOR)
		factor = SMALLEST_FACTOR;
	if (factor > LARGEST_FACTOR)
		factor = LARGEST_FACTOR;
	setupworld(factor);

	for (int x = 0; x < ssize; x++) {
		for (int y = 0; y < ssize; y++) {
			struct sqr *s = S(x, y);
			s->r = s->g = s->b = 150;
			s->ftex = DEFAULT_FLOOR;
			s->ctex = DEFAULT_CEIL;
			s->wtex = s->utex = DEFAULT_WALL;
			s->type = SOLID;
			s->floor = 0;
			s->ceil = 16;
			s->vdelta = 0;
			s->defer = 0;
		}
	}

	strncpy(hdr.head, "CUBE", 4);
	hdr.version = MAPVERSION;
	hdr.headersize = sizeof(struct header);
	hdr.sfactor = sfactor;

	if (copy) {
		for (int x = 0; x < ssize / 2; x++) {
			for (int y = 0; y < ssize / 2; y++) {
				*S(x + ssize / 4, y + ssize / 4) =
				    *SWS(oldworld, x, y, ssize / 2);
			}
		}

		for (Entity *e in ents) {
			e.x += ssize / 4;
			e.y += ssize / 4;
		}
	} else {
		char buffer[128] = "Untitled Map by Unknown";
		memcpy(hdr.maptitle, buffer, 128);
		hdr.waterlevel = -100000;
		for (int i = 0; i < 15; i++)
			hdr.reserved[i] = 0;
		for (int k = 0; k < 3; k++)
			for (int i = 0; i < 256; i++)
				hdr.texlists[k][i] = i;
		[ents removeAllObjects];
		struct block b = { 8, 8, ssize - 16, ssize - 16 };
		edittypexy(SPACE, &b);
	}

	calclight();
	startmap(@"base/unnamed");
	if (oldworld) {
		OFFreeMemory(oldworld);
		toggleedit();
		execute(@"fullbright 1", true);
	}
}

COMMAND(mapenlarge, ARG_NONE, ^{
	empty_world(-1, false);
})

COMMAND(newmap, ARG_1INT, ^(int i) {
	empty_world(i, false);
})

COMMAND(recalc, ARG_NONE, ^{
	calclight();
})
