enet_includes = include_directories('include')
enet = static_library('enet',
  [
    'callbacks.c',
    'host.c',
    'list.c',
    'memory.c',
    'packet.c',
    'peer.c',
    'protocol.c',
    'unix.c',
    'win32.c',
  ],
  include_directories: [enet_includes])
