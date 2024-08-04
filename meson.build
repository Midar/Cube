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

link_args = []
extra_deps = []

if host_machine.system() == 'windows'
  link_args += ['-lopengl32', '-lglu32']
else
  extra_deps += dependency('gl')
  extra_deps += dependency('glu')
  extra_deps += dependency('x11')
endif

enet_includes = include_directories('enet/include')
enet = static_library('enet',
  [
    'enet/callbacks.c',
    'enet/host.c',
    'enet/list.c',
    'enet/memory.c',
    'enet/packet.c',
    'enet/peer.c',
    'enet/protocol.c',
    'enet/unix.c',
    'enet/win32.c',
  ],
  include_directories: [enet_includes])

executable('client',
  [
    'src/client.mm',
    'src/clientextras.mm',
    'src/clientgame.mm',
    'src/clients2c.mm',
    'src/command.mm',
    'src/console.mm',
    'src/editing.mm',
    'src/entities.mm',
    'src/init.mm',
    'src/main.mm',
    'src/menus.mm',
    'src/monster.mm',
    'src/physics.mm',
    'src/rendercubes.mm',
    'src/renderextras.mm',
    'src/rendergl.mm',
    'src/rendermd2.mm',
    'src/renderparticles.mm',
    'src/rendertext.mm',
    'src/rndmap.mm',
    'src/savegamedemo.mm',
    'src/server.mm',
    'src/serverbrowser.mm',
    'src/serverms.mm',
    'src/serverutil.mm',
    'src/sound.mm',
    'src/tools.mm',
    'src/weapon.mm',
    'src/world.mm',
    'src/worldio.mm',
    'src/worldlight.mm',
    'src/worldocull.mm',
    'src/worldrender.mm',
  ],
  dependencies: [
    objfw_dep,
    sdl12_dep,
    sdlimage_dep,
    sdlmixer_dep,
    zlib_dep,
    extra_deps
  ],
  include_directories: [enet_includes],
  link_args: link_args,
  link_with: [enet],
  win_subsystem: 'windows')

executable('server',
  [
    'src/server.mm',
    'src/serverms.mm',
    'src/serverutil.mm',
    'src/tools.mm',
  ],
  objcpp_args: ['-DSTANDALONE'],
  dependencies: [
    objfw_dep,
    sdl12_dep
  ],
  include_directories: [enet_includes],
  link_with: [enet],
  win_subsystem: 'console')
