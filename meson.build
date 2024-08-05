project('Cube', ['c', 'objcpp'],
  meson_version: '>=1.5.0')

add_global_arguments(
  [
    '-fobjc-arc',
    '-fobjc-arc-exceptions'
  ],
  language: 'objcpp')

objfw_dep = dependency('objfw')
sdl12_dep = dependency('sdl12_compat')
sdlimage_dep = dependency('SDL_image')
sdlmixer_dep = dependency('SDL_mixer')
zlib_dep = dependency('zlib')

client_link_args = []
server_link_args = []
extra_deps = []

if host_machine.system() == 'windows'
  client_link_args += ['-lopengl32', '-lglu32', '-lwinmm']
  server_link_args += ['-lwinmm']
else
  extra_deps += dependency('gl')
  extra_deps += dependency('glu')
  extra_deps += dependency('x11')
endif

subdir('enet')
subdir('src')
