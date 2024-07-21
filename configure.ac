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

AC_PROG_CC
AC_PROG_CPP
AC_PROG_OBJCXX(clang++ g++)
AC_PROG_OBJCXXCPP

AC_CHECK_TOOL(OBJFW_CONFIG, objfw-config)
AS_IF([test x"$OBJFW_CONFIG" = x""], [
	AC_MSG_ERROR(You need ObjFW and objfw-config installed!)
])
OBJCXXFLAGS="$OBJCXXFLAGS $($OBJFW_CONFIG --cppflags --objcflags)"
LDFLAGS="$($OBJFW_CONFIG --ldflags --rpath)"
LIBS="$($OBJFW_CONFIG --libs) $LIBS"

AC_PATH_TOOL(AR, ar)
AC_PATH_TOOL(RANLIB, ranlib)

PKG_CHECK_MODULES(SDL, [
	sdl12_compat >= 1.2
	SDL_image >= 1.2
	SDL_mixer >= 1.2
])
PKG_CHECK_MODULES(GL, gl)
PKG_CHECK_MODULES(GLU, glu)
PKG_CHECK_MODULES(ZLIB, zlib)

case "$host_os" in
mingw32*)
	;;
*)
	PKG_CHECK_MODULES(X11, x11)
	;;
esac

AC_CONFIG_FILES([buildsys.mk extra.mk])
AC_OUTPUT
