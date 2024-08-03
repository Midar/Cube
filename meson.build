project('Cube', ['c', 'objcpp'])

add_global_arguments(
  ['-fobjc-arc', '-fobjc-arc-exceptions'],
  language: 'objcpp')

objfw_dep = dependency('objfw')
sdl12_dep = dependency('sdl12_compat')
sdlimage_dep = dependency('SDL_image')
sdlmixer_dep = dependency('SDL_mixer')
gl_dep = dependency('gl')
glu_dep = dependency('glu')
zlib_dep = dependency('zlib')
x11_dep = dependency('x11', required: false)

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
    gl_dep,
    glu_dep,
    zlib_dep,
    x11_dep,
  ],
  include_directories: [enet_includes],
  link_with: [enet])
