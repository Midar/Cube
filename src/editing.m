// editing.cpp: most map editing commands go here, entity editing commands are
// in world.cpp

#include "cube.h"

#import "Command.h"
#import "DynamicEntity.h"
#import "Monster.h"
#import "OFString+Cube.h"
#import "Player.h"
#import "Variable.h"

bool editmode = false;

// the current selection, used by almost all editing commands
// invariant: all code assumes that these are kept inside MINBORD distance of
// the edge of the map

struct block sel = { 0, 0, 0, 0 };

OF_CONSTRUCTOR()
{
	enqueueInit(^ {
		static const struct {
			OFString *name;
			int *storage;
		} vars[4] = {
			{ @"selx", &sel.x },
			{ @"sely", &sel.y },
			{ @"selxs", &sel.xs },
			{ @"selys", &sel.ys }
		};

		for (size_t i = 0; i < 4; i++) {
			Variable *variable = [Variable
			    variableWithName: vars[i].name
					 min: 0
					 max: 4096
				     storage: vars[i].storage
				   persisted: false
				      getter: NULL
				      setter: NULL];
			Identifier.identifiers[vars[i].name] = variable;
		}
	});
}

int selh = 0;
bool selset = false;

#define loopselxy(b)							   \
	{								   \
		makeundo();						   \
		for (int x = 0; x < sel->xs; x++) {			   \
			for (int y = 0; y < sel->ys; y++) {		   \
				struct sqr *s = S(sel->x + x, sel->y + y); \
				b;					   \
			}						   \
		}							   \
		remip(sel, 0);						   \
	}

int cx, cy, ch;

int curedittex[] = { -1, -1, -1 };

bool dragging = false;
int lastx, lasty, lasth;

int lasttype = 0, lasttex = 0;
static struct sqr rtex;

VAR(editing, 0, 0, 1);

void
toggleedit()
{
	Player *player1 = Player.player1;
	if (player1.state == CS_DEAD)
		// do not allow dead players to edit to avoid state
		return;
	if (!editmode && !allowedittoggle())
		// not in most multiplayer modes
		return;
	if (!(editmode = !editmode)) {
		// reset triggers to allow quick playtesting
		settagareas();
		// find spawn closest to current floating pos
		entinmap(player1);
	} else {
		// clear trigger areas to allow them to be edited
		resettagareas();
		player1.health = 100;
		if (m_classicsp)
			// all monsters back at their spawns for editing
			[Monster resetAll];
		projreset();
	}
	Cube.sharedInstance.repeatsKeys = editmode;
	selset = false;
	editing = editmode;
}

COMMAND(edittoggle, ARG_NONE, ^ {
	toggleedit();
})

void
correctsel() // ensures above invariant
{
	selset = !OUTBORD(sel.x, sel.y);
	int bsize = ssize - MINBORD;
	if (sel.xs + sel.x > bsize)
		sel.xs = bsize - sel.x;
	if (sel.ys + sel.y > bsize)
		sel.ys = bsize - sel.y;
	if (sel.xs <= 0 || sel.ys <= 0)
		selset = false;
}

bool
noteditmode()
{
	correctsel();
	if (!editmode)
		conoutf(@"this function is only allowed in edit mode");
	return !editmode;
}

bool
noselection()
{
	if (!selset)
		conoutf(@"no selection");
	return !selset;
}

#define EDITSEL					\
	if (noteditmode() || noselection())	\
		return;
#define EDITSELMP						\
	if (noteditmode() || noselection() || multiplayer())	\
		return;
#define EDITMP					\
	if (noteditmode() || multiplayer())	\
		return;

COMMAND(select, ARG_4INT, (^ (int x, int y, int xs, int ys) {
	struct block s = { x, y, xs, ys };
	sel = s;
	selh = 0;
	correctsel();
}))

void
makesel()
{
	struct block s = { min(lastx, cx), min(lasty, cy), abs(lastx - cx) + 1,
		abs(lasty - cy) + 1 };
	sel = s;
	selh = max(lasth, ch);
	correctsel();
	if (selset)
		rtex = *S(sel.x, sel.y);
}

VAR(flrceil, 0, 0, 2);

// finds out z height when cursor points at wall
float
sheight(struct sqr *s, struct sqr *t, float z)
{
	return !flrceil // z-s->floor<s->ceil-z
	    ? (s->type == FHF ? s->floor - t->vdelta / 4.0f : (float)s->floor)
	    : (s->type == CHF ? s->ceil + t->vdelta / 4.0f : (float)s->ceil);
}

void
cursorupdate() // called every frame from hud
{
	Player *player1 = Player.player1;
	flrceil = ((int)(player1.pitch >= 0)) * 2;

	volatile float x =
	    worldpos.x; // volatile needed to prevent msvc7 optimizer bug?
	volatile float y = worldpos.y;
	volatile float z = worldpos.z;

	cx = (int)x;
	cy = (int)y;

	if (OUTBORD(cx, cy))
		return;
	struct sqr *s = S(cx, cy);

	// selected wall
	if (fabs(sheight(s, s, z) - z) > 1) {
		// find right wall cube
		x += (x > player1.origin.x ? 0.5f : -0.5f);
		y += (y > player1.origin.y ? 0.5f : -0.5f);

		cx = (int)x;
		cy = (int)y;

		if (OUTBORD(cx, cy))
			return;
	}

	if (dragging)
		makesel();

	const int GRIDSIZE = 5;
	const float GRIDW = 0.5f;
	const float GRID8 = 2.0f;
	const float GRIDS = 2.0f;
	const int GRIDM = 0x7;

	// render editing grid

	for (int ix = cx - GRIDSIZE; ix <= cx + GRIDSIZE; ix++) {
		for (int iy = cy - GRIDSIZE; iy <= cy + GRIDSIZE; iy++) {
			if (OUTBORD(ix, iy))
				continue;
			struct sqr *s = S(ix, iy);
			if (SOLID(s))
				continue;
			float h1 = sheight(s, s, z);
			float h2 = sheight(s, SWS(s, 1, 0, ssize), z);
			float h3 = sheight(s, SWS(s, 1, 1, ssize), z);
			float h4 = sheight(s, SWS(s, 0, 1, ssize), z);
			if (s->tag)
				linestyle(GRIDW, [OFColor colorWithRed: 1.0f
								 green: 0.25f
								  blue: 0.25f
								 alpha: 1.0f]);
			else if (s->type == FHF || s->type == CHF)
				linestyle(GRIDW, [OFColor colorWithRed: 0.5f
								 green: 1.0f
								  blue: 0.5f
								 alpha: 1.0f]);
			else
				linestyle(GRIDW, OFColor.gray);
			struct block b = { ix, iy, 1, 1 };
			box(&b, h1, h2, h3, h4);
			linestyle(GRID8, [OFColor colorWithRed: 0.25f
							 green: 0.25f
							  blue: 1.0f
							 alpha: 1.0f]);
			if (!(ix & GRIDM))
				line(ix, iy, h1, ix, iy + 1, h4);
			if (!(ix + 1 & GRIDM))
				line(ix + 1, iy, h2, ix + 1, iy + 1, h3);
			if (!(iy & GRIDM))
				line(ix, iy, h1, ix + 1, iy, h2);
			if (!(iy + 1 & GRIDM))
				line(ix, iy + 1, h4, ix + 1, iy + 1, h3);
		}
	}

	if (!SOLID(s)) {
		float ih = sheight(s, s, z);
		linestyle(GRIDS, OFColor.white);
		struct block b = { cx, cy, 1, 1 };
		box(&b, ih, sheight(s, SWS(s, 1, 0, ssize), z),
		    sheight(s, SWS(s, 1, 1, ssize), z),
		    sheight(s, SWS(s, 0, 1, ssize), z));
		linestyle(GRIDS, OFColor.red);
		dot(cx, cy, ih);
		ch = (int)ih;
	}

	if (selset) {
		linestyle(GRIDS, [OFColor colorWithRed: 1.0f
						 green: 0.25f
						  blue: 0.25f
						 alpha: 1.0f]);
		box(&sel, (float)selh, (float)selh, (float)selh, (float)selh);
	}
}

static OFMutableData *undos; // unlimited undo
VARP(undomegs, 0, 1, 10);    // bounded by n megs

void
pruneundos(int maxremain) // bound memory
{
	int t = 0;
	for (ssize_t i = (ssize_t)undos.count - 1; i >= 0; i--) {
		struct block *undo = [undos mutableItemAtIndex: i];

		t += undo->xs * undo->ys * sizeof(struct sqr);
		if (t > maxremain) {
			OFFreeMemory(undo);
			[undos removeItemAtIndex: i];
		}
	}
}

void
makeundo()
{
	if (undos == nil)
		undos = [[OFMutableData alloc]
		    initWithItemSize: sizeof(struct block *)];

	struct block *copy = blockcopy(&sel);
	[undos addItem: &copy];
	pruneundos(undomegs << 20);
}

COMMAND(undo, ARG_NONE, ^ {
	EDITMP;
	if (undos.count == 0) {
		conoutf(@"nothing more to undo");
		return;
	}
	struct block *p = undos.mutableLastItem;
	[undos removeLastItem];
	blockpaste(p);
	OFFreeMemory(p);
})

static struct block *copybuf = NULL;

COMMAND(copy, ARG_NONE, ^ {
	EDITSELMP;

	if (copybuf)
		OFFreeMemory(copybuf);

	copybuf = blockcopy(&sel);
})

COMMAND(paste, ARG_NONE, ^ {
	EDITMP;
	if (!copybuf) {
		conoutf(@"nothing to paste");
		return;
	}
	sel.xs = copybuf->xs;
	sel.ys = copybuf->ys;
	correctsel();
	if (!selset || sel.xs != copybuf->xs || sel.ys != copybuf->ys) {
		conoutf(@"incorrect selection");
		return;
	}
	makeundo();
	copybuf->x = sel.x;
	copybuf->y = sel.y;
	blockpaste(copybuf);
})

// maintain most recently used of the texture lists when applying texture
void
tofronttex()
{
	for (int i = 0; i < 3; i++) {
		int c = curedittex[i];
		if (c >= 0) {
			unsigned char *p = hdr.texlists[i];
			int t = p[c];
			for (int a = c - 1; a >= 0; a--)
				p[a + 1] = p[a];
			p[0] = t;
			curedittex[i] = -1;
		}
	}
}

void
editdrag(bool isDown)
{
	if ((dragging = isDown)) {
		lastx = cx;
		lasty = cy;
		lasth = ch;
		selset = false;
		tofronttex();
	}
	makesel();
}

// the core editing function. all the *xy functions perform the core operations
// and are also called directly from the network, the function below it is
// strictly triggered locally. They all have very similar structure.

void
editheightxy(bool isfloor, int amount, const struct block *sel)
{
	loopselxy(
	    if (isfloor) {
		    s->floor += amount;
		    if (s->floor >= s->ceil)
			    s->floor = s->ceil - 1;
	    } else {
		    s->ceil += amount;
		    if (s->ceil <= s->floor)
			    s->ceil = s->floor + 1;
	    });
}

void
editheight(int flr, int amount)
{
	EDITSEL;

	bool isfloor = flr == 0;
	editheightxy(isfloor, amount, &sel);
	addmsg(1, 7, SV_EDITH, sel.x, sel.y, sel.xs, sel.ys, isfloor, amount);
}

COMMAND(editheight, ARG_2INT, ^ (int flr, int amount) {
	editheight(flr, amount);
})

void
edittexxy(int type, int t, const struct block *sel)
{
	loopselxy(
		switch (type) {
		case 0:
			s->ftex = t;
			break;
		case 1:
			s->wtex = t;
			break;
		case 2:
			s->ctex = t;
			break;
		case 3:
			s->utex = t;
			break;
		}
	);
}

COMMAND(edittex, ARG_2INT, ^ (int type, int dir) {
	EDITSEL;

	if (type < 0 || type > 3)
		return;

	if (type != lasttype) {
		tofronttex();
		lasttype = type;
	}

	int atype = type == 3 ? 1 : type;
	int i = curedittex[atype];
	i = i < 0 ? 0 : i + dir;
	curedittex[atype] = i = min(max(i, 0), 255);
	int t = lasttex = hdr.texlists[atype][i];
	edittexxy(type, t, &sel);
	addmsg(1, 7, SV_EDITT, sel.x, sel.y, sel.xs, sel.ys, type, t);
})

COMMAND(replace, ARG_NONE, (^ {
	EDITSELMP;

	for (int x = 0; x < ssize; x++) {
		for (int y = 0; y < ssize; y++) {
			struct sqr *s = S(x, y);
			switch (lasttype) {
			case 0:
				if (s->ftex == rtex.ftex)
					s->ftex = lasttex;
				break;
			case 1:
				if (s->wtex == rtex.wtex)
					s->wtex = lasttex;
				break;
			case 2:
				if (s->ctex == rtex.ctex)
					s->ctex = lasttex;
				break;
			case 3:
				if (s->utex == rtex.utex)
					s->utex = lasttex;
				break;
			}
		}
	}

	struct block b = { 0, 0, ssize, ssize };
	remip(&b, 0);
}))

void
edittypexy(int type, const struct block *sel)
{
	loopselxy(s->type = type);
}

static void
edittype(int type)
{
	EDITSEL;

	if (type == CORNER && (sel.xs != sel.ys || sel.xs == 3 || (sel.xs > 4 &&
	    sel.xs != 8) || sel.x & ~-sel.xs || sel.y & ~-sel.ys)) {
		conoutf(@"corner selection must be power of 2 aligned");
		return;
	}

	edittypexy(type, &sel);
	addmsg(1, 6, SV_EDITS, sel.x, sel.y, sel.xs, sel.ys, type);
}

COMMAND(heightfield, ARG_1INT, ^ (int t) {
	edittype(t == 0 ? FHF : CHF);
})

COMMAND(solid, ARG_1INT, ^ (int t) {
	edittype(t == 0 ? SPACE : SOLID);
})

COMMAND(corner, ARG_NONE, ^ {
	edittype(CORNER);
})

void
editequalisexy(bool isfloor, const struct block *sel)
{
	int low = 127, hi = -128;
	loopselxy({
		if (s->floor < low)
			low = s->floor;
		if (s->ceil > hi)
			hi = s->ceil;
	});
	loopselxy({
		if (isfloor)
			s->floor = low;
		else
			s->ceil = hi;
		if (s->floor >= s->ceil)
			s->floor = s->ceil - 1;
	});
}

COMMAND(equalize, ARG_1INT, ^ (int flr) {
	bool isfloor = (flr == 0);

	EDITSEL;

	editequalisexy(isfloor, &sel);
	addmsg(1, 6, SV_EDITE, sel.x, sel.y, sel.xs, sel.ys, isfloor);
})

void
setvdeltaxy(int delta, const struct block *sel)
{
	loopselxy(s->vdelta = max(s->vdelta + delta, 0));
	remipmore(sel, 0);
}

COMMAND(vdelta, ARG_1INT, ^ (int delta) {
	EDITSEL;

	setvdeltaxy(delta, &sel);
	addmsg(1, 6, SV_EDITD, sel.x, sel.y, sel.xs, sel.ys, delta);
})

#define MAXARCHVERT 50
int archverts[MAXARCHVERT][MAXARCHVERT];
bool archvinit = false;

COMMAND(archvertex, ARG_3INT, ^ (int span, int vert, int delta) {
	if (!archvinit) {
		archvinit = true;
		for (int s = 0; s < MAXARCHVERT; s++)
			for (int v = 0; v < MAXARCHVERT; v++)
				archverts[s][v] = 0;
	}
	if (span >= MAXARCHVERT || vert >= MAXARCHVERT || span < 0 || vert < 0)
		return;
	archverts[span][vert] = delta;
})

COMMAND(arch, ARG_2INT, ^ (int sidedelta, int _a) {
	EDITSELMP;

	sel.xs++;
	sel.ys++;

	if (sel.xs > MAXARCHVERT)
		sel.xs = MAXARCHVERT;
	if (sel.ys > MAXARCHVERT)
		sel.ys = MAXARCHVERT;

	struct block *sel_ = &sel;
	// Ugly hack to make the macro work.
	struct block *sel = sel_;
	loopselxy(s->vdelta = sel->xs > sel->ys ? (archverts[sel->xs - 1][x] +
	    (y == 0 || y == sel->ys - 1 ? sidedelta : 0)) :
	    (archverts[sel->ys - 1][y] + (x == 0 || x == sel->xs - 1 ?
	    sidedelta : 0)));
	remipmore(sel, 0);
})

COMMAND(slope, ARG_2INT, ^ (int xd, int yd) {
	EDITSELMP;

	int off = 0;
	if (xd < 0)
		off -= xd * sel.xs;
	if (yd < 0)
		off -= yd * sel.ys;

	sel.xs++;
	sel.ys++;

	struct block *sel_ = &sel;
	// Ugly hack to make the macro work.
	struct block *sel = sel_;
	loopselxy(s->vdelta = xd * x + yd * y + off);
	remipmore(sel, 0);
})

COMMAND(perlin, ARG_3INT, ^ (int scale, int seed, int psize) {
	EDITSELMP;

	sel.xs++;
	sel.ys++;

	makeundo();

	sel.xs--;
	sel.ys--;

	perlinarea(&sel, scale, seed, psize);

	sel.xs++;
	sel.ys++;

	remipmore(&sel, 0);

	sel.xs--;
	sel.ys--;
})

static int fullbright = 0;
VARB(fullbright, 0, 1, ^ { return fullbright; }, ^ (int value) {
	if (fullbright) {
		if (noteditmode())
			return;

		for (int i = 0; i < mipsize; i++)
			world[i].r = world[i].g = world[i].b = 176;
	}
});

COMMAND(edittag, ARG_1INT, ^ (int tag) {
	EDITSELMP;

	struct block *sel_ = &sel;
	// Ugly hack to make the macro work.
	struct block *sel = sel_;
	loopselxy(s->tag = tag);
})

COMMAND(newent, ARG_5STR,
    ^ (OFString *what, OFString *a1, OFString *a2, OFString *a3, OFString *a4) {
	EDITSEL;

	newentity(sel.x, sel.y, (int)Player.player1.origin.z, what,
	    [a1 cube_intValueWithBase: 0], [a2 cube_intValueWithBase: 0],
	    [a3 cube_intValueWithBase: 0], [a4 cube_intValueWithBase: 0]);
})
