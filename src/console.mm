// console.cpp: the console buffer, its display, and command line control

#include "cube.h"

#include <ctype.h>

#import "ConsoleLine.h"
#import "KeyMapping.h"
#import "OFString+Cube.h"

static OFMutableArray<ConsoleLine *> *conlines;

const int ndraw = 5;
const int WORDWRAP = 80;
int conskip = 0;

bool saycommandon = false;
static OFMutableString *commandbuf;

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
	OFMutableString *text;

	// constrain the buffer size
	if (conlines.count > 100) {
		text = [conlines.lastObject.text mutableCopy];
		[conlines removeLastObject];
	} else
		text = [OFMutableString string];

	if (highlight)
		// show line in a different colour, for chat etc.
		[text appendString:@"\f"];

	[text appendString:sf];

	if (conlines == nil)
		conlines = [[OFMutableArray alloc] init];

	[conlines insertObject:[ConsoleLine lineWithText:text
	                                         outtime:lastmillis]
	               atIndex:0];

	puts(text.UTF8String);
#ifndef OF_WINDOWS
	fflush(stdout);
#endif
}

void
conoutf(OFConstantString *format, ...)
{
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

// render buffer taking into account time & scrolling
void
renderconsole()
{
	int nd = 0;
	OFString *refs[ndraw];

	size_t i = 0;
	for (ConsoleLine *conline in conlines) {
		if (conskip ? i >= conskip - 1 || i >= conlines.count - ndraw
		            : lastmillis - conline.outtime < 20000) {
			refs[nd++] = conline.text;
			if (nd == ndraw)
				break;
		}

		i++;
	}

	loopj(nd)
	{
		draw_text(refs[j], FONTH / 3,
		    (FONTH / 4 * 5) * (nd - j - 1) + FONTH / 3, 2);
	}
}

// keymap is defined externally in keymap.cfg

static OFMutableArray<KeyMapping *> *keyMappings = nil;

void
keymap(OFString *code, OFString *key, OFString *action)
{
	if (keyMappings == nil)
		keyMappings = [[OFMutableArray alloc] init];

	KeyMapping *mapping = [KeyMapping mappingWithCode:code.cube_intValue
	                                             name:key];
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
saycommand(OFString *init) // turns input to the command line on or off
{
	saycommandon = (init != nil);
	if (saycommandon)
		SDL_StartTextInput();
	else
		SDL_StopTextInput();

	if (!editmode)
		Cube.sharedInstance.repeatsKeys = saycommandon;

	if (init == nil)
		init = @"";

	commandbuf = [init mutableCopy];
}
COMMAND(saycommand, ARG_VARI)

void
mapmsg(OFString *s)
{
	memset(hdr.maptitle, '\0', sizeof(hdr.maptitle));
	strncpy(hdr.maptitle, s.UTF8String, 127);
}
COMMAND(mapmsg, ARG_1STR)

void
pasteconsole()
{
	[commandbuf appendString:@(SDL_GetClipboardText())];
}

static OFMutableArray<OFString *> *vhistory;
static int histpos = 0;

void
history(int n)
{
	static bool rec = false;

	if (!rec && n >= 0 && n < vhistory.count) {
		rec = true;
		execute(vhistory[vhistory.count - n - 1]);
		rec = false;
	}
}
COMMAND(history, ARG_1INT)

void
keypress(int code, bool isDown)
{
	// keystrokes go to commandline
	if (saycommandon) {
		if (isDown) {
			switch (code) {
			case SDLK_RETURN:
				break;

			case SDLK_BACKSPACE:
			case SDLK_LEFT:
				if (commandbuf.length > 0)
					[commandbuf
					    deleteCharactersInRange:
					        OFMakeRange(
					            commandbuf.length - 1, 1)];

				resetcomplete();
				break;

			case SDLK_UP:
				if (histpos)
					commandbuf =
					    [vhistory[--histpos] mutableCopy];
				break;

			case SDLK_DOWN:
				if (histpos < vhistory.count)
					commandbuf =
					    [vhistory[histpos++] mutableCopy];
				break;

			case SDLK_TAB:
				complete(commandbuf);
				break;

			case SDLK_v:
				if (SDL_GetModState() &
				    (KMOD_LCTRL | KMOD_RCTRL)) {
					pasteconsole();
					return;
				}

			default:
				resetcomplete();
			}
		} else {
			if (code == SDLK_RETURN) {
				if (commandbuf.length > 0) {
					if (vhistory == nil)
						vhistory =
						    [[OFMutableArray alloc]
						        init];

					if (vhistory.count == 0 ||
					    ![vhistory.lastObject
					        isEqual:commandbuf]) {
						// cap this?
						[vhistory addObject:[commandbuf
						                        copy]];
					}
					histpos = vhistory.count;
					if ([commandbuf hasPrefix:@"/"])
						execute(commandbuf, true);
					else
						toserver(commandbuf);
				}
				saycommand(NULL);
			} else if (code == SDLK_ESCAPE) {
				saycommand(NULL);
			}
		}
	} else if (!menukey(code, isDown)) {
		// keystrokes go to menu

		for (KeyMapping *mapping in keyMappings) {
			if (mapping.code == code) {
				// keystrokes go to game, lookup in keymap and
				// execute
				execute(mapping.action, isDown);
				return;
			}
		}
	}
}

void
input(OFString *text)
{
	if (saycommandon)
		[commandbuf appendString:text];
}

OFString *
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
