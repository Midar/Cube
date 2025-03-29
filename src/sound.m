#include "cube.h"

#import "Command.h"
#import "Player.h"
#import "Variable.h"

#include <SDL_mixer.h>

VARP(soundvol, 0, 255, 255);
VARP(musicvol, 0, 128, 255);
bool nosound = false;

#define MAXCHAN 32
#define SOUNDFREQ 22050
#define MAXVOL MIX_MAX_VOLUME

struct soundloc {
	OFVector3D loc;
	bool inuse;
} soundlocs[MAXCHAN];

static Mix_Music *mod = NULL;

void
stopsound()
{
	if (nosound)
		return;

	if (mod != NULL) {
		Mix_HaltMusic();
		Mix_FreeMusic(mod);
		mod = NULL;
	}
}

VAR(soundbufferlen, 128, 1024, 4096);

void
initsound()
{
	memset(soundlocs, 0, sizeof(struct soundloc) * MAXCHAN);
	if (Mix_OpenAudio(SOUNDFREQ, MIX_DEFAULT_FORMAT, 2, soundbufferlen) <
	    0) {
		conoutf(@"sound init failed (SDL_mixer): %s",
		    (size_t)Mix_GetError());
		nosound = true;
	}
	Mix_AllocateChannels(MAXCHAN);
}

COMMAND(music, ARG_1STR, (^ (OFString *name) {
	if (nosound)
		return;

	stopsound();

	if (soundvol && musicvol) {
		name = [name stringByReplacingOccurrencesOfString: @"\\"
		                                       withString: @"/"];
		OFString *path = [OFString stringWithFormat:
		    @"packages/%@", name];
		OFIRI *IRI = [Cube.sharedInstance.gameDataIRI
		    IRIByAppendingPathComponent: path];

		if ((mod = Mix_LoadMUS(
		         IRI.fileSystemRepresentation.UTF8String)) != NULL) {
			Mix_PlayMusic(mod, -1);
			Mix_VolumeMusic((musicvol * MAXVOL) / 255);
		}
	}
}))

static OFMutableData *samples;
static OFMutableArray<OFString *> *snames;

COMMAND(registersound, ARG_1EST, ^int(OFString *name) {
	int i = 0;
	for (OFString *iter in snames) {
		if ([iter isEqual: name])
			return i;

		i++;
	}

	if (snames == nil)
		snames = [[OFMutableArray alloc] init];
	if (samples == nil)
		samples = [[OFMutableData alloc]
		    initWithItemSize: sizeof(Mix_Chunk *)];

	[snames addObject: [name stringByReplacingOccurrencesOfString: @"\\"
							   withString: @"/"]];
	Mix_Chunk *sample = NULL;
	[samples addItem: &sample];

	return samples.count - 1;
})

void
cleansound()
{
	if (nosound)
		return;
	stopsound();
	Mix_CloseAudio();
}

VAR(stereo, 0, 1, 1);

static void
updatechanvol(int chan, const OFVector3D *loc)
{
	int vol = soundvol, pan = 255 / 2;

	if (loc) {
		OFVector3D origin = Player.player1.origin;
		float dist = OFDistanceOfVectors3D(origin, *loc);
		OFVector3D v = OFSubtractVectors3D(origin, *loc);

		// simple mono distance attenuation
		vol -= (int)(dist * 3 * soundvol / 255);

		if (stereo && (v.x != 0 || v.y != 0)) {
			// relative angle of sound along X-Y axis
			float yaw = -atan2(v.x, v.y) -
			    Player.player1.yaw * (PI / 180.0f);
			// range is from 0 (left) to 255 (right)
			pan = (int)(255.9f * (0.5 * sin(yaw) + 0.5f));
		}
	}

	vol = (vol * MAXVOL) / 255;
	Mix_Volume(chan, vol);
	Mix_SetPanning(chan, 255 - pan, pan);
}

static void
newsoundloc(int chan, const OFVector3D *loc)
{
	assert(chan >= 0 && chan < MAXCHAN);
	soundlocs[chan].loc = *loc;
	soundlocs[chan].inuse = true;
}

void
updatevol()
{
	if (nosound)
		return;

	for (int i = 0; i < MAXCHAN; i++) {
		if (soundlocs[i].inuse) {
			if (Mix_Playing(i))
				updatechanvol(i, &soundlocs[i].loc);
			else
				soundlocs[i].inuse = false;
		}
	}
}

void
playsoundc(int n)
{
	addmsg(0, 2, SV_SOUND, n);
	playsound(n, NULL);
}

int soundsatonce = 0, lastsoundmillis = 0;

void
playsound(int n, const OFVector3D *loc)
{
	if (nosound)
		return;

	if (!soundvol)
		return;

	if (lastmillis == lastsoundmillis)
		soundsatonce++;
	else
		soundsatonce = 1;

	lastsoundmillis = lastmillis;

	if (soundsatonce > 5)
		// avoid bursts of sounds with heavy packetloss and in sp
		return;

	if (n < 0 || n >= samples.count) {
		conoutf(@"unregistered sound: %d", n);
		return;
	}

	Mix_Chunk **sample = (Mix_Chunk **)[samples mutableItemAtIndex: n];
	if (*sample == NULL) {
		OFString *path = [OFString stringWithFormat:
		    @"packages/sounds/%@.wav", snames[n]];
		OFIRI *IRI = [Cube.sharedInstance.gameDataIRI
		    IRIByAppendingPathComponent: path];

		*sample = Mix_LoadWAV(IRI.fileSystemRepresentation.UTF8String);

		if (*sample == NULL) {
			conoutf(@"failed to load sample: %@", IRI.string);
			return;
		}
	}

	int chan = Mix_PlayChannel(-1, *sample, 0);
	if (chan < 0)
		return;

	if (loc)
		newsoundloc(chan, loc);

	updatechanvol(chan, loc);
}

COMMAND(sound, ARG_1INT, ^ (int n) {
	playsound(n, NULL);
})
