// rendermd2.cpp: loader code adapted from a nehe tutorial

#include "cube.h"

#import "DynamicEntity.h"
#import "MD2.h"
#import "MapModelInfo.h"
#import "OFString+Cube.h"

static OFMutableDictionary<OFString *, MD2 *> *mdllookup = nil;
static OFMutableArray<MD2 *> *mapmodels = nil;

static const int FIRSTMDL = 20;

void
delayedload(MD2 *m)
{
	if (!m.loaded) {
		OFString *path = [OFString
		    stringWithFormat:@"packages/models/%@", m.loadname];
		OFIRI *baseIRI = [Cube.sharedInstance.gameDataIRI
		    IRIByAppendingPathComponent:path];

		OFIRI *IRI1 = [baseIRI IRIByAppendingPathComponent:@"tris.md2"];
		if (![m loadWithIRI:IRI1])
			fatal(@"loadmodel: ", IRI1.string);

		OFIRI *IRI2 = [baseIRI IRIByAppendingPathComponent:@"skin.jpg"];
		int xs, ys;
		installtex(FIRSTMDL + m.mdlnum, IRI2, &xs, &ys, false);
		m.loaded = true;
	}
}

MD2 *
loadmodel(OFString *name)
{
	static int modelnum = 0;

	MD2 *m = mdllookup[name];
	if (m != nil)
		return m;

	m = [MD2 md2];
	m.mdlnum = modelnum++;
	m.mmi = [MapModelInfo infoWithRad:2 h:2 zoff:0 snap:0 name:@""];
	m.loadname = name;

	if (mdllookup == nil)
		mdllookup = [[OFMutableDictionary alloc] init];

	mdllookup[name] = m;

	return m;
}

void
mapmodel(
    OFString *rad, OFString *h, OFString *zoff, OFString *snap, OFString *name)
{
	MD2 *m = loadmodel([name stringByReplacingOccurrencesOfString:@"\\"
	                                                   withString:@"/"]);
	m.mmi = [MapModelInfo infoWithRad:rad.cube_intValue
	                                h:h.cube_intValue
	                             zoff:zoff.cube_intValue
	                             snap:snap.cube_intValue
	                             name:m.loadname];

	if (mapmodels == nil)
		mapmodels = [[OFMutableArray alloc] init];

	[mapmodels addObject:m];
}
COMMAND(mapmodel, ARG_5STR)

void
mapmodelreset()
{
	[mapmodels removeAllObjects];
}
COMMAND(mapmodelreset, ARG_NONE)

MapModelInfo *
getmminfo(int i)
{
	return i < mapmodels.count ? mapmodels[i].mmi : nil;
}

void
rendermodel(OFString *mdl, int frame, int range, int tex, float rad,
    OFVector3D position, float yaw, float pitch, bool teammate, float scale,
    float speed, int snap, int basetime)
{
	MD2 *m = loadmodel(mdl);

	if (isoccluded(player1.o.x, player1.o.y, position.x - rad,
	        position.z - rad, rad * 2))
		return;

	delayedload(m);

	int xs, ys;
	glBindTexture(GL_TEXTURE_2D,
	    tex ? lookuptexture(tex, &xs, &ys) : FIRSTMDL + m.mdlnum);

	int ix = (int)position.x;
	int iy = (int)position.z;
	OFVector3D light = OFMakeVector3D(1, 1, 1);

	if (!OUTBORD(ix, iy)) {
		sqr *s = S(ix, iy);
		float ll = 256.0f; // 0.96f;
		float of = 0.0f;   // 0.1f;
		light.x = s->r / ll + of;
		light.y = s->g / ll + of;
		light.z = s->b / ll + of;
	}

	if (teammate) {
		light.x *= 0.6f;
		light.y *= 0.7f;
		light.z *= 1.2f;
	}

	[m renderWithLight:light
	             frame:frame
	             range:range
	          position:position
	               yaw:yaw
	             pitch:pitch
	             scale:scale
	             speed:speed
	              snap:snap
	          basetime:basetime];
}
