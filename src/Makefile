PROG = client

SRCS = client.mm		\
       clientextras.mm		\
       clientgame.mm		\
       clients2c.mm		\
       command.mm		\
       console.mm		\
       editing.mm		\
       entities.mm		\
       main.mm			\
       menus.mm			\
       monster.mm		\
       physics.mm		\
       rendercubes.mm		\
       renderextras.mm		\
       rendergl.mm		\
       rendermd2.mm		\
       renderparticles.mm	\
       rendertext.mm		\
       rndmap.mm		\
       savegamedemo.mm		\
       server.mm		\
       serverbrowser.mm		\
       serverms.mm		\
       serverutil.mm		\
       sound.mm			\
       tools.mm			\
       weapon.mm		\
       world.mm			\
       worldio.mm		\
       worldlight.mm		\
       worldocull.mm		\
       worldrender.mm

include ../buildsys.mk
include ../extra.mk

CPPFLAGS += -I../enet/include	\
	    ${SDL_CFLAGS}	\
	    ${GL_CFLAGS}	\
	    ${GLU_CFLAGS}	\
	    ${X11_CFLAGS}	\
	    ${ZLIB_CFLAGS}
LIBS += -L../enet -lenet	\
	${SDL_LIBS}		\
	${GL_LIBS}		\
	${GLU_LIBS}		\
	${X11_LIBS}		\
	${ZLIB_LIBS}		\
	-lm
LD = ${OBJCXX}
