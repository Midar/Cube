// main.cpp: initialisation & main loop

#include "cube.h"

OF_APPLICATION_DELEGATE(Cube)

@implementation Cube
- (void)showMessage:(OFString *)msg
{
#ifdef _WIN32
	MessageBoxW(
	    NULL, msg.UTF16String, L"cube fatal error", MB_OK | MB_SYSTEMMODAL);
#else
	[OFStdOut writeString:msg];
#endif
}

- (void)applicationWillTerminate:(OFNotification *)notification
{
	stop();
	disconnect(true);
	writecfg();
	cleangl();
	cleansound();
	cleanupserver();
	SDL_ShowCursor(1);
	SDL_Quit();
}

void
quit() // normal exit
{
	writeservercfg();
	[OFApplication.sharedApplication terminateWithStatus:0];
}

void
fatal(OFString *s, OFString *o) // failure exit
{
	OFString *msg =
	    [OFString stringWithFormat:@"%@%@ (%s)\n", s, o, SDL_GetError()];

	OFApplication *app = OFApplication.sharedApplication;
	[(Cube *)app.delegate showMessage:msg];
	[app terminateWithStatus:1];
}

void *
alloc(int s) // for some big chunks... most other allocs use the memory pool
{
	void *b = calloc(1, s);
	if (!b)
		fatal(@"out of memory!");
	return b;
}

SDL_Window *window;
int scr_w = 640;
int scr_h = 480;

void
screenshot()
{
	SDL_Surface *image;
	SDL_Surface *temp;
	int idx;
	if (image = SDL_CreateRGBSurface(SDL_SWSURFACE, scr_w, scr_h, 24,
	        0x0000FF, 0x00FF00, 0xFF0000, 0)) {
		if (temp = SDL_CreateRGBSurface(SDL_SWSURFACE, scr_w, scr_h, 24,
		        0x0000FF, 0x00FF00, 0xFF0000, 0)) {
			glReadPixels(0, 0, scr_w, scr_h, GL_RGB,
			    GL_UNSIGNED_BYTE, image->pixels);
			for (idx = 0; idx < scr_h; idx++) {
				char *dest =
				    (char *)temp->pixels + 3 * scr_w * idx;
				memcpy(dest,
				    (char *)image->pixels +
				        3 * scr_w * (scr_h - 1 - idx),
				    3 * scr_w);
				endianswap(dest, 3, scr_w);
			};
			sprintf_sd(buf)(
			    "screenshots/screenshot_%d.bmp", lastmillis);
			SDL_SaveBMP(temp, path(buf));
			SDL_FreeSurface(temp);
		};
		SDL_FreeSurface(image);
	};
}

COMMAND(screenshot, ARG_NONE)
COMMAND(quit, ARG_NONE)

bool keyrepeat = false;

VARF(gamespeed, 10, 100, 1000, if (multiplayer()) gamespeed = 100);
VARP(minmillis, 0, 5, 1000);

int framesinmap = 0;

- (void)applicationDidFinishLaunching:(OFNotification *)notification
{
	bool dedicated, windowed;
	int par = 0, uprate = 0, maxcl = 4;
	OFString *__autoreleasing sdesc, *__autoreleasing ip;
	OFString *__autoreleasing master, *__autoreleasing passwd;

	processInitQueue();

#define log(s) conoutf(@"init: %s", s)
	log("sdl");

	const OFOptionsParserOption options[] = {
	    {'d', @"dedicated", 0, &dedicated, NULL},
	    {'t', @"window", 0, &windowed, NULL},
	    {'w', @"width", 1, NULL, NULL}, {'h', @"height", 1, NULL, NULL},
	    {'u', @"upload-rate", 1, NULL, NULL},
	    {'n', @"server-desc", 1, NULL, &sdesc}, {'i', @"ip", 1, NULL, &ip},
	    {'m', @"master", 1, NULL, &master},
	    {'p', @"password", 1, NULL, &passwd},
	    {'c', @"max-clients", 1, NULL, NULL}, {'\0', nil, 0, NULL, NULL}};
	OFOptionsParser *optionsParser =
	    [OFOptionsParser parserWithOptions:options];
	OFUnichar option;
	while ((option = [optionsParser nextOption]) != '\0') {
		switch (option) {
		case 'w':
			scr_w = optionsParser.argument.longLongValue;
			break;
		case 'h':
			scr_h = optionsParser.argument.longLongValue;
			break;
		case 'u':
			uprate = optionsParser.argument.longLongValue;
			break;
		case 'c':
			maxcl = optionsParser.argument.longLongValue;
			break;
		case ':':
		case '=':
		case '?':
			conoutf(@"unknown commandline option");
			[OFApplication terminateWithStatus:1];
		}
	}

	if (sdesc == nil)
		sdesc = @"";
	if (ip == nil)
		ip = @"";
	if (passwd == nil)
		passwd = @"";

	if (SDL_Init(SDL_INIT_TIMER | SDL_INIT_VIDEO | par) < 0)
		fatal(@"Unable to initialize SDL");

	log("net");
	if (enet_initialize() < 0)
		fatal(@"Unable to initialise network module");

	initclient();
	// never returns if dedicated
	initserver(dedicated, uprate, sdesc.UTF8String, ip.UTF8String,
	    master.UTF8String, passwd, maxcl);

	log("world");
	empty_world(7, true);

	log("video: sdl");
	if (SDL_InitSubSystem(SDL_INIT_VIDEO) < 0)
		fatal(@"Unable to initialize SDL Video");

	log("video: mode");
	SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
	if ((window = SDL_CreateWindow("cube engine", SDL_WINDOWPOS_UNDEFINED,
	         SDL_WINDOWPOS_UNDEFINED, scr_w, scr_h,
	         SDL_WINDOW_SHOWN | SDL_WINDOW_OPENGL |
	             (!windowed ? SDL_WINDOW_FULLSCREEN : 0))) == NULL ||
	    SDL_GL_CreateContext(window) == NULL)
		fatal(@"Unable to create OpenGL screen");

	log("video: misc");
	SDL_SetWindowGrab(window, SDL_TRUE);
	SDL_SetRelativeMouseMode(SDL_TRUE);
	keyrepeat = false;
	SDL_ShowCursor(0);

	log("gl");
	gl_init(scr_w, scr_h);

	log("basetex");
	int xs, ys;
	if (!installtex(2, path(newstring("data/newchars.png")), xs, ys) ||
	    !installtex(3, path(newstring("data/martin/base.png")), xs, ys) ||
	    !installtex(6, path(newstring("data/martin/ball1.png")), xs, ys) ||
	    !installtex(7, path(newstring("data/martin/smoke.png")), xs, ys) ||
	    !installtex(8, path(newstring("data/martin/ball2.png")), xs, ys) ||
	    !installtex(9, path(newstring("data/martin/ball3.png")), xs, ys) ||
	    !installtex(4, path(newstring("data/explosion.jpg")), xs, ys) ||
	    !installtex(5, path(newstring("data/items.png")), xs, ys) ||
	    !installtex(1, path(newstring("data/crosshair.png")), xs, ys))
		fatal(@"could not find core textures (hint: run cube from the "
		      @"parent of the bin directory)");

	log("sound");
	initsound();

	log("cfg");
	newmenu(@"frags\tpj\tping\tteam\tname");
	newmenu(@"ping\tplr\tserver");
	exec(@"data/keymap.cfg");
	exec(@"data/menus.cfg");
	exec(@"data/prefabs.cfg");
	exec(@"data/sounds.cfg");
	exec(@"servers.cfg");
	if (!execfile(@"config.cfg"))
		execfile(@"data/defaults.cfg");
	exec(@"autoexec.cfg");

	log("localconnect");
	localconnect();
	// if this map is changed, also change depthcorrect()
	changemap(@"metl3");

	log("mainloop");
	int ignore = 5;
	for (;;) {
		int millis = SDL_GetTicks() * gamespeed / 100;
		if (millis - lastmillis > 200)
			lastmillis = millis - 200;
		else if (millis - lastmillis < 1)
			lastmillis = millis - 1;
		if (millis - lastmillis < minmillis)
			SDL_Delay(minmillis - (millis - lastmillis));
		cleardlights();
		updateworld(millis);
		if (!demoplayback)
			serverslice((int)time(NULL), 0);
		static float fps = 30.0f;
		fps = (1000.0f / curtime + fps * 50) / 51;
		computeraytable(player1->o.x, player1->o.y);
		readdepth(scr_w, scr_h);
		SDL_GL_SwapWindow(window);
		extern void updatevol();
		updatevol();
		if (framesinmap++ <
		    5) // cheap hack to get rid of initial sparklies, even when
		       // triple buffering etc.
		{
			player1->yaw += 5;
			gl_drawframe(scr_w, scr_h, fps);
			player1->yaw -= 5;
		}
		gl_drawframe(scr_w, scr_h, fps);
		SDL_Event event;
		int lasttype = 0, lastbut = 0;
		while (SDL_PollEvent(&event)) {
			switch (event.type) {
			case SDL_QUIT:
				quit();
				break;

			case SDL_KEYDOWN:
			case SDL_KEYUP:
				if (keyrepeat || event.key.repeat == 0)
					keypress(event.key.keysym.sym,
					    event.key.state == SDL_PRESSED,
					    event.key.keysym.sym);
				break;

			case SDL_MOUSEMOTION:
				if (ignore) {
					ignore--;
					break;
				}
				mousemove(event.motion.xrel, event.motion.yrel);
				break;

			case SDL_MOUSEBUTTONDOWN:
			case SDL_MOUSEBUTTONUP:
				if (lasttype == event.type &&
				    lastbut == event.button.button)
					break; // why?? get event twice without
					       // it
				keypress(-event.button.button,
				    event.button.state != 0, 0);
				lasttype = event.type;
				lastbut = event.button.button;
				break;
			}
		}
	}
	quit();
}
@end
