// rendergl.cpp: core opengl rendering stuff

#define gamma math_gamma

#include "cube.h"

#import "Command.h"
#import "Monster.h"
#import "OFString+Cube.h"
#import "Player.h"
#import "Variable.h"

#ifdef DARWIN
# define GL_COMBINE_EXT GL_COMBINE_ARB
# define GL_COMBINE_RGB_EXT GL_COMBINE_RGB_ARB
# define GL_SOURCE0_RBG_EXT GL_SOURCE0_RGB_ARB
# define GL_SOURCE1_RBG_EXT GL_SOURCE1_RGB_ARB
# define GL_RGB_SCALE_EXT GL_RGB_SCALE_ARB
#endif

extern int curvert;

bool hasoverbright = false;

void purgetextures();

GLUquadricObj *qsphere = NULL;
int glmaxtexsize = 256;

void
gl_init(int w, int h)
{
	// #define fogvalues 0.5f, 0.6f, 0.7f, 1.0f

	glViewport(0, 0, w, h);
	glClearDepth(1.0);
	glDepthFunc(GL_LESS);
	glEnable(GL_DEPTH_TEST);
	glShadeModel(GL_SMOOTH);

	glEnable(GL_FOG);
	glFogi(GL_FOG_MODE, GL_LINEAR);
	glFogf(GL_FOG_DENSITY, 0.25);
	glHint(GL_FOG_HINT, GL_NICEST);

	glEnable(GL_LINE_SMOOTH);
	glHint(GL_LINE_SMOOTH_HINT, GL_NICEST);
	glEnable(GL_POLYGON_OFFSET_LINE);
	glPolygonOffset(-3.0, -3.0);

	glCullFace(GL_FRONT);
	glEnable(GL_CULL_FACE);

	char *exts = (char *)glGetString(GL_EXTENSIONS);

	if (strstr(exts, "GL_EXT_texture_env_combine"))
		hasoverbright = true;
	else
		conoutf(@"WARNING: cannot use overbright lighting, using old "
		        @"lighting model!");

	glGetIntegerv(GL_MAX_TEXTURE_SIZE, &glmaxtexsize);

	purgetextures();

	if (!(qsphere = gluNewQuadric()))
		fatal(@"glu sphere");
	gluQuadricDrawStyle(qsphere, GLU_FILL);
	gluQuadricOrientation(qsphere, GLU_INSIDE);
	gluQuadricTexture(qsphere, GL_TRUE);
	glNewList(1, GL_COMPILE);
	gluSphere(qsphere, 1, 12, 6);
	glEndList();
}

void
cleangl()
{
	if (qsphere)
		gluDeleteQuadric(qsphere);
}

bool
installtex(int tnum, OFIRI *IRI, int *xs, int *ys, bool clamp)
{
	SDL_Surface *s = IMG_Load(IRI.fileSystemRepresentation.UTF8String);
	if (s == NULL) {
		conoutf(@"couldn't load texture %@", IRI.string);
		return false;
	}

	if (s->format->BitsPerPixel != 24) {
		SDL_PixelFormat *format =
		    SDL_AllocFormat(SDL_PIXELFORMAT_RGB24);
		if (format == NULL) {
			conoutf(@"texture cannot be converted to 24bpp: %@",
			    IRI.string);
			return false;
		}

		@try {
			SDL_Surface *converted =
			    SDL_ConvertSurface(s, format, 0);
			if (converted == NULL) {
				conoutf(@"texture cannot be converted "
				        @"to 24bpp: %@",
				    IRI.string);
				return false;
			}

			SDL_FreeSurface(s);
			s = converted;
		} @finally {
			SDL_FreeFormat(format);
		}
	}

#if 0
	for (int i = 0; i < s->w * s->h * 3; i++) {
		unsigned char *p = (unsigned char *)s->pixels + i;
		*p = 255 - *p;
	}
#endif
	glBindTexture(GL_TEXTURE_2D, tnum);
	glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S,
	    clamp ? GL_CLAMP_TO_EDGE : GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T,
	    clamp ? GL_CLAMP_TO_EDGE : GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER,
	    GL_LINEAR_MIPMAP_LINEAR); // NEAREST);
	glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);

	*xs = s->w;
	*ys = s->h;
	while (*xs > glmaxtexsize || *ys > glmaxtexsize) {
		*xs /= 2;
		*ys /= 2;
	}

	void *scaledimg = s->pixels;

	if (*xs != s->w) {
		conoutf(@"warning: quality loss: scaling %@",
		    IRI.string); // for voodoo cards under linux
		scaledimg = OFAllocMemory(1, *xs * *ys * 3);
		gluScaleImage(GL_RGB, s->w, s->h, GL_UNSIGNED_BYTE, s->pixels,
		    *xs, *ys, GL_UNSIGNED_BYTE, scaledimg);
	}

	if (gluBuild2DMipmaps(GL_TEXTURE_2D, GL_RGB, *xs, *ys, GL_RGB,
	        GL_UNSIGNED_BYTE, scaledimg))
		fatal(@"could not build mipmaps");

	if (*xs != s->w)
		free(scaledimg);

	SDL_FreeSurface(s);

	return true;
}

// management of texture slots
// each texture slot can have multople texture frames, of which currently only
// the first is used additional frames can be used for various shaders

#define MAXTEX 1000
static int texx[MAXTEX]; // ( loaded texture ) -> ( name, size )
static int texy[MAXTEX];
static OFString *texname[MAXTEX];
static int curtex = 0;
static const int FIRSTTEX = 1000; // opengl id = loaded id + FIRSTTEX
// std 1+, sky 14+, mdls 20+

// increase to allow more complex shader defs
#define MAXFRAMES 2
// ( cube texture, frame ) -> ( opengl id, name )
static int mapping[256][MAXFRAMES];
static OFString *mapname[256][MAXFRAMES];

void
purgetextures()
{
	for (int i = 0; i < 256; i++)
		for (int j = 0; j < MAXFRAMES; j++)
			mapping[i][j] = 0;
}

int curtexnum = 0;

COMMAND(texturereset, ARG_NONE, ^{
	curtexnum = 0;
})

COMMAND(texture, ARG_2STR, (^(OFString *aframe, OFString *name) {
	int num = curtexnum++, frame = aframe.cube_intValue;

	if (num < 0 || num >= 256 || frame < 0 || frame >= MAXFRAMES)
		return;

	mapping[num][frame] = 1;
	mapname[num][frame] = [name stringByReplacingOccurrencesOfString:@"\\"
	                                                      withString:@"/"];
}))

int
lookuptexture(int tex, int *xs, int *ys)
{
	int frame = 0; // other frames?
	int tid = mapping[tex][frame];

	if (tid >= FIRSTTEX) {
		*xs = texx[tid - FIRSTTEX];
		*ys = texy[tid - FIRSTTEX];
		return tid;
	}

	*xs = *ys = 16;
	if (tid == 0)
		return 1; // crosshair :)

	// lazily happens once per "texture" command, basically
	for (int i = 0; i < curtex; i++) {
		if ([mapname[tex][frame] isEqual:texname[i]]) {
			mapping[tex][frame] = tid = i + FIRSTTEX;
			*xs = texx[i];
			*ys = texy[i];
			return tid;
		}
	}

	if (curtex == MAXTEX)
		fatal(@"loaded too many textures");

	int tnum = curtex + FIRSTTEX;
	texname[curtex] = mapname[tex][frame];

	OFString *path =
	    [OFString stringWithFormat:@"packages/%@", texname[curtex]];

	if (installtex(tnum,
	        [Cube.sharedInstance.gameDataIRI
	            IRIByAppendingPathComponent:path],
	        xs, ys, false)) {
		mapping[tex][frame] = tnum;
		texx[curtex] = *xs;
		texy[curtex] = *ys;
		curtex++;
		return tnum;
	} else {
		return mapping[tex][frame] = FIRSTTEX; // temp fix
	}
}

static void
gl_setupworld()
{
	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_COLOR_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	setarraypointers();

	if (hasoverbright) {
		glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_COMBINE_EXT);
		glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB_EXT, GL_MODULATE);
		glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE0_RGB_EXT, GL_TEXTURE);
		glTexEnvi(
		    GL_TEXTURE_ENV, GL_SOURCE1_RGB_EXT, GL_PRIMARY_COLOR_EXT);
	}
}

int skyoglid;

struct strip {
	int tex, start, num;
};
static OFMutableData *strips;

void
renderstripssky()
{
	glBindTexture(GL_TEXTURE_2D, skyoglid);

	const struct strip *items = strips.items;
	size_t count = strips.count;
	for (size_t i = 0; i < count; i++)
		if (items[i].tex == skyoglid)
			glDrawArrays(
			    GL_TRIANGLE_STRIP, items[i].start, items[i].num);
}

void
renderstrips()
{
	int lasttex = -1;
	const struct strip *items = strips.items;
	size_t count = strips.count;
	for (size_t i = 0; i < count; i++) {
		if (items[i].tex == skyoglid)
			continue;

		if (items[i].tex != lasttex) {
			glBindTexture(GL_TEXTURE_2D, items[i].tex);
			lasttex = items[i].tex;
		}

		glDrawArrays(GL_TRIANGLE_STRIP, items[i].start, items[i].num);
	}
}

void
overbright(float amount)
{
	if (hasoverbright)
		glTexEnvf(GL_TEXTURE_ENV, GL_RGB_SCALE_EXT, amount);
}

void
addstrip(int tex, int start, int n)
{
	if (strips == nil)
		strips = [[OFMutableData alloc]
		    initWithItemSize:sizeof(struct strip)];

	struct strip s = { .tex = tex, .start = start, .num = n };
	[strips addItem:&s];
}

#undef gamma

VARFP(gamma, 30, 100, 300, {
	float f = gamma / 100.0f;
	Uint16 ramp[256];

	SDL_CalculateGammaRamp(f, ramp);

	if (SDL_SetWindowGammaRamp(
	        Cube.sharedInstance.window, ramp, ramp, ramp) == -1) {
		conoutf(
		    @"Could not set gamma (card/driver doesn't support it?)");
		conoutf(@"sdl: %s", SDL_GetError());
	}
})

void
transplayer()
{
	Player *player1 = Player.player1;

	glLoadIdentity();

	glRotated(player1.roll, 0.0, 0.0, 1.0);
	glRotated(player1.pitch, -1.0, 0.0, 0.0);
	glRotated(player1.yaw, 0.0, 1.0, 0.0);

	glTranslated(-player1.origin.x,
	    (player1.state == CS_DEAD ? player1.eyeHeight - 0.2f : 0) -
	        player1.origin.z,
	    -player1.origin.y);
}

VARP(fov, 10, 105, 120);

int xtraverts;

VAR(fog, 64, 180, 1024);
VAR(fogcolour, 0, 0x8099B3, 0xFFFFFF);

VARP(hudgun, 0, 1, 1);

OFString *hudgunnames[] = { @"hudguns/fist", @"hudguns/shotg",
	@"hudguns/chaing", @"hudguns/rocket", @"hudguns/rifle" };

void
drawhudmodel(int start, int end, float speed, int base)
{
	Player *player1 = Player.player1;

	rendermodel(hudgunnames[player1.gunSelect], start, end, 0, 1.0f,
	    OFMakeVector3D(
	        player1.origin.x, player1.origin.z, player1.origin.y),
	    player1.yaw + 90, player1.pitch, false, 1.0f, speed, 0, base);
}

void
drawhudgun(float fovy, float aspect, int farplane)
{
	Player *player1 = Player.player1;

	if (!hudgun /*|| !player1.gunSelect*/)
		return;

	glEnable(GL_CULL_FACE);

	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	gluPerspective(fovy, aspect, 0.3f, farplane);
	glMatrixMode(GL_MODELVIEW);

	// glClear(GL_DEPTH_BUFFER_BIT);
	int rtime = reloadtime(player1.gunSelect);
	if (player1.lastAction && player1.lastAttackGun == player1.gunSelect &&
	    lastmillis - player1.lastAction < rtime) {
		drawhudmodel(7, 18, rtime / 18.0f, player1.lastAction);
	} else
		drawhudmodel(6, 1, 100, 0);

	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	gluPerspective(fovy, aspect, 0.15f, farplane);
	glMatrixMode(GL_MODELVIEW);

	glDisable(GL_CULL_FACE);
}

void
gl_drawframe(int w, int h, float curfps)
{
	Player *player1 = Player.player1;
	float hf = hdr.waterlevel - 0.3f;
	float fovy = (float)fov * h / w;
	float aspect = w / (float)h;
	bool underwater = (player1.origin.z < hf);

	glFogi(GL_FOG_START, (fog + 64) / 8);
	glFogi(GL_FOG_END, fog);
	float fogc[4] = { (fogcolour >> 16) / 256.0f,
		((fogcolour >> 8) & 255) / 256.0f, (fogcolour & 255) / 256.0f,
		1.0f };
	glFogfv(GL_FOG_COLOR, fogc);
	glClearColor(fogc[0], fogc[1], fogc[2], 1.0f);

	if (underwater) {
		fovy += (float)sin(lastmillis / 1000.0) * 2.0f;
		aspect += (float)sin(lastmillis / 1000.0 + PI) * 0.1f;
		glFogi(GL_FOG_START, 0);
		glFogi(GL_FOG_END, (fog + 96) / 8);
	}

	glClear((player1.outsideMap ? GL_COLOR_BUFFER_BIT : 0) |
	    GL_DEPTH_BUFFER_BIT);

	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	int farplane = fog * 5 / 2;
	gluPerspective(fovy, aspect, 0.15f, farplane);
	glMatrixMode(GL_MODELVIEW);

	transplayer();

	glEnable(GL_TEXTURE_2D);

	int xs, ys;
	skyoglid = lookuptexture(DEFAULT_SKY, &xs, &ys);

	resetcubes();

	curvert = 0;
	[strips removeAllItems];

	render_world(player1.origin.x, player1.origin.y, player1.origin.z,
	    (int)player1.yaw, (int)player1.pitch, (float)fov, w, h);
	finishstrips();

	gl_setupworld();

	renderstripssky();

	glLoadIdentity();
	glRotated(player1.pitch, -1.0, 0.0, 0.0);
	glRotated(player1.yaw, 0.0, 1.0, 0.0);
	glRotated(90.0, 1.0, 0.0, 0.0);
	glColor3f(1.0f, 1.0f, 1.0f);
	glDisable(GL_FOG);
	glDepthFunc(GL_GREATER);
	draw_envbox(14, fog * 4 / 3);
	glDepthFunc(GL_LESS);
	glEnable(GL_FOG);

	transplayer();

	overbright(2);

	renderstrips();

	xtraverts = 0;

	renderclients();
	[Monster renderAll];

	renderentities();

	renderspheres(curtime);
	renderents();

	glDisable(GL_CULL_FACE);

	drawhudgun(fovy, aspect, farplane);

	overbright(1);
	int nquads = renderwater(hf);

	overbright(2);
	render_particles(curtime);
	overbright(1);

	glDisable(GL_FOG);

	glDisable(GL_TEXTURE_2D);

	gl_drawhud(w, h, (int)curfps, nquads, curvert, underwater);

	glEnable(GL_CULL_FACE);
	glEnable(GL_FOG);
}
