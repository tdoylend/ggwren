extern char **scriptArgv;
extern int scriptArgc;

void ggRegisterClass(const char *name, WrenForeignMethodFn allocate, WrenFinalizerFn finalize);
void ggRegisterMethod(const char *className, const char *signature, WrenForeignMethodFn fn);

void initBuiltins(void); // Defined in builtins.c.

static inline char *dupString(const char *string);
size_t nextPowerOfTwo(size_t x);
