# GGWren

Wren with the batteries included.

Adds a small standard library to Wren. The following modules are available:

 -  [JSON](https://json.org) encoding and decoding that passes the 
    [JSON Parsing Test Suite](https://github.com/nst/JSONTestSuite).
 -  File I/O
 -  TCP socket I/O
 -  [SQLite3](https://sqlite.org/)
 -  Spec-compliant [Mustache](https://mustache.github.io) template rendering (no
    optional modules supported yet)

Coming soon:

 -  HTTP server + client libraries
 -  Mustache template rendering
 -  SDL2
 -  OpenGL

For license information, please view the [LICENSE.txt](./LICENSE.txt) file.

For compilation instructions, please view [INSTALL.md](./INSTALL.md).

## Directory structure

 - `bin`: `.dll`s and `.so`s for extension modules are stored here.
 - `extsrc`: Source code for the extension modules is stored here.
 - `examples`: Demoes (written in pure Wren) go here.
 - `ggwren`: The primary executable.
 - `include`: Where GGWren's header files are stored; particularly those needed to
              build extension modules.
 - `src`: The primary source code of GGWren.
 - `scripts`: Where build scripts are stored.
 - `test`: Where tests are stored.

