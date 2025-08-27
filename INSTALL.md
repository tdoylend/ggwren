# Building GGWren

To build GGWren, compile `src/*.c` with your compiler of choice. You must have
`wren.h` in the include path, as well as the `.h` files for any optional
libraries you choose to include. You will also need to link the binaries for
Wren and your optional libraries into the resulting executable.

GGWren will only enable the API for a given library if it is requested. Compile
in the Wren API for a library by defining `GG_LIB_*`, where `*` is the name of
the library. If using static linking (instead of dynamic), make sure to also
define `GG_STATIC_*`; GGWren will define the required library-specific symbol
when including its `.h` file.
