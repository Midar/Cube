// protos for ALL external functions in cube...

// command
extern int variable(OFString *name, int min, int cur, int max, int *storage,
    void (*fun)(), bool persist);
extern void setvar(OFString *name, int i);
extern int getvar(OFString *name);
extern bool identexists(OFString *name);
extern bool addcommand(OFString *name, void (*fun)(), int narg);
extern int execute(OFString *p, bool down = true);
extern void exec(OFString *cfgfile);
extern bool execfile(OFIRI *cfgfile);
extern void resetcomplete();
extern void complete(OFMutableString *s);
extern void alias(OFString *name, OFString *action);
extern OFString *getalias(OFString *name);
extern void writecfg();

// console
extern void keypress(int code, bool isDown);
extern void input(OFString *text);
extern void renderconsole();
extern void conoutf(OFConstantString *format, ...);
extern OFString *getcurcommand();
extern void writebinds(OFStream *stream);

// init
extern void enqueueInit(void (^init)(void));
extern void processInitQueue(void);

// menus
extern bool rendermenu();
extern void menuset(int menu);
extern void menumanual(int m, int n, OFString *text);
extern void sortmenu();
extern bool menukey(int code, bool isdown);
extern void newmenu(OFString *name);

// serverbrowser
extern void addserver(OFString *servername);
extern OFString *getservername(int n);
extern void writeservercfg();

// rendergl
extern void gl_init(int w, int h);
extern void cleangl();
extern void gl_drawframe(int w, int h, float curfps);
extern bool installtex(int tnum, OFIRI *IRI, int *xs, int *ys, bool clamp);
extern void mipstats(int a, int b, int c);
extern void vertf(float v1, float v2, float v3, sqr *ls, float t1, float t2);
extern void addstrip(int tex, int start, int n);
extern int lookuptexture(int tex, int *xs, int *ys);

// rendercubes
extern void resetcubes();
extern void render_flat(int tex, int x, int y, int size, int h, sqr *l1,
    sqr *l2, sqr *l3, sqr *l4, bool isceil);
extern void render_flatdelta(int wtex, int x, int y, int size, float h1,
    float h2, float h3, float h4, sqr *l1, sqr *l2, sqr *l3, sqr *l4,
    bool isceil);
extern void render_square(int wtex, float floor1, float floor2, float ceil1,
    float ceil2, int x1, int y1, int x2, int y2, int size, sqr *l1, sqr *l2,
    bool topleft);
extern void render_tris(int x, int y, int size, bool topleft, sqr *h1, sqr *h2,
    sqr *s, sqr *t, sqr *u, sqr *v);
extern void addwaterquad(int x, int y, int size);
extern int renderwater(float hf);
extern void finishstrips();
extern void setarraypointers();

// client
extern void localservertoclient(uchar *buf, int len);
extern void connects(OFString *servername);
extern void disconnect(int onlyclean = 0, int async = 0);
extern void toserver(OFString *text);
extern void addmsg(int rel, int num, int type, ...);
extern bool multiplayer();
extern bool allowedittoggle();
extern void sendpackettoserv(void *packet);
extern void gets2c();
extern void c2sinfo(DynamicEntity *d);
extern void neterr(OFString *s);
extern void initclientnet();
extern bool netmapstart();
extern int getclientnum();
extern void changemapserv(OFString *name, int mode);
extern void writeclientinfo(OFStream *stream);

// clientgame
extern void initPlayers();
extern void mousemove(int dx, int dy);
extern void updateworld(int millis);
extern void startmap(OFString *name);
extern void changemap(OFString *name);
extern void initclient();
extern void spawnplayer(DynamicEntity *d);
extern void selfdamage(int damage, int actor, DynamicEntity *act);
extern DynamicEntity *newdynent();
extern OFString *getclientmap();
extern OFString *modestr(int n);
extern DynamicEntity *getclient(int cn);
extern void setclient(int cn, id client);
extern void timeupdate(int timeremain);
extern void resetmovement(DynamicEntity *d);
extern void fixplayer1range();

// clientextras
extern void renderclients();
extern void renderclient(
    DynamicEntity *d, bool team, OFString *mdlname, bool hellpig, float scale);
void showscores(bool on);
extern void renderscores();

// world
extern void setupworld(int factor);
extern void empty_world(int factor, bool force);
extern void remip(block &b, int level = 0);
extern void remipmore(block &b, int level = 0);
extern int closestent();
extern int findentity(int type, int index = 0);
extern void trigger(int tag, int type, bool savegame);
extern void resettagareas();
extern void settagareas();
extern Entity *newentity(
    int x, int y, int z, OFString *what, int v1, int v2, int v3, int v4);

// worldlight
extern void calclight();
extern void dodynlight(const OFVector3D &vold, const OFVector3D &v, int reach,
    int strength, DynamicEntity *owner);
extern void cleardlights();
extern block *blockcopy(block &b);
extern void blockpaste(block &b);

// worldrender
extern void render_world(float vx, float vy, float vh, int yaw, int pitch,
    float widef, int w, int h);

// worldocull
extern void computeraytable(float vx, float vy);
extern int isoccluded(float vx, float vy, float cx, float cy, float csize);

// main
extern void fatal(OFString *s, OFString *o = @"");

// rendertext
extern void draw_text(OFString *string, int left, int top, int gl_num);
extern void draw_textf(
    OFConstantString *format, int left, int top, int gl_num, ...);
extern int text_width(OFString *string);
extern void draw_envbox(int t, int fogdist);

// editing
extern void cursorupdate();
extern void toggleedit();
extern void editdrag(bool isdown);
extern void setvdeltaxy(int delta, block &sel);
extern void editequalisexy(bool isfloor, block &sel);
extern void edittypexy(int type, block &sel);
extern void edittexxy(int type, int t, block &sel);
extern void editheightxy(bool isfloor, int amount, block &sel);
extern bool noteditmode();
extern void pruneundos(int maxremain = 0);

// renderextras
extern void line(int x1, int y1, float z1, int x2, int y2, float z2);
extern void box(block &b, float z1, float z2, float z3, float z4);
extern void dot(int x, int y, float z);
extern void linestyle(float width, int r, int g, int b);
extern void newsphere(const OFVector3D &o, float max, int type);
extern void renderspheres(int time);
extern void gl_drawhud(
    int w, int h, int curfps, int nquads, int curvert, bool underwater);
extern void readdepth(int w, int h);
extern void blendbox(int x1, int y1, int x2, int y2, bool border);
extern void damageblend(int n);

// renderparticles
extern void setorient(OFVector3D &r, OFVector3D &u);
extern void particle_splash(int type, int num, int fade, const OFVector3D &p);
extern void particle_trail(
    int type, int fade, OFVector3D &from, OFVector3D &to);
extern void render_particles(int time);

// worldio
extern void save_world(OFString *fname);
extern void load_world(OFString *mname);
extern void writemap(OFString *mname, int msize, uchar *mdata);
extern OFData *readmap(OFString *mname);
extern void loadgamerest();
extern void incomingdemodata(uchar *buf, int len, bool extras = false);
extern void demoplaybackstep();
extern void stop();
extern void stopifrecording();
extern void demodamage(int damage, const OFVector3D &o);
extern void demoblend(int damage);

// physics
extern void moveplayer(DynamicEntity *pl, int moveres, bool local);
extern bool collide(DynamicEntity *d, bool spawn, float drop, float rise);
extern void entinmap(DynamicEntity *d);
extern void setentphysics(int mml, int mmr);
extern void physicsframe();

// sound
extern void playsound(int n, const OFVector3D *loc = NULL);
extern void playsoundc(int n);
extern void initsound();
extern void cleansound();

// rendermd2
extern void rendermodel(OFString *mdl, int frame, int range, int tex, float rad,
    OFVector3D position, float yaw, float pitch, bool teammate, float scale,
    float speed, int snap = 0, int basetime = 0);
@class MapModelInfo;
extern MapModelInfo *getmminfo(int i);

// server
extern void initserver(bool dedicated, int uprate, OFString *sdesc,
    OFString *ip, OFString *master, OFString *passwd, int maxcl);
extern void cleanupserver();
extern void localconnect();
extern void localdisconnect();
extern void localclienttoserver(struct _ENetPacket *);
extern void serverslice(int seconds, unsigned int timeout);
extern void putint(uchar *&p, int n);
extern int getint(uchar *&p);
extern void sendstring(OFString *t, uchar *&p);
extern void startintermission();
extern void restoreserverstate(OFArray<Entity *> *ents);
extern uchar *retrieveservers(uchar *buf, int buflen);
extern char msgsizelookup(int msg);
extern void serverms(int mode, int numplayers, int minremain,
    OFString *smapname, int seconds, bool isfull);
extern void servermsinit(OFString *master, OFString *sdesc, bool listen);
extern void sendmaps(int n, OFString *mapname, int mapsize, uchar *mapdata);
extern ENetPacket *recvmap(int n);

// weapon
extern void selectgun(int a = -1, int b = -1, int c = -1);
extern void shoot(DynamicEntity *d, const OFVector3D &to);
extern void shootv(int gun, OFVector3D &from, OFVector3D &to,
    DynamicEntity *d = 0, bool local = false);
extern void createrays(OFVector3D &from, OFVector3D &to);
extern void moveprojectiles(float time);
extern void projreset();
extern OFString *playerincrosshair();
extern int reloadtime(int gun);

// monster
extern void monsterclear();
extern void restoremonsterstate();
extern void monsterthink();
extern void monsterrender();
extern OFArray<DynamicEntity *> *getmonsters();
extern void monsterpain(DynamicEntity *m, int damage, DynamicEntity *d);
extern void endsp(bool allkilled);

// entities
extern void initEntities();
extern void renderents();
extern void putitems(uchar *&p);
extern void checkquad(int time);
extern void checkitems();
extern void realpickup(int n, DynamicEntity *d);
extern void renderentities();
extern void resetspawns();
extern void setspawn(uint i, bool on);
extern void teleport(int n, DynamicEntity *d);
extern void baseammo(int gun);

// rndmap
extern void perlinarea(block &b, int scale, int seed, int psize);
