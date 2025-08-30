# GGWren

Wren with the batteries included.

Adds a small standard library to Wren. The following are built-in:

 -  [JSON](https://json.org) encoding and decoding that passes the 
    [JSON Parsing Test Suite](https://github.com/nst/JSONTestSuite)
 -  File I/O

For license information, please view the [LICENSE.txt](./LICENSE.txt) file.

For compilation instructions, please view [INSTALL.md](./INSTALL.md).

## Folder organization

 - `bin`: Binaries for the cmodules () are stored here.
 - `extsrc`: Source code for the extension modules is stored here.
 - `examples`: Demoes (written in pure Wren) go here.
 - `ggwren`: The primary executable.
 - `include`: Where GGWren's header files are stored; particularly those needed to
              build extension modules.
 - `scripts`: Where build scripts are stored.
 - `test`: Where tests are stored.

