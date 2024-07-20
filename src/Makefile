PROG = client

SRCS = client.o			\
       clientextras.o		\
       clientgame.o		\
       clients2c.o		\
       command.o		\
       console.o		\
       editing.o		\
       entities.o		\
       main.o			\
       menus.o			\
       monster.o		\
       physics.o		\
       rendercubes.o		\
       renderextras.o		\
       rendergl.o		\
       rendermd2.o		\
       renderparticles.o	\
       rendertext.o		\
       rndmap.o			\
       savegamedemo.o		\
       server.o			\
       serverbrowser.o		\
       serverms.o		\
       serverutil.o		\
       sound.o			\
       tools.o			\
       weapon.o			\
       world.o			\
       worldio.o		\
       worldlight.o		\
       worldocull.o		\
       worldrender.o

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
