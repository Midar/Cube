PROG = client

SRCS = client.cxx		\
       clientextras.cxx		\
       clientgame.cxx		\
       clients2c.cxx		\
       command.cxx		\
       console.cxx		\
       editing.cxx		\
       entities.cxx		\
       main.cxx			\
       menus.cxx		\
       monster.cxx		\
       physics.cxx		\
       rendercubes.cxx		\
       renderextras.cxx		\
       rendergl.cxx		\
       rendermd2.cxx		\
       renderparticles.cxx	\
       rendertext.cxx		\
       rndmap.cxx		\
       savegamedemo.cxx		\
       server.cxx		\
       serverbrowser.cxx	\
       serverms.cxx		\
       serverutil.cxx		\
       sound.cxx		\
       tools.cxx		\
       weapon.cxx		\
       world.cxx		\
       worldio.cxx		\
       worldlight.cxx		\
       worldocull.cxx		\
       worldrender.cxx

include ../buildsys.mk
include ../extra.mk

CPPFLAGS += -I../enet/include	\
	    ${SDL_CFLAGS}	\
	    ${GL_CFLAGS}	\
	    ${GLU_CFLAGS}	\
	    ${X11_CFLAGS}	\
	    ${ZLIB_CFLAGS}
CXXFLAGS += -fpermissive
LIBS += -L../enet -lenet	\
	${SDL_LIBS}		\
	${GL_LIBS}		\
	${GLU_LIBS}		\
	${X11_LIBS}		\
	${ZLIB_LIBS}
LD = ${CXX}
