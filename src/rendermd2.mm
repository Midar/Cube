// rendermd2.cpp: loader code adapted from a nehe tutorial

#include "cube.h"

struct md2_header {
	int magic;
	int version;
	int skinWidth, skinHeight;
	int frameSize;
	int numSkins, numVertices, numTexcoords;
	int numTriangles, numGlCommands, numFrames;
	int offsetSkins, offsetTexcoords, offsetTriangles;
	int offsetFrames, offsetGlCommands, offsetEnd;
};

struct md2_vertex {
	uchar vertex[3], lightNormalIndex;
};

struct md2_frame {
	float scale[3];
	float translate[3];
	char name[16];
	md2_vertex vertices[1];
};

@interface MD2 : OFObject {
	int _numGlCommands;
	int *_glCommands;
	int _numTriangles;
	int _frameSize;
	int _numFrames;
	int _numVerts;
	char *_frames;
	OFVector3D **_mverts;
	int _displaylist;
	int _displaylistverts;
}

@property (nonatomic) MapModelInfo *mmi;
@property (copy, nonatomic) OFString *loadname;
@property (nonatomic) int mdlnum;
@property (nonatomic) bool loaded;

- (bool)loadWithPath:(char *)filename;
- (void)renderWithLight:(OFVector3D &)light
                  frame:(int)frame
                  range:(int)range
                      x:(float)x
                      y:(float)y
                      z:(float)z
                    yaw:(float)yaw
                  pitch:(float)pitch
                  scale:(float)scale
                  speed:(float)speed
                   snap:(int)snap
               basetime:(int)basetime;
- (void)scaleWithFrame:(int)frame scale:(float)scale snap:(int)snap;
@end

static OFMutableDictionary<OFString *, MD2 *> *mdllookup = nil;
static OFMutableArray<MD2 *> *mapmodels = nil;

@implementation MD2
+ (void)initialize
{
	if (self != [MD2 class])
		return;

	mdllookup = [[OFMutableDictionary alloc] init];
	mapmodels = [[OFMutableArray alloc] init];
}

- (void)dealloc
{
	if (_glCommands)
		delete[] _glCommands;
	if (_frames)
		delete[] _frames;
}

- (bool)loadWithPath:(char *)filename
{
	FILE *file;
	md2_header header;

	if ((file = fopen(filename, "rb")) == NULL)
		return false;

	fread(&header, sizeof(md2_header), 1, file);
	endianswap(&header, sizeof(int), sizeof(md2_header) / sizeof(int));

	if (header.magic != 844121161 || header.version != 8)
		return false;

	_frames = new char[header.frameSize * header.numFrames];
	if (_frames == NULL)
		return false;

	fseek(file, header.offsetFrames, SEEK_SET);
	fread(_frames, header.frameSize * header.numFrames, 1, file);

	for (int i = 0; i < header.numFrames; ++i)
		endianswap(_frames + i * header.frameSize, sizeof(float), 6);

	_glCommands = new int[header.numGlCommands];
	if (_glCommands == NULL)
		return false;

	fseek(file, header.offsetGlCommands, SEEK_SET);
	fread(_glCommands, header.numGlCommands * sizeof(int), 1, file);

	endianswap(_glCommands, sizeof(int), header.numGlCommands);

	_numFrames = header.numFrames;
	_numGlCommands = header.numGlCommands;
	_frameSize = header.frameSize;
	_numTriangles = header.numTriangles;
	_numVerts = header.numVertices;

	fclose(file);

	_mverts = new OFVector3D *[_numFrames];
	loopj(_numFrames) _mverts[j] = NULL;

	return true;
}

float
snap(int sn, float f)
{
	return sn ? (float)(((int)(f + sn * 0.5f)) & (~(sn - 1))) : f;
}

- (void)scaleWithFrame:(int)frame scale:(float)scale snap:(int)sn
{
	_mverts[frame] = new OFVector3D[_numVerts];
	md2_frame *cf = (md2_frame *)((char *)_frames + _frameSize * frame);
	float sc = 16.0f / scale;
	loop(vi, _numVerts)
	{
		uchar *cv = (uchar *)&cf->vertices[vi].vertex;
		OFVector3D *v = &(_mverts[frame])[vi];
		v->x = (snap(sn, cv[0] * cf->scale[0]) + cf->translate[0]) / sc;
		v->y =
		    -(snap(sn, cv[1] * cf->scale[1]) + cf->translate[1]) / sc;
		v->z = (snap(sn, cv[2] * cf->scale[2]) + cf->translate[2]) / sc;
	}
}

- (void)renderWithLight:(OFVector3D &)light
                  frame:(int)frame
                  range:(int)range
                      x:(float)x
                      y:(float)y
                      z:(float)z
                    yaw:(float)yaw
                  pitch:(float)pitch
                  scale:(float)sc
                  speed:(float)speed
                   snap:(int)sn
               basetime:(int)basetime
{
	loopi(range) if (!_mverts[frame + i])[self scaleWithFrame:frame + i
	                                                    scale:sc
	                                                     snap:sn];

	glPushMatrix();
	glTranslatef(x, y, z);
	glRotatef(yaw + 180, 0, -1, 0);
	glRotatef(pitch, 0, 0, 1);

	glColor3fv((float *)&light);

	if (_displaylist && frame == 0 && range == 1) {
		glCallList(_displaylist);
		xtraverts += _displaylistverts;
	} else {
		if (frame == 0 && range == 1) {
			static int displaylistn = 10;
			glNewList(_displaylist = displaylistn++, GL_COMPILE);
			_displaylistverts = xtraverts;
		}

		int time = lastmillis - basetime;
		int fr1 = (int)(time / speed);
		float frac1 = (time - fr1 * speed) / speed;
		float frac2 = 1 - frac1;
		fr1 = fr1 % range + frame;
		int fr2 = fr1 + 1;
		if (fr2 >= frame + range)
			fr2 = frame;
		OFVector3D *verts1 = _mverts[fr1];
		OFVector3D *verts2 = _mverts[fr2];

		for (int *command = _glCommands; (*command) != 0;) {
			int numVertex = *command++;
			if (numVertex > 0) {
				glBegin(GL_TRIANGLE_STRIP);
			} else {
				glBegin(GL_TRIANGLE_FAN);
				numVertex = -numVertex;
			}

			loopi(numVertex)
			{
				float tu = *((float *)command++);
				float tv = *((float *)command++);
				glTexCoord2f(tu, tv);
				int vn = *command++;
				OFVector3D &v1 = verts1[vn];
				OFVector3D &v2 = verts2[vn];
#define ip(c) v1.c *frac2 + v2.c *frac1
				glVertex3f(ip(x), ip(z), ip(y));
			}

			xtraverts += numVertex;

			glEnd();
		}

		if (_displaylist) {
			glEndList();
			_displaylistverts = xtraverts - _displaylistverts;
		}
	}

	glPopMatrix();
}

const int FIRSTMDL = 20;

void
delayedload(MD2 *m)
{
	if (!m.loaded) {
		@autoreleasepool {
			sprintf_sd(name1)("packages/models/%s/tris.md2",
			    m.loadname.UTF8String);
			if (![m loadWithPath:path(name1)])
				fatal("loadmodel: ", name1);
			sprintf_sd(name2)("packages/models/%s/skin.jpg",
			    m.loadname.UTF8String);
			int xs, ys;
			installtex(FIRSTMDL + m.mdlnum, path(name2), xs, ys);
			m.loaded = true;
		}
	}
}

int modelnum = 0;

MD2 *
loadmodel(OFString *name)
{
	@autoreleasepool {
		MD2 *m = mdllookup[name];
		if (m != nil)
			return m;
		m = [[MD2 alloc] init];
		m.mdlnum = modelnum++;
		MapModelInfo *mmi = [[MapModelInfo alloc] initWithRad:2
		                                                    h:2
		                                                 zoff:0
		                                                 snap:0
		                                                 name:@""];
		m.mmi = mmi;
		m.loadname = name;
		mdllookup[name] = m;
		return m;
	}
}

void
mapmodel(
    OFString *rad, OFString *h, OFString *zoff, OFString *snap, OFString *name)
{
	MD2 *m = loadmodel(name);
	MapModelInfo *mmi =
	    [[MapModelInfo alloc] initWithRad:(int)rad.longLongValue
	                                    h:(int)h.longLongValue
	                                 zoff:(int)zoff.longLongValue
	                                 snap:(int)snap.longLongValue
	                                 name:m.loadname];
	m.mmi = mmi;
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
rendermodel(OFString *mdl, int frame, int range, int tex, float rad, float x,
    float y, float z, float yaw, float pitch, bool teammate, float scale,
    float speed, int snap, int basetime)
{
	MD2 *m = loadmodel(mdl);

	if (isoccluded(player1->o.x, player1->o.y, x - rad, z - rad, rad * 2))
		return;

	delayedload(m);

	int xs, ys;
	glBindTexture(GL_TEXTURE_2D,
	    tex ? lookuptexture(tex, xs, ys) : FIRSTMDL + m.mdlnum);

	int ix = (int)x;
	int iy = (int)z;
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
	                 x:x
	                 y:y
	                 z:z
	               yaw:yaw
	             pitch:pitch
	             scale:scale
	             speed:speed
	              snap:snap
	          basetime:basetime];
}
@end

@implementation MapModelInfo
- (instancetype)initWithRad:(int)rad
                          h:(int)h
                       zoff:(int)zoff
                       snap:(int)snap
                       name:(OFString *)name
{
	self = [super init];

	_rad = rad;
	_h = h;
	_zoff = zoff;
	_snap = snap;
	_name = [name copy];

	return self;
}
@end
