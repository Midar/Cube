// command.cpp: implements the parsing and execution of a tiny script language
// which is largely backwards compatible with the quake console language.

#include "cube.h"

#include <memory>

#import "Alias.h"
#import "Command.h"
#import "Identifier.h"
#import "Variable.h"

void
itoa(char *s, int i)
{
	sprintf_s(s)("%d", i);
}

char *
exchangestr(char *o, const char *n)
{
	gp()->deallocstr(o);
	return newstring(n);
}

// contains ALL vars/commands/aliases
static OFMutableDictionary<OFString *, __kindof Identifier *> *identifiers;

void
alias(OFString *name, OFString *action)
{
	Alias *alias = identifiers[name];

	if (alias == nil) {
		alias = [[Alias alloc] initWithName:name
		                             action:action
		                          persisted:true];

		if (identifiers == nil)
			identifiers = [[OFMutableDictionary alloc] init];

		identifiers[name] = alias;
	} else {
		if ([alias isKindOfClass:[Alias class]])
			alias.action = action;
		else
			conoutf(
			    @"cannot redefine builtin %@ with an alias", name);
	}
}
COMMAND(alias, ARG_2STR)

int
variable(OFString *name, int min, int cur, int max, int *storage,
    void (*function)(), bool persisted)
{
	Variable *variable = [[Variable alloc] initWithName:name
	                                                min:min
	                                                max:max
	                                            storage:storage
	                                           function:function
	                                          persisted:persisted];

	if (identifiers == nil)
		identifiers = [[OFMutableDictionary alloc] init];

	identifiers[name] = variable;

	return cur;
}

void
setvar(OFString *name, int i)
{
	*[identifiers[name] storage] = i;
}

int
getvar(OFString *name)
{
	return *[identifiers[name] storage];
}

bool
identexists(OFString *name)
{
	return (identifiers[name] != nil);
}

OFString *
getalias(OFString *name)
{
	Alias *alias = identifiers[name];

	if ([alias isKindOfClass:[Alias class]])
		return alias.action;

	return nil;
}

bool
addcommand(OFString *name, void (*function)(), int argumentsTypes)
{
	Command *command = [[Command alloc] initWithName:name
	                                        function:function
	                                  argumentsTypes:argumentsTypes];

	if (identifiers == nil)
		identifiers = [[OFMutableDictionary alloc] init];

	identifiers[name] = command;

	return false;
}

char *
parseexp(char *&p, int right) // parse any nested set of () or []
{
	int left = *p++;
	char *word = p;
	for (int brak = 1; brak;) {
		int c = *p++;
		if (c == '\r')
			*(p - 1) = ' '; // hack
		if (c == left)
			brak++;
		else if (c == right)
			brak--;
		else if (!c) {
			p--;
			conoutf(@"missing \"%c\"", right);
			return NULL;
		}
	}
	char *s = newstring(word, p - word - 1);
	if (left == '(') {
		string t;
		// evaluate () exps directly, and substitute result
		@autoreleasepool {
			itoa(t, execute(@(s)));
		}
		s = exchangestr(s, t);
	}
	return s;
}

char *
parseword(char *&p) // parse single argument, including expressions
{
	p += strspn(p, " \t\r");
	if (p[0] == '/' && p[1] == '/')
		p += strcspn(p, "\n\0");
	if (*p == '\"') {
		p++;
		char *word = p;
		p += strcspn(p, "\"\r\n\0");
		char *s = newstring(word, p - word);
		if (*p == '\"')
			p++;
		return s;
	}
	if (*p == '(')
		return parseexp(p, ')');
	if (*p == '[')
		return parseexp(p, ']');
	char *word = p;
	p += strcspn(p, "; \t\r\n\0");
	if (p - word == 0)
		return NULL;
	return newstring(word, p - word);
}

OFString *
lookup(OFString *n) // find value of ident referenced with $ in exp
{
	@autoreleasepool {
		__kindof Identifier *identifier =
		    identifiers[[n substringFromIndex:1]];

		if ([identifier isKindOfClass:[Variable class]]) {
			return [OFString
			    stringWithFormat:@"%d", *[identifier storage]];
		} else if ([identifier isKindOfClass:[Alias class]])
			return [identifier action];
	}

	conoutf(@"unknown alias lookup: %@", [n substringFromIndex:1]);
	return n;
}

int
execute(
    OFString *string, bool isdown) // all evaluation happens here, recursively
{
	@autoreleasepool {
		std::unique_ptr<char> copy(strdup(string.UTF8String));
		char *p = copy.get();
		const int MAXWORDS = 25; // limit, remove
		OFString *w[MAXWORDS];
		int val = 0;
		for (bool cont = true; cont;) {
			// for each ; seperated statement
			int numargs = MAXWORDS;
			loopi(MAXWORDS)
			{
				// collect all argument values
				w[i] = @"";
				if (i > numargs)
					continue;
				// parse and evaluate exps
				char *s = parseword(p);
				if (!s) {
					numargs = i;
					s = "";
				}
				if (*s == '$')
					// substitute variables
					w[i] = lookup(@(s));
				else
					w[i] = @(s);
			}

			p += strcspn(p, ";\n\0");
			// more statements if this isn't the end of the string
			cont = *p++ != 0;
			OFString *c = w[0];
			// strip irc-style command prefix
			if ([c hasPrefix:@"/"])
				c = [c substringFromIndex:1];
			// empty statement
			if (c.length == 0)
				continue;

			__kindof Identifier *identifier = identifiers[c];
			if (identifier == nil) {
				@try {
					val = (int)[c longLongValueWithBase:0];
				} @catch (OFInvalidFormatException *e) {
					conoutf(@"unknown command: %s", c);
				}
			} else {
				if ([identifier
				        isKindOfClass:[Command class]]) {
					// game defined commands use very
					// ad-hoc function signature, and just
					// call it
					OFArray<OFString *> *arguments =
					    [[OFArray alloc]
					        initWithObjects:w
					                  count:numargs + 1];
					val = [identifier
					    callWithArguments:arguments
					               isDown:isdown];
				} else if ([identifier
				               isKindOfClass:[Variable
				                                 class]]) {
					// game defined variables
					if (isdown) {
						if (w[1].length == 0)
							[identifier printValue];
						else
							[identifier
							    setValue:
							        (int)[w[1]
							            longLongValueWithBase:
							                0]];
					}
				} else if ([identifier
				               isKindOfClass:[Alias class]]) {
					// alias, also used as functions and
					// (global) variables
					for (int i = 1; i < numargs; i++) {
						// set any arguments as
						// (global) arg values so
						// functions can access them
						OFString *t = [OFString
						    stringWithFormat:@"arg%d",
						    i];
						alias(t, w[i]);
					}
					// create new string here because alias
					// could rebind itself
					val = execute(
					    [[identifier action] copy], isdown);
					break;
				}
			}
		}

		return val;
	}
}

// tab-completion of all identifiers

int completesize = 0, completeidx = 0;

void
resetcomplete()
{
	completesize = 0;
}

void
complete(OFString *s_)
{
	@autoreleasepool {
		std::unique_ptr<char> copy(strdup(s_.UTF8String));
		char *s = copy.get();

		if (*s != '/') {
			string t;
			strcpy_s(t, s);
			strcpy_s(s, "/");
			strcat_s(s, t);
		}

		if (!s[1])
			return;

		if (!completesize) {
			completesize = strlen(s) - 1;
			completeidx = 0;
		}

		__block int idx = 0;
		[identifiers enumerateKeysAndObjectsUsingBlock:^(
		    OFString *name, Identifier *identifier, bool *stop) {
			if (strncmp(identifier.name.UTF8String, s + 1,
			        completesize) == 0 &&
			    idx++ == completeidx) {
				strcpy_s(s, "/");
				strcat_s(s, identifier.name.UTF8String);
			}
		}];

		completeidx++;

		if (completeidx >= idx)
			completeidx = 0;
	}
}

bool
execfile(OFString *cfgfile)
{
	@autoreleasepool {
		OFMutableData *data;
		@try {
			data = [OFMutableData dataWithContentsOfFile:cfgfile];
		} @catch (id e) {
			return false;
		}

		// Ensure \0 termination.
		[data addItem:""];

		execute(@((char *)data.mutableItems));
		return true;
	}
}

void
exec(OFString *cfgfile)
{
	if (!execfile(cfgfile)) {
		@autoreleasepool {
			conoutf(@"could not read \"%@\"", cfgfile);
		}
	}
}

void
writecfg()
{
	OFStream *stream;
	@try {
		OFIRI *IRI = [Cube.sharedInstance.userDataIRI
		    IRIByAppendingPathComponent:@"config.cfg"];
		stream = [[OFIRIHandler handlerForIRI:IRI] openItemAtIRI:IRI
		                                                    mode:@"w"];
	} @catch (id e) {
		return;
	}

	[stream writeString:
	            @"// automatically written on exit, do not modify\n"
	            @"// delete this file to have defaults.cfg overwrite these "
	            @"settings\n"
	            @"// modify settings in game, or put settings in "
	            @"autoexec.cfg to override anything\n"
	            @"\n"];
	writeclientinfo(stream);
	[stream writeString:@"\n"];

	[identifiers enumerateKeysAndObjectsUsingBlock:^(
	    OFString *name, __kindof Identifier *identifier, bool *stop) {
		if (![identifier isKindOfClass:[Variable class]] ||
		    ![identifier persisted])
			return;

		[stream writeFormat:@"%@ %d\n", identifier.name,
		        *[identifier storage]];
	}];
	[stream writeString:@"\n"];

	writebinds(stream);
	[stream writeString:@"\n"];

	[identifiers enumerateKeysAndObjectsUsingBlock:^(
	    OFString *name, __kindof Identifier *identifier, bool *stop) {
		if (![identifier isKindOfClass:[Alias class]] ||
		    [identifier.name hasPrefix:@"nextmap_"])
			return;

		[stream writeFormat:@"alias \"%@\" [%@]\n", identifier.name,
		        [identifier action]];
	}];

	[stream close];
}

COMMAND(writecfg, ARG_NONE)

// below the commands that implement a small imperative language. thanks to the
// semantics of
// () and [] expressions, any control construct can be defined trivially.

void
intset(OFString *name, int v)
{
	@autoreleasepool {
		alias(name, [OFString stringWithFormat:@"%d", v]);
	}
}

void
ifthen(OFString *cond, OFString *thenp, OFString *elsep)
{
	execute((![cond hasPrefix:@"0"] ? thenp : elsep));
}

void
loopa(OFString *times, OFString *body)
{
	@autoreleasepool {
		int t = (int)times.longLongValue;

		loopi(t)
		{
			intset(@"i", i);
			execute(body);
		}
	}
}

void
whilea(OFString *cond, OFString *body)
{
	while (execute(cond))
		execute(body);
}

void
onrelease(bool on, OFString *body)
{
	if (!on)
		execute(body);
}

void
concat(OFString *s)
{
	alias(@"s", s);
}

void
concatword(OFString *s)
{
	// The original used this code which does nothing:
	// for (char *a = s, *b = s; *a = *b; b++)
	//	if (*a != ' ')
	//		a++;
	concat(s);
}

int
listlen(OFString *a_)
{
	@autoreleasepool {
		const char *a = a_.UTF8String;

		if (!*a)
			return 0;

		int n = 0;
		while (*a)
			if (*a++ == ' ')
				n++;

		return n + 1;
	}
}

void
at(OFString *s_, OFString *pos)
{
	@autoreleasepool {
		int n = (int)pos.longLongValue;
		std::unique_ptr<char> copy(strdup(s_.UTF8String));
		char *s = copy.get();

		loopi(n) s += strspn(s += strcspn(s, " \0"), " ");
		s[strcspn(s, " \0")] = 0;
		concat(@(s));
	}
}

COMMANDN(loop, loopa, ARG_2STR)
COMMANDN(while, whilea, ARG_2STR)
COMMANDN(if, ifthen, ARG_3STR)
COMMAND(onrelease, ARG_DWN1)
COMMAND(exec, ARG_1STR)
COMMAND(concat, ARG_VARI)
COMMAND(concatword, ARG_VARI)
COMMAND(at, ARG_2STR)
COMMAND(listlen, ARG_1EST)

int
add(int a, int b)
{
	return a + b;
}
COMMANDN(+, add, ARG_2EXP)

int
mul(int a, int b)
{
	return a * b;
}
COMMANDN(*, mul, ARG_2EXP)

int
sub(int a, int b)
{
	return a - b;
}
COMMANDN(-, sub, ARG_2EXP)

int
divi(int a, int b)
{
	return b ? a / b : 0;
}
COMMANDN(div, divi, ARG_2EXP)

int
mod(int a, int b)
{
	return b ? a % b : 0;
}
COMMAND(mod, ARG_2EXP)

int
equal(int a, int b)
{
	return (int)(a == b);
}
COMMANDN(=, equal, ARG_2EXP)

int
lt(int a, int b)
{
	return (int)(a < b);
}
COMMANDN(<, lt, ARG_2EXP)

int
gt(int a, int b)
{
	return (int)(a > b);
}
COMMANDN(>, gt, ARG_2EXP)

int
strcmpa(OFString *a, OFString *b)
{
	return [a isEqual:b];
}
COMMANDN(strcmp, strcmpa, ARG_2EST)

int
rndn(int a)
{
	return a > 0 ? rnd(a) : 0;
}
COMMANDN(rnd, rndn, ARG_1EXP)

int
explastmillis()
{
	return lastmillis;
}
COMMANDN(millis, explastmillis, ARG_1EXP)
