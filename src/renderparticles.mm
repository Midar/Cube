// renderparticles.cpp

#include "cube.h"

const int MAXPARTICLES = 10500;
const int NUMPARTCUTOFF = 20;
struct particle {
	OFVector3D o, d;
	int fade, type;
	int millis;
	particle *next;
};
particle particles[MAXPARTICLES], *parlist = NULL, *parempty = NULL;
bool parinit = false;

VARP(maxparticles, 100, 2000, MAXPARTICLES - 500);

static void
newparticle(const OFVector3D &o, const OFVector3D &d, int fade, int type)
{
	if (!parinit) {
		loopi(MAXPARTICLES)
		{
			particles[i].next = parempty;
			parempty = &particles[i];
		}
		parinit = true;
	}
	if (parempty) {
		particle *p = parempty;
		parempty = p->next;
		p->o = o;
		p->d = d;
		p->fade = fade;
		p->type = type;
		p->millis = lastmillis;
		p->next = parlist;
		parlist = p;
	}
}

VAR(demotracking, 0, 0, 1);
VARP(particlesize, 20, 100, 500);

OFVector3D right, up;

void
setorient(OFVector3D &r, OFVector3D &u)
{
	right = r;
	up = u;
}

void
render_particles(int time)
{
	if (demoplayback && demotracking) {
		OFVector3D nom = OFMakeVector3D(0, 0, 0);
		newparticle(player1->o, nom, 100000000, 8);
	}

	glDepthMask(GL_FALSE);
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_SRC_ALPHA);
	glDisable(GL_FOG);

	struct parttype {
		float r, g, b;
		int gr, tex;
		float sz;
	} parttypes[] = {
		{ 0.7f, 0.6f, 0.3f, 2, 3, 0.06f },  // yellow: sparks
		{ 0.5f, 0.5f, 0.5f, 20, 7, 0.15f }, // grey:   small smoke
		{ 0.2f, 0.2f, 1.0f, 20, 3,
		    0.08f },                       // blue:   edit mode entities
		{ 1.0f, 0.1f, 0.1f, 1, 7, 0.06f }, // red:    blood spats
		{ 1.0f, 0.8f, 0.8f, 20, 6, 1.2f }, // yellow: fireball1
		{ 0.5f, 0.5f, 0.5f, 20, 7, 0.6f }, // grey:   big smoke
		{ 1.0f, 1.0f, 1.0f, 20, 8, 1.2f }, // blue:   fireball2
		{ 1.0f, 1.0f, 1.0f, 20, 9, 1.2f }, // green:  fireball3
		{ 1.0f, 0.1f, 0.1f, 0, 7, 0.2f },  // red:    demotrack
	};

	int numrender = 0;

	for (particle *p, **pp = &parlist; p = *pp;) {
		parttype *pt = &parttypes[p->type];

		glBindTexture(GL_TEXTURE_2D, pt->tex);
		glBegin(GL_QUADS);

		glColor3d(pt->r, pt->g, pt->b);
		float sz = pt->sz * particlesize / 100.0f;
		// perf varray?
		glTexCoord2f(0.0, 1.0);
		glVertex3d(p->o.x + (-right.x + up.x) * sz,
		    p->o.z + (-right.y + up.y) * sz,
		    p->o.y + (-right.z + up.z) * sz);
		glTexCoord2f(1.0, 1.0);
		glVertex3d(p->o.x + (right.x + up.x) * sz,
		    p->o.z + (right.y + up.y) * sz,
		    p->o.y + (right.z + up.z) * sz);
		glTexCoord2f(1.0, 0.0);
		glVertex3d(p->o.x + (right.x - up.x) * sz,
		    p->o.z + (right.y - up.y) * sz,
		    p->o.y + (right.z - up.z) * sz);
		glTexCoord2f(0.0, 0.0);
		glVertex3d(p->o.x + (-right.x - up.x) * sz,
		    p->o.z + (-right.y - up.y) * sz,
		    p->o.y + (-right.z - up.z) * sz);
		glEnd();
		xtraverts += 4;

		if (numrender++ > maxparticles || (p->fade -= time) < 0) {
			*pp = p->next;
			p->next = parempty;
			parempty = p;
		} else {
			if (pt->gr)
				p->o.z -= ((lastmillis - p->millis) / 3.0f) *
				    curtime / (pt->gr * 10000);
			OFVector3D a = p->d;
			vmul(a, time);
			vdiv(a, 20000.0f);
			vadd(p->o, a);
			pp = &p->next;
		}
	}

	glEnable(GL_FOG);
	glDisable(GL_BLEND);
	glDepthMask(GL_TRUE);
}

void
particle_splash(int type, int num, int fade, const OFVector3D &p)
{
	loopi(num)
	{
		const int radius = type == 5 ? 50 : 150;
		int x, y, z;
		do {
			x = rnd(radius * 2) - radius;
			y = rnd(radius * 2) - radius;
			z = rnd(radius * 2) - radius;
		} while (x * x + y * y + z * z > radius * radius);
		newparticle(p, OFMakeVector3D(x, y, z), rnd(fade * 3), type);
	}
}

void
particle_trail(int type, int fade, OFVector3D &s, OFVector3D &e)
{
	vdist(d, v, s, e);
	vdiv(v, d * 2 + 0.1f);
	OFVector3D p = s;
	loopi((int)d * 2)
	{
		vadd(p, v);
		OFVector3D d =
		    OFMakeVector3D(rnd(11) - 5, rnd(11) - 5, rnd(11) - 5);
		newparticle(p, d, rnd(fade) + fade, type);
	}
}
