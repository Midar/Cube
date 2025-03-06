// console.cpp: the console buffer, its display, and command line control

#include "cube.h"

#include <ctype.h>
#include <memory>

#import "KeyMapping.h"

struct cline {
	char *cref;
	int outtime;
};
vector<cline> conlines;

const int ndraw = 5;
const int WORDWRAP = 80;
int conskip = 0;

bool saycommandon = false;
string commandbuf;

void
setconskip(int n)
{
	conskip += n;
	if (conskip < 0)
		conskip = 0;
}
COMMANDN(conskip, setconskip, ARG_1INT)

static void
conline(OFString *sf, bool highlight) // add a line to the console buffer
{
	cline cl;
	cl.cref = conlines.length() > 100
	              ? conlines.pop().cref
	              : newstringbuf(""); // constrain the buffer size
	cl.outtime = lastmillis;          // for how long to keep line on screen
	conlines.insert(0, cl);
	if (highlight) // show line in a different colour, for chat etc.
	{
		cl.cref[0] = '\f';
		cl.cref[1] = 0;
		strcat_s(cl.cref, sf.UTF8String);
	} else {
		strcpy_s(cl.cref, sf.UTF8String);
	}
	puts(cl.cref);
#ifndef OF_WINDOWS
	fflush(stdout);
#endif
}

void
conoutf(OFConstantString *format, ...)
{
	@autoreleasepool {
		va_list arguments;
		va_start(arguments, format);

		OFString *string = [[OFString alloc] initWithFormat:format
		                                          arguments:arguments];

		va_end(arguments);

		int n = 0;
		while (string.length > WORDWRAP) {
			conline([string substringToIndex:WORDWRAP], n++ != 0);
			string = [string substringFromIndex:WORDWRAP];
		}
		conline(string, n != 0);
	}
}

void
renderconsole() // render buffer taking into account time & scrolling
{
	int nd = 0;
	char *refs[ndraw];
	loopv(conlines) if (conskip ? i >= conskip - 1 ||
	                                  i >= conlines.length() - ndraw
	                            : lastmillis - conlines[i].outtime < 20000)
	{
		refs[nd++] = conlines[i].cref;
		if (nd == ndraw)
			break;
	}
	@autoreleasepool {
		loopj(nd)
		{
			draw_text(@(refs[j]), FONTH / 3,
			    (FONTH / 4 * 5) * (nd - j - 1) + FONTH / 3, 2);
		}
	}
}

// keymap is defined externally in keymap.cfg

static OFMutableArray<KeyMapping *> *keyMappings = nil;

void
keymap(OFString *code, OFString *key, OFString *action)
{
	if (keyMappings == nil)
		keyMappings = [[OFMutableArray alloc] init];

	KeyMapping *mapping =
	    [[KeyMapping alloc] initWithCode:(int)code.longLongValue name:key];
	mapping.action = action;
	[keyMappings addObject:mapping];
}
COMMAND(keymap, ARG_3STR)

void
bindkey(OFString *key, OFString *action)
{
	for (KeyMapping *mapping in keyMappings) {
		if ([mapping.name caseInsensitiveCompare:key] ==
		    OFOrderedSame) {
			mapping.action = action;
			return;
		}
	}

	conoutf(@"unknown key \"%@\"", key);
}
COMMANDN(bind, bindkey, ARG_2STR)

void
saycommand(char *init) // turns input to the command line on or off
{
	saycommandon = (init != NULL);
	if (saycommandon)
		SDL_StartTextInput();
	else
		SDL_StopTextInput();
	if (!editmode)
		Cube.sharedInstance.repeatsKeys = saycommandon;
	if (!init)
		init = "";
	strcpy_s(commandbuf, init);
}
COMMAND(saycommand, ARG_VARI)

void
mapmsg(OFString *s)
{
	@autoreleasepool {
		strn0cpy(hdr.maptitle, s.UTF8String, 128);
	}
}
COMMAND(mapmsg, ARG_1STR)

void
pasteconsole()
{
	char *cb = SDL_GetClipboardText();
	strcat_s(commandbuf, cb);
}

static OFMutableArray<OFString *> *vhistory;
int histpos = 0;

void
history(int n)
{
	static bool rec = false;

	if (!rec && n >= 0 && n < vhistory.count) {
		rec = true;
		OFString *cmd = vhistory[vhistory.count - n - 1];
		std::unique_ptr<char> copy(strdup(cmd.UTF8String));
		execute(copy.get());
		rec = false;
	}
}
COMMAND(history, ARG_1INT)

void
keypress(int code, bool isdown, int cooked)
{
	if (saycommandon) // keystrokes go to commandline
	{
		if (isdown) {
			switch (code) {
			case SDLK_RETURN:
				break;

			case SDLK_BACKSPACE:
			case SDLK_LEFT: {
				for (int i = 0; commandbuf[i]; i++)
					if (!commandbuf[i + 1])
						commandbuf[i] = 0;
				resetcomplete();
				break;
			}

			case SDLK_UP:
				if (histpos) {
					@autoreleasepool {
						strcpy_s(commandbuf,
						    vhistory[--histpos]
						        .UTF8String);
					}
				}
				break;

			case SDLK_DOWN:
				if (histpos < vhistory.count) {
					@autoreleasepool {
						strcpy_s(commandbuf,
						    vhistory[histpos++]
						        .UTF8String);
					}
				}
				break;

			case SDLK_TAB:
				complete(commandbuf);
				break;

			case SDLK_v:
				if (SDL_GetModState() &
				    (KMOD_LCTRL | KMOD_RCTRL)) {
					pasteconsole();
					return;
				};

			default:
				resetcomplete();
				if (cooked) {
					char add[] = {(char)cooked, 0};
					strcat_s(commandbuf, add);
				}
			}
		} else {
			if (code == SDLK_RETURN) {
				if (commandbuf[0]) {
					@autoreleasepool {
						OFString *cmdbuf =
						    @(commandbuf);

						if (vhistory == nil)
							vhistory =
							    [[OFMutableArray
							        alloc] init];

						if (vhistory.count == 0 ||
						    ![vhistory.lastObject
						        isEqual:cmdbuf]) {
							// cap this?
							[vhistory
							    addObject:cmdbuf];
						}
					}
					histpos = vhistory.count;
					if (commandbuf[0] == '/')
						execute(commandbuf, true);
					else
						toserver(commandbuf);
				}
				saycommand(NULL);
			} else if (code == SDLK_ESCAPE) {
				saycommand(NULL);
			}
		}
	} else if (!menukey(code, isdown)) {
		// keystrokes go to menu

		for (KeyMapping *mapping in keyMappings) {
			if (mapping.code == code) {
				// keystrokes go to game, lookup in keymap and
				// execute
				string temp;
				strcpy_s(temp, mapping.action.UTF8String);
				execute(temp, isdown);
				return;
			}
		}
	}
}

char *
getcurcommand()
{
	return saycommandon ? commandbuf : NULL;
}

void
writebinds(OFStream *stream)
{
	for (KeyMapping *mapping in keyMappings)
		if (mapping.action.length > 0)
			[stream writeFormat:@"bind \"%@\" [%@]\n", mapping.name,
			        mapping.action];
}
