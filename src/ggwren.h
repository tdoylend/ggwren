#ifndef GGWREN_H
#define GGWREN_H

#define GG_VERSION "0.0.1-indev"

#include <wren.h>

typedef struct CModule CModule;
CModule *register_cmodule(const char *name);

void register_method(
    CModule *cmodule,
    const char *class,
    const char *signature,
    WrenForeignMethodFn fn
);

void register_class(
    CModule *cmodule,
    const char *name,
    WrenForeignMethodFn allocate,
    WrenFinalizerFn finalize
);

// Load whichever cmodules are enabled and register them so they are accessible via GG.bind(..).
void loadCModules(void);

// Read the contents of a file and return it as a NUL-terminated string.
char *readEntireFile(const char *path);

// Compute the smallest power of two at least as large as x.
size_t nextPowerOfTwo(size_t x);

extern char **global_argv;
extern int    global_argc;

#endif
