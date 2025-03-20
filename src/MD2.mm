#import "MD2.h"

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

static float
snap(int sn, float f)
{
	return sn ? (float)(((int)(f + sn * 0.5f)) & (~(sn - 1))) : f;
}

@implementation MD2
{
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

+ (instancetype)md2
{
	return [[self alloc] init];
}

- (void)dealloc
{
	if (_glCommands)
		delete[] _glCommands;
	if (_frames)
		delete[] _frames;
}

- (bool)loadWithIRI:(OFIRI *)IRI
{
	OFSeekableStream *stream;
	@try {
		stream = (OFSeekableStream *)[[OFIRIHandler handlerForIRI:IRI]
		    openItemAtIRI:IRI
		             mode:@"r"];
	} @catch (id e) {
		return false;
	}

	if (![stream isKindOfClass:OFSeekableStream.class])
		return false;

	md2_header header;
	[stream readIntoBuffer:&header exactLength:sizeof(md2_header)];
	endianswap(&header, sizeof(int), sizeof(md2_header) / sizeof(int));

	if (header.magic != 844121161 || header.version != 8)
		return false;

	_frames = new char[header.frameSize * header.numFrames];
	if (_frames == NULL)
		return false;

	[stream seekToOffset:header.offsetFrames whence:OFSeekSet];
	[stream readIntoBuffer:_frames
	           exactLength:header.frameSize * header.numFrames];

	for (int i = 0; i < header.numFrames; ++i)
		endianswap(_frames + i * header.frameSize, sizeof(float), 6);

	_glCommands = new int[header.numGlCommands];
	if (_glCommands == NULL)
		return false;

	[stream seekToOffset:header.offsetGlCommands whence:OFSeekSet];
	[stream readIntoBuffer:_glCommands
	           exactLength:header.numGlCommands * sizeof(int)];
	endianswap(_glCommands, sizeof(int), header.numGlCommands);

	_numFrames = header.numFrames;
	_numGlCommands = header.numGlCommands;
	_frameSize = header.frameSize;
	_numTriangles = header.numTriangles;
	_numVerts = header.numVertices;

	[stream close];

	_mverts = new OFVector3D *[_numFrames];
	loopj(_numFrames) _mverts[j] = NULL;

	return true;
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

- (void)renderWithLight:(OFVector3D)light
                  frame:(int)frame
                  range:(int)range
               position:(OFVector3D)position
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
	glTranslatef(position.x, position.y, position.z);
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
@end
