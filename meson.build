project('Cube', ['c', 'objc'],
  meson_version: '>=1.5.0',
  default_options: {
    'optimization': '2'
  })

add_global_arguments(
  [
    '-fobjc-arc',
    '-fobjc-arc-exceptions'
  ],
  language: 'objc')

objfw_dep = dependency('objfw')
sdl_dep = dependency('SDL2')
sdlimage_dep = dependency('SDL2_image')
sdlmixer_dep = dependency('SDL2_mixer')
zlib_dep = dependency('zlib')

client_link_args = []
server_link_args = []
extra_deps = []

if host_machine.system() == 'windows'
  client_link_args += ['-lopengl32', '-lglu32', '-lwinmm']
  server_link_args += ['-lwinmm']
elif host_machine.system() == 'darwin'
  extra_deps += dependency('OpenGL', method: 'extraframework')
else
  extra_deps += dependency('gl')
  extra_deps += dependency('glu')
  extra_deps += dependency('x11')
endif

subdir('enet')
subdir('src')
