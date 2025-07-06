SUBDIRS_AFTER = server

PROG = cube
SRCS = Alias.m			\
       Client.m			\
       Command.m		\
       ConsoleLine.m		\
       Cube.m			\
       DynamicEntity.m		\
       Entity.m			\
       Identifier.m		\
       KeyMapping.m		\
       MD2.m			\
       MapModelInfo.m		\
       Menu.m			\
       MenuItem.m		\
       Monster.m		\
       OFColor+Cube.m		\
       OFString+Cube.m		\
       Player.m			\
       Projectile.m		\
       ResolverResult.m		\
       ResolverThread.m		\
       ServerEntity.m		\
       ServerInfo.m		\
       Variable.m		\
       clients.m		\
       clientextras.m		\
       clientgame.m		\
       clients2c.m		\
       commands.m		\
       console.m		\
       editing.m		\
       entities.m		\
       init.m			\
       menus.m			\
       physics.m		\
       rendercubes.m		\
       renderextras.m		\
       rendergl.m		\
       rendermd2.m		\
       renderparticles.m	\
       rendertext.m		\
       rndmap.m			\
       savegamedemo.m		\
       server.m			\
       serverbrowser.m		\
       serverms.m		\
       serverutil.m		\
       sound.m			\
       tools.m			\
       weapon.m			\
       world.m			\
       worldio.m		\
       worldlight.m		\
       worldocull.m		\
       worldrender.m

include ../buildsys.mk
include ../extra.mk

CC = ${OBJC}
CPPFLAGS += ${SDL_CFLAGS} ${zlib_CFLAGS} ${enet_CFLAGS}
LDFLAGS += ${GUI_LDFLAGS}
LIBS := ${SDL_LIBS} ${zlib_LIBS} ${enet_LIBS} ${OPENGL_LIBS} ${LIBS}
