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
	unsigned char vertex[3], lightNormalIndex;
};

struct md2_frame {
	float scale[3];
	float translate[3];
	char name[16];
	struct md2_vertex vertices[1];
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
	OFFreeMemory(_glCommands);
	OFFreeMemory(_frames);

	if (_mverts != NULL)
		for (size_t i = 0; i < _numFrames; i++)
			OFFreeMemory(_mverts[i]);

	OFFreeMemory(_mverts);
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

	struct md2_header header;
	[stream readIntoBuffer:&header exactLength:sizeof(header)];
	endianswap(&header, sizeof(int), sizeof(header) / sizeof(int));

	if (header.magic != 844121161 || header.version != 8)
		return false;

	@try {
		_frames = OFAllocMemory(header.numFrames, header.frameSize);
	} @catch (OFOutOfMemoryException *e) {
		return false;
	}

	[stream seekToOffset:header.offsetFrames whence:OFSeekSet];
	[stream readIntoBuffer:_frames
	           exactLength:header.frameSize * header.numFrames];

	for (int i = 0; i < header.numFrames; ++i)
		endianswap(_frames + i * header.frameSize, sizeof(float), 6);

	@try {
		_glCommands = OFAllocMemory(header.numGlCommands, sizeof(int));
	} @catch (OFOutOfMemoryException *e) {
		return false;
	}

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

	_mverts = OFAllocZeroedMemory(_numFrames, sizeof(OFVector3D *));

	return true;
}

- (void)scaleWithFrame:(int)frame scale:(float)scale snap:(int)sn
{
	OFAssert(_mverts[frame] == NULL);

	_mverts[frame] = OFAllocMemory(_numVerts, sizeof(OFVector3D));
	struct md2_frame *cf =
	    (struct md2_frame *)((char *)_frames + _frameSize * frame);
	float sc = 16.0f / scale;
	for (int vi = 0; vi < _numVerts; vi++) {
		unsigned char *cv = (unsigned char *)&cf->vertices[vi].vertex;
		OFVector3D *v = &(_mverts[frame])[vi];
		v->x = (snap(sn, cv[0] * cf->scale[0]) + cf->translate[0]) / sc;
		v->y =
		    -(snap(sn, cv[1] * cf->scale[1]) + cf->translate[1]) / sc;
		v->z = (snap(sn, cv[2] * cf->scale[2]) + cf->translate[2]) / sc;
	}
}

- (void)renderWithLight:(OFColor *)light
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
	for (int i = 0; i < range; i++)
		if (!_mverts[frame + i])
			[self scaleWithFrame:frame + i scale:sc snap:sn];

	glPushMatrix();
	glTranslatef(position.x, position.y, position.z);
	glRotatef(yaw + 180, 0, -1, 0);
	glRotatef(pitch, 0, 0, 1);

	float red, green, blue;
	[light getRed:&red green:&green blue:&blue alpha:NULL];
	glColor3f(red, green, blue);

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

			for (int i = 0; i < numVertex; i++) {
				float tu = *((float *)command++);
				float tv = *((float *)command++);
				glTexCoord2f(tu, tv);
				int vn = *command++;
#define ip(c) verts1[vn].c *frac2 + verts2[vn].c *frac1
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
