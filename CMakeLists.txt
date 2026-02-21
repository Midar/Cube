cmake_minimum_required(VERSION 3.31.10)
project(
	Cube
	VERSION 0.1
	HOMEPAGE_URL https://git.nil.im/js/Cube
	LANGUAGES OBJC
)

find_package(ObjFW 1.5 REQUIRED)
find_package(SDL2 REQUIRED)
find_package(SDL2_image REQUIRED)
find_package(SDL2_mixer REQUIRED)
find_package(ZLIB REQUIRED)

find_package(PkgConfig REQUIRED)
pkg_check_modules(ENET REQUIRED libenet)

add_subdirectory(src)
