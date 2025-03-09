// main.cpp: initialisation & main loop

#include "cube.h"

OF_APPLICATION_DELEGATE(Cube)

VARF(gamespeed, 10, 100, 1000, if (multiplayer()) gamespeed = 100);
VARP(minmillis, 0, 5, 1000);

@implementation Cube
{
	int _width, _height;
}

+ (Cube *)sharedInstance
{
	return (Cube *)OFApplication.sharedApplication.delegate;
}

- (void)applicationDidFinishLaunching:(OFNotification *)notification
{
	bool dedicated, windowed;
	int par = 0, uprate = 0, maxcl = 4;
	OFString *__autoreleasing sdesc, *__autoreleasing ip;
	OFString *__autoreleasing master, *__autoreleasing passwd;

	processInitQueue();

#define log(s) conoutf(@"init: %@", s)
	log(@"sdl");

	const OFOptionsParserOption options[] = { { 'd', @"dedicated", 0,
		                                      &dedicated, NULL },
		{ 't', @"window", 0, &windowed, NULL },
		{ 'w', @"width", 1, NULL, NULL },
		{ 'h', @"height", 1, NULL, NULL },
		{ 'u', @"upload-rate", 1, NULL, NULL },
		{ 'n', @"server-desc", 1, NULL, &sdesc },
		{ 'i', @"ip", 1, NULL, &ip },
		{ 'm', @"master", 1, NULL, &master },
		{ 'p', @"password", 1, NULL, &passwd },
		{ 'c', @"max-clients", 1, NULL, NULL },
		{ '\0', nil, 0, NULL, NULL } };
	OFOptionsParser *optionsParser =
	    [OFOptionsParser parserWithOptions:options];
	OFUnichar option;
	while ((option = [optionsParser nextOption]) != '\0') {
		switch (option) {
		case 'w':
			_width = (int)optionsParser.argument.longLongValue;
			break;
		case 'h':
			_height = (int)optionsParser.argument.longLongValue;
			break;
		case 'u':
			uprate = (int)optionsParser.argument.longLongValue;
			break;
		case 'c':
			maxcl = (int)optionsParser.argument.longLongValue;
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

	_gameDataIRI = [OFFileManager.defaultManager currentDirectoryIRI];
	_userDataIRI = [OFFileManager.defaultManager currentDirectoryIRI];

	[OFFileManager.defaultManager
	    createDirectoryAtIRI:[_userDataIRI
	                             IRIByAppendingPathComponent:@"demos"]
	           createParents:true];
	[OFFileManager.defaultManager
	    createDirectoryAtIRI:[_userDataIRI
	                             IRIByAppendingPathComponent:@"savegames"]
	           createParents:true];

	if (SDL_Init(SDL_INIT_TIMER | SDL_INIT_VIDEO | par) < 0)
		fatal(@"Unable to initialize SDL");

	log(@"net");
	if (enet_initialize() < 0)
		fatal(@"Unable to initialise network module");

	initclient();
	// never returns if dedicated
	initserver(dedicated, uprate, sdesc, ip, master, passwd, maxcl);

	log(@"world");
	empty_world(7, true);

	log(@"video: sdl");
	if (SDL_InitSubSystem(SDL_INIT_VIDEO) < 0)
		fatal(@"Unable to initialize SDL Video");

	if (_width == 0 || _height == 0) {
		SDL_DisplayMode mode;

		if (SDL_GetDesktopDisplayMode(0, &mode) == 0) {
			_width = mode.w;
			_height = mode.h;
		} else {
			_width = 1920;
			_height = 1080;
		}
	}

	log(@"video: mode");
	SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
	if ((_window = SDL_CreateWindow("cube engine", SDL_WINDOWPOS_UNDEFINED,
	         SDL_WINDOWPOS_UNDEFINED, _width, _height,
	         SDL_WINDOW_SHOWN | SDL_WINDOW_OPENGL |
	             (!windowed ? SDL_WINDOW_FULLSCREEN : 0))) == NULL ||
	    SDL_GL_CreateContext(_window) == NULL)
		fatal(@"Unable to create OpenGL screen");

	log(@"video: misc");
	SDL_SetWindowGrab(_window, SDL_TRUE);
	SDL_SetRelativeMouseMode(SDL_TRUE);
	SDL_ShowCursor(0);

	log(@"gl");
	gl_init(_width, _height);

	log(@"basetex");
	int xs, ys;
	if (!installtex(2,
	        [_gameDataIRI IRIByAppendingPathComponent:@"data/newchars.png"],
	        &xs, &ys, false) ||
	    !installtex(3,
	        [_gameDataIRI
	            IRIByAppendingPathComponent:@"data/martin/base.png"],
	        &xs, &ys, false) ||
	    !installtex(6,
	        [_gameDataIRI
	            IRIByAppendingPathComponent:@"data/martin/ball1.png"],
	        &xs, &ys, false) ||
	    !installtex(7,
	        [_gameDataIRI
	            IRIByAppendingPathComponent:@"data/martin/smoke.png"],
	        &xs, &ys, false) ||
	    !installtex(8,
	        [_gameDataIRI
	            IRIByAppendingPathComponent:@"data/martin/ball2.png"],
	        &xs, &ys, false) ||
	    !installtex(9,
	        [_gameDataIRI
	            IRIByAppendingPathComponent:@"data/martin/ball3.png"],
	        &xs, &ys, false) ||
	    !installtex(4,
	        [_gameDataIRI
	            IRIByAppendingPathComponent:@"data/explosion.jpg"],
	        &xs, &ys, false) ||
	    !installtex(5,
	        [_gameDataIRI IRIByAppendingPathComponent:@"data/items.png"],
	        &xs, &ys, false) ||
	    !installtex(1,
	        [_gameDataIRI
	            IRIByAppendingPathComponent:@"data/crosshair.png"],
	        &xs, &ys, false))
		fatal(@"could not find core textures (hint: run cube from the "
		      @"parent of the bin directory)");

	log(@"sound");
	initsound();

	log(@"cfg");
	newmenu(@"frags\tpj\tping\tteam\tname");
	newmenu(@"ping\tplr\tserver");
	exec(@"data/keymap.cfg");
	exec(@"data/menus.cfg");
	exec(@"data/prefabs.cfg");
	exec(@"data/sounds.cfg");
	exec(@"servers.cfg");
	if (!execfile([_userDataIRI IRIByAppendingPathComponent:@"config.cfg"]))
		execfile([_gameDataIRI
		    IRIByAppendingPathComponent:@"data/defaults.cfg"]);
	exec(@"autoexec.cfg");

	log(@"localconnect");
	localconnect();
	// if this map is changed, also change depthcorrect()
	changemap(@"metl3");

	log(@"mainloop");
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
		readdepth(_width, _height);
		SDL_GL_SwapWindow(_window);
		extern void updatevol();
		updatevol();

		// cheap hack to get rid of initial sparklies, even when triple
		// buffering etc.
		if (_framesInMap++ < 5) {
			player1->yaw += 5;
			gl_drawframe(_width, _height, fps);
			player1->yaw -= 5;
		}

		gl_drawframe(_width, _height, fps);

		SDL_Event event;
		int lasttype = 0, lastbut = 0;
		while (SDL_PollEvent(&event)) {
			switch (event.type) {
			case SDL_QUIT:
				[self quit];
				break;
			case SDL_KEYDOWN:
			case SDL_KEYUP:
				if (_repeatsKeys || event.key.repeat == 0)
					keypress(event.key.keysym.sym,
					    event.key.state == SDL_PRESSED);
				break;
			case SDL_TEXTINPUT:
				@autoreleasepool {
					input(@(event.text.text));
				}
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
					// why?? get event twice without it
					break;

				keypress(-event.button.button,
				    event.button.state != 0);
				lasttype = event.type;
				lastbut = event.button.button;
				break;
			}
		}
	}

	[self quit];
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

- (void)showMessage:(OFString *)msg
{
#ifdef _WIN32
	MessageBoxW(
	    NULL, msg.UTF16String, L"cube fatal error", MB_OK | MB_SYSTEMMODAL);
#else
	[OFStdOut writeString:msg];
#endif
}

- (void)screenshot
{
	SDL_Surface *image;
	SDL_Surface *temp;

	if ((image = SDL_CreateRGBSurface(SDL_SWSURFACE, _width, _height, 24,
	         0x0000FF, 0x00FF00, 0xFF0000, 0)) != NULL) {
		if ((temp = SDL_CreateRGBSurface(SDL_SWSURFACE, _width, _height,
		         24, 0x0000FF, 0x00FF00, 0xFF0000, 0)) != NULL) {
			glReadPixels(0, 0, _width, _height, GL_RGB,
			    GL_UNSIGNED_BYTE, image->pixels);

			for (int idx = 0; idx < _height; idx++) {
				char *dest =
				    (char *)temp->pixels + 3 * _width * idx;
				memcpy(dest,
				    (char *)image->pixels +
				        3 * _width * (_height - 1 - idx),
				    3 * _width);
				endianswap(dest, 3, _width);
			}

			@autoreleasepool {
				OFString *path = [OFString
				    stringWithFormat:
				        @"screenshots/screenshot_%d.bmp",
				    lastmillis];
				SDL_SaveBMP(temp,
				    [_userDataIRI
				        IRIByAppendingPathComponent:path]
				        .fileSystemRepresentation.UTF8String);
			}
			SDL_FreeSurface(temp);
		}

		SDL_FreeSurface(image);
	}
}

- (void)quit
{
	writeservercfg();
	[OFApplication terminateWithStatus:0];
}
@end

void
fatal(OFString *s, OFString *o) // failure exit
{
	OFString *msg =
	    [OFString stringWithFormat:@"%@%@ (%s)\n", s, o, SDL_GetError()];

	[Cube.sharedInstance showMessage:msg];
	[OFApplication terminateWithStatus:1];
}

void
quit() // normal exit
{
	[Cube.sharedInstance quit];
}
COMMAND(quit, ARG_NONE)

void
screenshot()
{
	[Cube.sharedInstance screenshot];
}
COMMAND(screenshot, ARG_NONE)
