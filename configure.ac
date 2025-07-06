AC_INIT(cube, 0.1, js@nil.im)
AC_CONFIG_SRCDIR(src)
AC_CONFIG_AUX_DIR(build-aux)
AC_CONFIG_MACRO_DIR(build-aux/m4)

for i in configure.ac build-aux/m4/*; do
	AS_IF([test $i -nt configure], [
		AC_MSG_ERROR([$i is newer than configure! Run ./autogen.sh!])
	])
done

BUILDSYS_INIT

AC_CANONICAL_HOST

AC_CHECK_TOOL(OBJFW_CONFIG, objfw-config)
AS_IF([test x"$OBJFW_CONFIG" = x""], [
	AC_MSG_ERROR(You need ObjFW and objfw-config installed!)
])

test x"$OBJC" = x"" && OBJC="$($OBJFW_CONFIG --objc)"

AC_LANG([Objective C])
AC_PROG_OBJC
AC_PROG_OBJCPP

CPP="$OBJCPP"
CPPFLAGS="$CPPFLAGS $OBJCPPFLAGS"
CPPFLAGS="$CPPFLAGS $($OBJFW_CONFIG $OBJFW_CONFIG_FLAGS --cppflags)"
OBJCFLAGS="$OBJCFLAGS $($OBJFW_CONFIG $OBJFW_CONFIG_FLAGS --objcflags --arc)"
LDFLAGS="$LDFLAGS $($OBJFW_CONFIG $OBJFW_CONFIG_FLAGS --ldflags)"
LIBS="$($OBJFW_CONFIG $OBJFW_CONFIG_FLAGS --libs --rpath) $LIBS"

AX_CHECK_COMPILER_FLAGS(-std=gnu11, [
	OBJCFLAGS="$OBJCFLAGS -std=gnu11"
], [
	AX_CHECK_COMPILER_FLAGS(-std=gnu1x, [
		OBJCFLAGS="$OBJCFLAGS -std=gnu1x"
	], [
		AX_CHECK_COMPILER_FLAGS(-std=gnu99,
			[OBJCFLAGS="$OBJCFLAGS -std=gnu99"])
	])
])

PKG_CHECK_MODULES(SDL, [sdl2 SDL2_image SDL2_mixer])
PKG_CHECK_MODULES(zlib, [zlib])
PKG_CHECK_MODULES(enet, [libenet])

case "$host_os" in
darwin*)
	AC_SUBST(OPENGL_LIBS, "-framework OpenGL")
	;;
mingw*)
	LIBS="$LIBS -lwinmm"
	AC_SUBST(GUI_LDFLAGS, "-mwindows")
	AC_SUBST(OPENGL_LIBS, "-lopengl32 -lglu32")
	;;
*)
	AC_SUBST(OPENGL_LIBS, "-lGL -lGLU -lX11")
	;;
esac

AC_CONFIG_FILES([buildsys.mk extra.mk])
AC_OUTPUT
