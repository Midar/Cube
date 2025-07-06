PROG = cube_server
SRCS = Client.m		\
       Entity.m		\
       ServerEntity.m	\
       server.m		\
       serverms.m	\
       serverutil.m	\
       tools.m

include ../../buildsys.mk
include ../../extra.mk

CC = ${OBJC}
CPPFLAGS += -DSTANDALONE ${SDL_CFLAGS} ${enet_CFLAGS}
LIBS += ${SDL_LIBS} ${enet_LIBS}
