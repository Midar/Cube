// command.cpp: implements the parsing and execution of a tiny script language
// which is largely backwards compatible with the quake console language.

#include "cube.h"

#import "Alias.h"
#import "Command.h"
#import "Identifier.h"
#import "OFString+Cube.h"
#import "Variable.h"

static void
cleanup(char **string)
{
	free(*string);
}

void
alias(OFString *name, OFString *action)
{
	Alias *alias = Identifier.identifiers[name];

	if (alias == nil)
		Identifier.identifiers[name] = [Alias aliasWithName: name
							     action: action
							  persisted: true];
	else {
		if ([alias isKindOfClass: Alias.class])
			alias.action = action;
		else
			conoutf(
			    @"cannot redefine builtin %@ with an alias", name);
	}
}

COMMAND(alias, ARG_2STR, ^ (OFString *name, OFString *action) {
	alias(name, action);
})

void
setvar(OFString *name, int i)
{
	Variable *variable = Identifier.identifiers[name];

	if ([variable isKindOfClass: Variable.class])
		variable.value = i;
}

int
getvar(OFString *name)
{
	Variable *variable = Identifier.identifiers[name];

	if ([variable isKindOfClass: Variable.class])
		return variable.value;

	return 0;
}

bool
identexists(OFString *name)
{
	return (Identifier.identifiers[name] != nil);
}

OFString *
getalias(OFString *name)
{
	Alias *alias = Identifier.identifiers[name];

	if ([alias isKindOfClass: Alias.class])
		return alias.action;

	return nil;
}

// parse any nested set of () or []
static char *
parseexp(char **p, int right)
{
	int left = *(*p)++;
	char *word = *p;
	for (int brak = 1; brak;) {
		int c = *(*p)++;
		if (c == '\r')
			*(*p - 1) = ' '; // hack
		if (c == left)
			brak++;
		else if (c == right)
			brak--;
		else if (!c) {
			(*p)--;
			conoutf(@"missing \"%c\"", right);
			return NULL;
		}
	}
	char *s = strndup(word, *p - word - 1);
	if (left == '(') {
		OFString *t;
		@try {
			t = [OFString stringWithFormat:
			    @"%d", execute(@(s), true)];
		} @finally {
			free(s);
		}
		s = strdup(t.UTF8String);
	}
	return s;
}

// parse single argument, including expressions
static char *
parseword(char **p)
{
	(*p) += strspn(*p, " \t\r");
	if ((*p)[0] == '/' && (*p)[1] == '/')
		*p += strcspn(*p, "\n\0");
	if (**p == '\"') {
		(*p)++;
		char *word = *p;
		*p += strcspn(*p, "\"\r\n\0");
		char *s = strndup(word, *p - word);
		if (**p == '\"')
			(*p)++;
		return s;
	}
	if (**p == '(')
		return parseexp(p, ')');
	if (**p == '[')
		return parseexp(p, ']');
	char *word = *p;
	*p += strcspn(*p, "; \t\r\n\0");
	if (*p - word == 0)
		return NULL;
	return strndup(word, *p - word);
}

// find value of ident referenced with $ in exp
OFString *
lookup(OFString *n)
{
	__kindof Identifier *identifier =
	    Identifier.identifiers[[n substringFromIndex: 1]];

	if ([identifier isKindOfClass: Variable.class]) {
		return [OFString stringWithFormat:
		    @"%d", [identifier value]];
	} else if ([identifier isKindOfClass: Alias.class])
		return [identifier action];

	conoutf(@"unknown alias lookup: %@", [n substringFromIndex: 1]);
	return n;
}

int
executeIdentifier(__kindof Identifier *identifier,
    OFArray<OFString *> *arguments, bool isDown)
{
	if (identifier == nil) {
		@try {
			return [arguments[0] intValueWithBase: 0];
		} @catch (OFInvalidFormatException *e) {
			conoutf(@"unknown command: %@", arguments[0]);
			return 0;
		} @catch (OFOutOfRangeException *e) {
			conoutf(@"invalid value: %@", arguments[0]);
			return 0;
		}
	}

	if ([identifier isKindOfClass: Command.class])
		// game defined commands use very ad-hoc function signature,
		// and just call it
		return [identifier callWithArguments: arguments isDown: isDown];

	if ([identifier isKindOfClass: Variable.class]) {
		if (!isDown)
			return 0;

		// game defined variables
		if (arguments.count < 2 || arguments[1].length == 0)
			[identifier printValue];
		else
			[identifier setValue:
			    [arguments[1] cube_intValueWithBase: 0]];
	}

	if ([identifier isKindOfClass: Alias.class]) {
		// alias, also used as functions and (global) variables
		for (int i = 1; i < arguments.count; i++) {
			// set any arguments as (global) arg values so
			// functions can access them
			OFString *t = [OFString stringWithFormat: @"arg%d", i];
			alias(t, arguments[i]);
		}

		return execute([identifier action], isDown);
	}

	return 0;
}

// all evaluation happens here, recursively
int
execute(OFString *string, bool isDown)
{
	char *copy __attribute__((__cleanup__(cleanup))) =
	    strdup(string.UTF8String);
	char *p = copy;
	const int MAXWORDS = 25; // limit, remove
	OFString *w[MAXWORDS];
	int val = 0;
	for (bool cont = true; cont;) {
		// for each ; seperated statement
		int numargs = MAXWORDS;
		for (int i = 0; i < MAXWORDS; i++) {
			// collect all argument values
			w[i] = @"";
			if (i > numargs)
				continue;
			// parse and evaluate exps
			char *s = parseword(&p);
			if (!s) {
				numargs = i;
				s = strdup("");
			}
			@try {
				if (*s == '$')
					// substitute variables
					w[i] = lookup(@(s));
				else
					w[i] = @(s);
			} @finally {
				free(s);
			}
		}

		p += strcspn(p, ";\n\0");
		// more statements if this isn't the end of the string
		cont = *p++ != 0;
		OFString *c = w[0];
		// strip irc-style command prefix
		if ([c hasPrefix: @"/"]) {
			c = [c substringFromIndex: 1];
			w[0] = c;
		}
		// empty statement
		if (c.length == 0)
			continue;

		val = executeIdentifier(Identifier.identifiers[c],
		    [OFArray arrayWithObjects: w count: numargs], isDown);
	}

	return val;
}

// tab-completion of all identifiers

int completesize = 0, completeidx = 0;

void
resetcomplete()
{
	completesize = 0;
}

void
complete(OFMutableString *s)
{
	if (![s hasPrefix: @"/"])
		[s insertString: @"/" atIndex: 0];

	if (s.length == 1)
		return;

	if (!completesize) {
		completesize = s.length - 1;
		completeidx = 0;
	}

	__block int idx = 0;
	[Identifier.identifiers enumerateKeysAndObjectsUsingBlock:
	    ^ (OFString *name, __kindof Identifier *identifier, bool *stop) {
		if (strncmp(identifier.name.UTF8String, s.UTF8String + 1,
		    completesize) == 0 && idx++ == completeidx)
			[s replaceCharactersInRange: OFMakeRange(
							 1, s.length - 1)
					 withString: identifier.name];
	}];

	completeidx++;

	if (completeidx >= idx)
		completeidx = 0;
}

bool
execfile(OFIRI *cfgfile)
{
	OFString *command;
	@try {
		command = [OFString stringWithContentsOfIRI: cfgfile];
	} @catch (OFOpenItemFailedException *e) {
		return false;
	} @catch (OFReadFailedException *e) {
		return false;
	}

	execute(command, true);
	return true;
}

void
exec(OFString *cfgfile)
{
	if (!execfile([Cube.sharedInstance.userDataIRI
	    IRIByAppendingPathComponent: cfgfile]) &&
	    !execfile([Cube.sharedInstance.gameDataIRI
	    IRIByAppendingPathComponent: cfgfile]))
		conoutf(@"could not read \"%@\"", cfgfile);
}

COMMAND(exec, ARG_1STR, ^ (OFString *cfgfile) {
	exec(cfgfile);
})

void
writecfg()
{
	OFStream *stream;
	@try {
		OFIRI *IRI = [Cube.sharedInstance.userDataIRI
		    IRIByAppendingPathComponent: @"config.cfg"];
		stream = [[OFIRIHandler handlerForIRI: IRI]
		    openItemAtIRI: IRI
			     mode: @"w"];
	} @catch (id e) {
		return;
	}

	[stream writeString:
	    @"// automatically written on exit, do not modify\n"
	    @"// delete this file to have defaults.cfg overwrite these "
	    @"settings\n"
	    @"// modify settings in game, or put settings in autoexec.cfg to "
	    @"override anything\n"
	    @"\n"];
	writeclientinfo(stream);
	[stream writeString: @"\n"];

	[Identifier.identifiers enumerateKeysAndObjectsUsingBlock:
	    ^ (OFString *name, Variable *variable, bool *stop) {
		if (![variable isKindOfClass: Variable.class] ||
		    !variable.persisted)
			return;

		[stream writeFormat: @"%@ %d\n", variable.name, variable.value];
	}];
	[stream writeString: @"\n"];

	writebinds(stream);
	[stream writeString: @"\n"];

	[Identifier.identifiers enumerateKeysAndObjectsUsingBlock:
	    ^ (OFString *name, Alias *alias, bool *stop) {
		if (![alias isKindOfClass: Alias.class] ||
		    [alias.name hasPrefix: @"nextmap_"])
			return;

		[stream writeFormat: @"alias \"%@\" [%@]\n",
				     alias.name, alias.action];
	}];

	[stream close];
}

COMMAND(writecfg, ARG_NONE, ^ {
	writecfg();
})

// below the commands that implement a small imperative language. thanks to the
// semantics of () and [] expressions, any control construct can be defined
// trivially.

void
intset(OFString *name, int v)
{
	alias(name, [OFString stringWithFormat: @"%d", v]);
}

COMMAND(if, ARG_3STR, ^ (OFString *cond, OFString *thenp, OFString *elsep) {
	execute((![cond hasPrefix: @"0"] ? thenp : elsep), true);
})

COMMAND(loop, ARG_2STR, ^ (OFString *times, OFString *body) {
	int t = times.cube_intValue;

	for (int i = 0; i < t; i++) {
		intset(@"i", i);
		execute(body, true);
	}
})

COMMAND(while, ARG_2STR, ^ (OFString *cond, OFString *body) {
	while (execute(cond, true))
		execute(body, true);
})

COMMAND(onrelease, ARG_DWN1, ^ (bool on, OFString *body) {
	if (!on)
		execute(body, true);
})

void
concat(OFString *s)
{
	alias(@"s", s);
}

COMMAND(concat, ARG_VARI, ^ (OFString *s) {
	concat(s);
})

COMMAND(concatword, ARG_VARI, ^ (OFString *s) {
	concat([s stringByReplacingOccurrencesOfString: @" " withString: @""]);
})

COMMAND(listlen, ARG_1EST, ^ (OFString *a_) {
	const char *a = a_.UTF8String;

	if (!*a)
		return 0;

	int n = 0;
	while (*a)
		if (*a++ == ' ')
			n++;

	return n + 1;
})

COMMAND(at, ARG_2STR, ^ (OFString *s_, OFString *pos) {
	int n = pos.cube_intValue;
	char *copy __attribute__((__cleanup__(cleanup))) =
	    strdup(s_.UTF8String);
	char *s = copy;
	for (int i = 0; i < n; i++) {
		s += strcspn(s, " \0");
		s += strspn(s, " ");
	}
	s[strcspn(s, " \0")] = 0;
	concat(@(s));
})

COMMAND(+, ARG_2EXP, ^ (int a, int b) {
	return a + b;
})

COMMAND(*, ARG_2EXP, ^ (int a, int b) {
	return a * b;
})

COMMAND(-, ARG_2EXP, ^ (int a, int b) {
	return a - b;
})

COMMAND(div, ARG_2EXP, ^ (int a, int b) {
	return b ? a / b : 0;
})

COMMAND(mod, ARG_2EXP, ^ (int a, int b) {
	return b ? a % b : 0;
})

COMMAND(=, ARG_2EXP, ^ (int a, int b) {
	return (int)(a == b);
})

COMMAND(<, ARG_2EXP, ^ (int a, int b) {
	return (int)(a < b);
})

COMMAND(>, ARG_2EXP, ^ (int a, int b) {
	return (int)(a > b);
})

COMMAND(strcmp, ARG_2EST, ^ (OFString *a, OFString *b) {
	return [a isEqual: b];
})

COMMAND(rnd, ARG_1EXP, ^ (int a) {
	return (a > 0 ? rnd(a) : 0);
})

COMMAND(millis, ARG_1EXP, ^ (int unused) {
	return lastmillis;
})
