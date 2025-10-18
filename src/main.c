/*
* GGWren
* Copyright (C) 2025 Thomas Doylend
* 
* This software is provided ‘as-is’, without any express or implied
* warranty. In no event will the authors be held liable for any damages
* arising from the use of this software.
* 
* Permission is granted to anyone to use this software for any purpose,
* including commercial applications, and to alter it and redistribute it
* freely, subject to the following restrictions:
* 
* 1. The origin of this software must not be misrepresented; you must not
*    claim that you wrote the original software. If you use this software
*    in a product, an acknowledgment in the product documentation would be
*    appreciated but is not required.
* 
* 2. Altered source versions must be plainly marked as such, and must not be
*    misrepresented as being the original software.
* 
* 3. This notice may not be removed or altered from any source
*    distribution.
*/

/**************************************************************************************************/

#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/**************************************************************************************************/
// Platform-specific includes
#ifdef __linux__
#include <dlfcn.h>
#include <fcntl.h>
#include <libgen.h>
#include <sys/stat.h>
#include <unistd.h>
#elif _WIN32
#error
#endif

#include <wren.h>
#define wrenGetSlotType_ wrenGetSlotType

#define GG_HOST
#include <ggwren.h>

#define GG_VERSION "0.0.1-indev"

#define MAX_MODULE_SEARCH_PATHS             64
#define MAX_COMPILATION_ERRORS_SHOWN         3
#define WARNING "\x1b[33;1m[WARNING]\x1b[m "
#define ERROR   "\x1b[31;1m[ERROR]\x1b[m "
#define TRACE   "\x1b[36m[TRACE]\x1b[m "
#define NOTE    "\x1b[36m[NOTE]\x1b[m "
#define HELP                                                                                       \
"Usage:"                                                                         "\n"              \
""                                                                               "\n"              \
"    %s [<options>] [<script>]"                                                  "\n"              \
""                                                                               "\n"              \
"Options:"                                                                       "\n"              \
""                                                                               "\n"              \
"    -list-lib-paths      List the paths GGWren will search for modules."        "\n"              \
""                                                                               "\n"              \
"    -lib=<path>          Add a module search path."                             "\n"              \
""                                                                               "\n"              

#define GG_SOURCE                                                                                  \
"class GG {"                                                                     "\n"              \
"    foreign static ggVersion"                                                   "\n"              \
"    foreign static wrenVersion"                                                 "\n"              \
"    foreign static bind(extension)"                                             "\n"              \
"    foreign static scriptDir"                                                   "\n"              \
"    foreign static scriptPath"                                                  "\n"              \
"    foreign static error"                                                       "\n"              \
"    foreign static setModuleSource(name, source)"                               "\n"              \
"}"                                                                              "\n"              \

#define EXITCODE_OK /*..............................*/  0
#define EXITCODE_RUNTIME_ERROR /*...................*/  1
#define EXITCODE_COMPILATION_ERROR /*...............*/  2
#define EXITCODE_COULD_NOT_LOAD_EXTENSION /*........*/  3
#define EXITCODE_COULD_NOT_BIND_FOREIGN_CLASS /*....*/  4
#define EXITCODE_COULD_NOT_BIND_FOREIGN_METHOD /*...*/  5
#define EXITCODE_INVALID_COMMAND_LINE_ARGS /*.......*/ 10
#define EXITCODE_COULD_NOT_READ_SCRIPT_SOURCE /*....*/ 11
#define EXITCODE_FATAL_ERROR /*.....................*/ 31

// Structs
typedef struct ExtClass ExtClass;
struct ExtClass {
    const char *name;
    WrenForeignMethodFn allocate;
    WrenFinalizerFn finalize;
    ExtClass *next;
};

typedef struct ExtMethod ExtMethod;
struct ExtMethod {
    const char *class;
    const char *signature;
    WrenForeignMethodFn fn;
    ExtMethod *next;
};

typedef void* ExtHandle;
ExtHandle openExt(const char *name);
void closeExt(ExtHandle handle);
void* getExtFn(ExtHandle handle, const char *name);

typedef struct Ext Ext;
struct Ext {
    char *name;
    ExtHandle handle;
    ExtClass *classes;
    ExtMethod *methods;
    Ext *next;
};

#include "gg.h"

typedef struct Buffer Buffer;
struct Buffer {
    uint8_t *bytes;
    size_t count;
    size_t capacity_including_nul;
};
void pushBuffer(Buffer *buffer, const char *string);
void pushBytesToBuffer(Buffer *buffer, const uint8_t *bytes, size_t length);
void printfBuffer(Buffer *buffer, const char *format, ...);
void clearBuffer(Buffer *buffer);
void appendPrintfBuffer(Buffer *buffer, const char *format, ...);
void finishBuffer(Buffer *buffer);

char* readEntireFile(const char* path, size_t* length);
char* xsprintf(const char* format, ...);
static inline char *dupString(const char *string);
size_t nextPowerOfTwo(size_t x);
void addModuleSearchPath(const char *path);

// Globals
char **argv;
int argc;
char **scriptArgv;
int scriptArgc;
char* binPath = NULL;
char* binDir  = NULL;
char* scriptPath = NULL;
char* scriptDir = NULL;
char* scriptSource = NULL;
char* scriptModuleName = NULL;
int scriptExitCode = EXITCODE_OK;
const char *extError = NULL;
char* moduleSearchPaths[MAX_MODULE_SEARCH_PATHS];
int moduleSearchPathCount = 0;
bool tooManyModuleSearchPaths = false;
Ext* extensions = NULL;
Ext* extBeingInitialized = NULL;
Ext* boundExtension = NULL;
WrenConfiguration config = {0};
WrenVM* vm = NULL;
Buffer foreignMethodSignature = {0};
Buffer modulePath = {0};
Buffer moduleNameTemp = {0};

char* preboundModuleName = NULL;
char* preboundModuleSource = NULL;

int compilationErrorsShown = 0;
int compilationErrorsHidden = 0;
Buffer fullError = {0};
bool errorSentinel = false;

GG_ABI abi = {
    #define GG_ABI_ENTRY(returnType, name, signature, params) .name = &name,
    GG_ABI_ENTRIES(GG_ABI_ENTRY)
    #undef GG_ABI_ENTRY
};

// Function implementations
ExtHandle openExt(const char *name) {
    char* extPath = xsprintf("%s/bin/%s.ggwren.so", binDir, name);
    ExtHandle handle = dlopen(extPath, RTLD_NOW | RTLD_LOCAL);
    free(extPath);
    if (!handle) extError = dlerror();
    return handle;
}

void closeExt(ExtHandle handle) {
    (void)dlclose(handle);
}

void* getExtFn(ExtHandle handle, const char *name) {
    void* sym = dlsym(handle, name);
    if (!sym) extError = dlerror();
    return sym;
}

void ggRegisterClass(const char *name, WrenForeignMethodFn allocate, WrenFinalizerFn finalize) {
    if (extBeingInitialized) {
        ExtClass* class = malloc(sizeof(ExtClass));
        class->name = name;
        class->allocate = allocate;
        class->finalize = finalize;
        class->next = extBeingInitialized->classes;
        extBeingInitialized->classes = class;
    } else {
        fprintf(stderr, WARNING "ggRegisterClass(..) was invoked by an extension outside "
                "ggExt_init(..), which has no effect.\n");
    }
}

void ggRegisterMethod(const char *className, const char *signature, WrenForeignMethodFn fn) {
    if (extBeingInitialized) {
        ExtMethod* method = malloc(sizeof(ExtMethod));
        method->class = className;
        method->signature = signature;
        method->fn = fn;
        method->next = extBeingInitialized->methods;
        extBeingInitialized->methods = method;
    } else {
        fprintf(stderr, WARNING "ggRegisterMethod(..) was invoked by an extension outside "
                "ggExt_init(..), which has no effect.\n");
    }
}

void pushBuffer(Buffer *buffer, const char *string) {
    size_t length = strlen(string);
    if ((length + buffer->count + 1) > buffer->capacity_including_nul) {
        buffer->capacity_including_nul = length + buffer->count + 1;
        buffer->capacity_including_nul = nextPowerOfTwo(buffer->capacity_including_nul);
        buffer->bytes = realloc(buffer->bytes, buffer->capacity_including_nul);
    }
    memcpy(&buffer->bytes[buffer->count], string, length);
    buffer->count += length;
    buffer->bytes[buffer->count] = 0;
}

void pushBytesToBuffer(Buffer *buffer, const uint8_t *bytes, size_t length) {
    if ((length + buffer->count + 1) > buffer->capacity_including_nul) {
        buffer->capacity_including_nul = length + buffer->count + 1;
        buffer->capacity_including_nul = nextPowerOfTwo(buffer->capacity_including_nul);
        buffer->bytes = realloc(buffer->bytes, buffer->capacity_including_nul);
    }
    memcpy(&buffer->bytes[buffer->count], bytes, length);
    buffer->count += length;
    buffer->bytes[buffer->count] = 0;
}

void clearBuffer(Buffer *buffer) {
    if (buffer->bytes) buffer->bytes[0] = 0;
    buffer->count = 0;
}

void appendPrintfBuffer(Buffer *buffer, const char *format, ...) {
    va_list args1;
    va_list args2;
    va_start(args1, format);
    va_copy(args2, args1);
    char c[2];
    size_t space_required = buffer->count + vsnprintf(c, 2, format, args1);
    if ((space_required + 1) > buffer->capacity_including_nul) {
        buffer->capacity_including_nul = space_required + 1;
        buffer->capacity_including_nul = nextPowerOfTwo(buffer->capacity_including_nul);
        buffer->bytes = realloc(buffer->bytes, buffer->capacity_including_nul);
    }
    buffer->count += vsnprintf(&buffer->bytes[buffer->count], space_required - buffer->count + 1,
            format, args2);
    va_end(args2);
    va_end(args1);
}

void printfBuffer(Buffer *buffer, const char *format, ...) {
    va_list args1;
    va_list args2;
    va_start(args1, format);
    va_copy(args2, args1);
    char c[2];
    size_t space_required = vsnprintf(c, 2, format, args1);
    if ((space_required + 1) > buffer->capacity_including_nul) {
        buffer->capacity_including_nul = space_required + 1;
        buffer->capacity_including_nul = nextPowerOfTwo(buffer->capacity_including_nul);
        buffer->bytes = realloc(buffer->bytes, buffer->capacity_including_nul);
    }
    buffer->count = vsnprintf(buffer->bytes, space_required + 1, format, args2);
    va_end(args2);
    va_end(args1);
}

void finishBuffer(Buffer *buffer) {
    if (buffer->bytes) free(buffer->bytes);
    memset(buffer, 0, sizeof(Buffer));
}

char *readEntireFile(const char *path, size_t* size_ptr) {
    int f = open(path, 0);
    bool ok = true;
    if (f < 0) ok = false;
    size_t size;
    char *buffer = NULL;
    if (ok) {
        struct stat stats;
        if (fstat(f, &stats) < 0) ok = false;
        size = stats.st_size;
    }
    if (ok) {
        buffer = malloc(size + 1);
        buffer[size] = 0;
    }
    size_t cursor = 0;
    while (ok && (cursor < size)) {
        ssize_t bytes_read = read(f, &buffer[cursor], size - cursor);
        if (bytes_read < 0) {
            ok = false;
        } else {
            cursor += bytes_read;
        }
    }
    if (buffer && !ok) {
        free(buffer);
    }
    if (f >= 0) close(f);
    if (ok && size_ptr) *size_ptr = size;
    return ok ? buffer : NULL;
}

char* xsprintf(const char *format, ...) {
    va_list args1;
    va_list args2;
    va_start(args1, format);
    va_copy(args2, args1);
    char c[2];
    size_t space_required = vsnprintf(c, 2, format, args1);
    char* result = malloc(space_required + 1);
    (void)vsnprintf(result, space_required + 1, format, args2);
    va_end(args2);
    va_end(args1);
    return result;
}

static inline char* dupString(const char* string) {
    size_t length = strlen(string);
    char* result = malloc(length+1);
    memcpy(result, string, length + 1);
    return result;
}

size_t nextPowerOfTwo(size_t x) {
    if (x == 0) return 1;
    x --;
    x |= x >> 1;
    x |= x >> 2;
    x |= x >> 4;
    x |= x >> 8;
    x |= x >> 16;
    x |= x >> 32;
    x += 1;
    return x;
}

void addModuleSearchPath(const char *path) {
    if (moduleSearchPathCount < MAX_MODULE_SEARCH_PATHS) {
        moduleSearchPaths[moduleSearchPathCount] = path ? dupString(path) : NULL;
        moduleSearchPathCount ++;
    } else {
        tooManyModuleSearchPaths = true;
    }
}

void apiStatic_GG_ggVersion_getter(WrenVM* vm) {
    wrenSetSlotString(vm, 0, GG_VERSION);
}

void apiStatic_GG_wrenVersion_getter(WrenVM* vm) {
    wrenSetSlotString(vm, 0, WREN_VERSION_STRING);
}

void apiStatic_GG_bind_1(WrenVM* vm) {
    WrenType t = wrenGetSlotType(vm, 1);
    if (t == WREN_TYPE_STRING) {
        Ext* result = NULL;
        const char* name = wrenGetSlotString(vm, 1);
        for (Ext* ext = extensions; !result && ext; ext = ext->next) {
            if (strcmp(ext->name, name) == 0) {
                result = ext;
            }
        }
        if (!result) {
            ExtHandle handle = openExt(name);
            if (handle) {
                Ext* ext = malloc(sizeof(Ext));
                ext->name = dupString(name);
                ext->handle = handle;
                ext->classes = NULL;
                ext->methods = NULL;
                ext->next = extensions;
                extensions = ext;
                ggExt_BootstrapFn extBootstrap = getExtFn(handle, "ggExt_bootstrap");
                ggExt_InitFn extInit = getExtFn(handle, "ggExt_init");
                if (extBootstrap) {
                    if (extBootstrap(&abi) == GG_BOOTSTRAP_OK) {
                        if (extInit) {
                            extBeingInitialized = ext;
                            extInit();
                            extBeingInitialized = NULL;
                        }
                        result = ext;
                    } else {
                        extError = "ggExt_bootstrap(..) returned a non-zero error value.\n";
                    }
                } else {
                    extError = "The extension does not have a ggExt_bootstrap function defined,\n"
                            "which means either it was compiled without ggwren.h or the\n"
                            "GG_EXT_IMPLEMENTATION macro was not defined. Please contact the\n"
                            "extension maintainer for a fix.";
                }
            }
            if (!result) {
                fprintf(stderr, ERROR "Could not load extension `%s`.\n", name);
                fprintf(stderr, ERROR "%s\n", extError);
                exit(EXITCODE_COULD_NOT_LOAD_EXTENSION);
                if (handle) closeExt(handle);
            }
        }
        boundExtension = result;
    } else if (t == WREN_TYPE_NULL) {
        boundExtension = NULL;
    } else {
        wrenSetSlotString(vm, 0, "The argument to `bind(..)` must be either a String or null.");
        wrenAbortFiber(vm, 0);
    }
}

void apiStatic_GG_scriptPath_getter(WrenVM* vm) {
    wrenSetSlotString(vm, 0, scriptPath);
}

void apiStatic_GG_scriptDir_getter(WrenVM* vm) {
    wrenSetSlotString(vm, 0, scriptDir);
}

void apiStatic_GG_error_getter(WrenVM* vm) {
    wrenSetSlotBytes(vm, 0, fullError.bytes, fullError.count);
}

void apiStatic_GG_setModuleSource_2(WrenVM* vm) {
    if (preboundModuleName) free(preboundModuleName);
    if (preboundModuleSource) free(preboundModuleSource);
    preboundModuleName = dupString(wrenGetSlotString(vm, 1));
    preboundModuleSource = dupString(wrenGetSlotString(vm, 2));
    wrenSetSlotNull(vm, 0);
}

void apiConfig_write(WrenVM* vm, const char* text) {
    printf("%s", text);
}

void apiConfig_error(
    WrenVM* vm,
    WrenErrorType type,
    const char* module,
    int line,
    const char* message
) {
    if (errorSentinel) {
        errorSentinel = false;
        clearBuffer(&fullError);
        compilationErrorsShown = 0;
        compilationErrorsHidden = 0;
    }
    if ((type != WREN_ERROR_COMPILE) && (compilationErrorsHidden > 0)) {
        appendPrintfBuffer(&fullError, NOTE "(%d additional error%s not shown)\n",
                compilationErrorsHidden, compilationErrorsHidden != 1 ? "s" : "");
        compilationErrorsHidden = 0;
    }
    switch (type) {
        case WREN_ERROR_COMPILE: {
            if (compilationErrorsShown >= MAX_COMPILATION_ERRORS_SHOWN) {
            } else {
                appendPrintfBuffer(&fullError,  ERROR "(In module `%s` on line %d) %s\n",
                        module, line, message);
                compilationErrorsShown ++;
            }
        } break;
        case WREN_ERROR_STACK_TRACE: {
            appendPrintfBuffer(&fullError, TRACE "In module `%s`, line %d, in `%s`\n",
                    module, line, message);
        } break;
        case WREN_ERROR_RUNTIME: {
            appendPrintfBuffer(&fullError, ERROR "%s\n", message);
        } break;
        case WREN_ERROR_END_OF_FRAME: {
            errorSentinel = true;
        } break;
    }
}

WrenForeignClassMethods apiConfig_bindForeignClass(
    WrenVM *vm,
    const char* module,
    const char* name
) {
    WrenForeignClassMethods result = {0};

    if (strcmp(module, "meta") == 0) {
        // do nothing
    } else if (strcmp(module, "random") == 0) {
        // do nothing
    } else if (boundExtension) {
        for (ExtClass *class=boundExtension->classes; !result.allocate && class;class=class->next) {
            if (strcmp(class->name, name) == 0) {
                result.allocate = class->allocate;
                result.finalize = class->finalize;
            }
        }
        if (!result.allocate) {
            fprintf(stderr, ERROR "Module `%s` defines foreign class `%s`, but bound "
                    "extension `%s` does not implement it.\n", module,
                    name, boundExtension->name);
            exit(EXITCODE_COULD_NOT_BIND_FOREIGN_CLASS);
        }
    } else {
        fprintf(stderr, ERROR "Module `%s` defines foreign class `%s` without first "
                "calling GG.bind(..).\n", module, name);
        exit(EXITCODE_COULD_NOT_BIND_FOREIGN_CLASS);
    }
    return result;
}

WrenForeignMethodFn apiConfig_bindForeignMethod(
    WrenVM* vm,
    const char* module,
    const char* class,
    bool isStatic,
    const char* signature
) {
    foreignMethodSignature.count = 0;
    printfBuffer(&foreignMethodSignature, "%s%s", isStatic ? "static " : "", signature);
    WrenForeignMethodFn result = NULL;
    if (strcmp(module, "gg") == 0) {
        if      (strcmp(signature, "ggVersion") == 0)    result = &apiStatic_GG_ggVersion_getter;
        else if (strcmp(signature, "wrenVersion") == 0)  result = &apiStatic_GG_wrenVersion_getter;
        else if (strcmp(signature, "bind(_)") == 0)      result = &apiStatic_GG_bind_1;
        else if (strcmp(signature, "scriptDir") == 0)    result = &apiStatic_GG_scriptDir_getter;
        else if (strcmp(signature, "scriptPath") == 0)   result = &apiStatic_GG_scriptPath_getter;
        else if (strcmp(signature, "setModuleSource(_,_)") == 0) result = &apiStatic_GG_setModuleSource_2;
        else if (strcmp(signature, "error") == 0)   result = &apiStatic_GG_error_getter;
        else {
            fprintf(stderr, "Internal error: gg declares non-existent method `%s`\n", signature);
            exit(EXITCODE_FATAL_ERROR);
        }
    } else if (strcmp(module, "meta") == 0) {
        // do nothing
    } else if (strcmp(module, "random") == 0) {
        // do nothing
    } else if (boundExtension) {
        for (ExtMethod *method = boundExtension->methods; !result && method; method= method->next) {
            if ((strcmp(method->class, class) == 0) &&
                (strcmp(method->signature, foreignMethodSignature.bytes) == 0))
            {
                result = method->fn;
            }
        }
        if (!result) {
            fprintf(stderr, ERROR "Module `%s` defines foreign %smethod `%s.%s`, but bound "
                    "extension `%s` does not implement it.\n", module, isStatic ? "static " : "",
                    class, signature, boundExtension->name);
            exit(EXITCODE_COULD_NOT_BIND_FOREIGN_METHOD);
        }
    } else {
        fprintf(stderr, ERROR "Module `%s` defines foreign %smethod `%s.%s` without first "
                "calling GG.bind(..).\n", module, isStatic ? "static " : "", class, signature);
        exit(EXITCODE_COULD_NOT_BIND_FOREIGN_METHOD);
    }

    return result;
}

const char* apiConfig_resolveModule(WrenVM *vm, const char* importer, const char* name) {
    char* result = malloc(strlen(importer)+strlen(name)+2);
    if (name[0] == '.') {
        strcpy(result, importer);
        const char* trimmed_name = &name[1];
        for (size_t i = 1; name[i] == '.'; i ++) {
            // For every dot past the first, go up one level.
            ssize_t last_slash = -1;
            for (size_t j = 0; result[j]; j ++) {
                if (result[j] == '.') {
                    last_slash = j;
                }
            }
            if (last_slash >= 0) {
                result[last_slash] = 0;
            } else {
                result[0] = 0;
            }
            trimmed_name = &name[i+1];
        }
        if (result[0] == 0) {
            strcpy(result, trimmed_name);
        } else {
            strcat(result, ".");
            strcat(result, trimmed_name);
        }
    } else {
        strcpy(result, name);
    }
    return result;
}

void apiConfig_loadModuleComplete(WrenVM* vm, const char* module, WrenLoadModuleResult result) {
    if (result.source) free((void*)(result.source));
}

WrenLoadModuleResult apiConfig_loadModule(WrenVM* vm, const char* name) {
    WrenLoadModuleResult result = {0};
    bool invalid_chars_in_name = false;
    clearBuffer(&moduleNameTemp);
    size_t name_count = strlen(name);
    for (size_t i = 0; i < name_count; i ++) {
        if ((name[i] == '/') || (name[i] == '\\') || (name[i] < 32) || (name[i] > 126)) {
            invalid_chars_in_name = true;
            break;
        } else if (name[i] == '.') {
            pushBuffer(&moduleNameTemp,"/");
        } else {
            pushBytesToBuffer(&moduleNameTemp, &name[i], 1);
        }
    }
    if (strcmp(name, "gg") == 0) {
        result.source = GG_SOURCE;
    } else if (preboundModuleName && (strcmp(name, preboundModuleName) == 0)) {
        result.source = preboundModuleSource;
    } else if (invalid_chars_in_name) {
        result.source = NULL;
    } else {
        for (size_t i = 0; i < moduleSearchPathCount; i ++) {
            printfBuffer(&modulePath, "%s/%s.wren", moduleSearchPaths[i], moduleNameTemp.bytes);
            result.source = readEntireFile(modulePath.bytes, NULL);
            if (result.source) break;
            printfBuffer(&modulePath, "%s/%s/lib.wren",moduleSearchPaths[i], moduleNameTemp.bytes);
            result.source = readEntireFile(modulePath.bytes, NULL);
            if (result.source) break;
        }
        if (result.source) {
            result.onComplete = apiConfig_loadModuleComplete;
        }
    }
    return result;
}

int main(int argc_, char** argv_) {
    enum {
        OK,
        INVALID_COMMAND_LINE_ARGS,
        FATAL_ERROR,
        COULD_NOT_READ_SCRIPT_SOURCE,
        SCRIPT_COMPILATION_ERROR,
        SCRIPT_RUNTIME_ERROR
    } status = OK;
    enum {
        RUN_SCRIPT,
        SHOW_HELP,
        LIST_SEARCH_PATHS
    } action = RUN_SCRIPT;

    argc = argc_;
    argv = argv_;
    addModuleSearchPath(NULL);
    if (status == OK) {
        // Detect the binPath. Keep it NULL if this fails.
        size_t capacity = 0;
        ssize_t length = 0;
        while ((status == OK) && (length >= capacity)) {
            capacity = capacity ? capacity << 1 : 256;
            binPath = realloc(binPath, capacity);
            length = readlink("/proc/self/exe", binPath, capacity);
            if (length < 0) {
                fprintf(stderr, ERROR "Failed to read location of the GGWren executable "
                        "readlink(..) failed.\n");
                status = FATAL_ERROR;
            }
        }
        if (status == OK) {
            char *realBinPath = realpath(binPath, NULL);
            if (realBinPath) {
                free(binPath);
                binPath = realBinPath;
            } else {
                fprintf(stderr, ERROR "Failed to read location of the GGWren executable "
                        "realpath(..) failed.\n");
                status = FATAL_ERROR;
            }
        } 
        if (status != OK) {
            if (binPath) free(binPath);
            binPath = NULL;
        }
    }
    if (binPath) {
        char *tempBinPath = dupString(binPath);
        binDir = dupString(dirname(tempBinPath));
        free(tempBinPath);
    }
    Buffer argKey = {0};
    Buffer argValue = {0};
    bool foundScriptPath = false;
    for (size_t i = 1; (status == OK) && !foundScriptPath && (i < argc); i ++) {
        char* arg = argv[i];
        size_t argLength = strlen(arg);
        bool argValueExists = false;
        argKey.count = 0;
        argValue.count = 0;
        pushBuffer(&argKey, arg);
        for (size_t i = 0; i < argLength; i ++) {
            if (arg[i] == '=') {
                argKey.count = 0;
                pushBytesToBuffer(&argKey, arg, i);
                pushBuffer(&argValue, &arg[i+1]);
                argValueExists = true;
                break;
            }
        }
        if (arg[0] == '-') {
            if      (strcmp(arg, "-list-lib-paths") == 0) action = LIST_SEARCH_PATHS;
            else if (strcmp(argKey.bytes, "-lib") == 0) {
                if (argValueExists) {
                    char *searchPath = realpath(argValue.bytes, NULL);
                    if (searchPath) {
                        addModuleSearchPath(searchPath);
                        free(searchPath);
                    } else {
                        addModuleSearchPath(argValue.bytes);
                    }
                } else {
                    fprintf(stderr, ERROR "You must supply a path with the `-lib` argument:\n\n");
                    fprintf(stderr, "    %s -lib=<path> ...\n\n", argv[0]);
                    status = INVALID_COMMAND_LINE_ARGS;
                }
            } else {
                fprintf(stderr, ERROR "Unknown option `%s`. Please run `%s -help` for a complete\n"
                        "list of command-line options.\n", argKey.bytes, argv[0]);
                status = INVALID_COMMAND_LINE_ARGS;
            }
        } else {
            scriptPath = realpath(arg, NULL);
            if (scriptPath) {
                char *tempScriptPath = dupString(scriptPath);
                scriptDir = dupString(dirname(tempScriptPath));
                free(tempScriptPath);
            } else {
                scriptPath = dupString(arg);
            }
            scriptArgv = &argv[i];
            scriptArgc = argc - i;
            foundScriptPath = true;
        }
    }
    finishBuffer(&argKey);
    finishBuffer(&argValue);
    if ((status == OK) && (action == RUN_SCRIPT)) {
        if (scriptPath) {       
            scriptSource = readEntireFile(scriptPath, NULL);
            char* tempScriptPath = dupString(scriptPath);
            scriptModuleName = dupString(basename(tempScriptPath));
            free(tempScriptPath);
            size_t length = strlen(scriptModuleName);
            if ((strlen(scriptModuleName) >= 5) && 
                    (strcmp(&scriptModuleName[length - 5], ".wren") == 0))
            {
                scriptModuleName[length - 5] = 0;
            }
            if (!scriptSource) {
                status = COULD_NOT_READ_SCRIPT_SOURCE;
                fprintf(stderr, ERROR "Could not read script file `%s`.\n", scriptPath);
            }
        } else {
            action = SHOW_HELP;
            status = INVALID_COMMAND_LINE_ARGS;
        }
    }
    if (scriptDir) moduleSearchPaths[0] = dupString(scriptDir);
    char *libDir = xsprintf("%s/lib", binDir);
    if (binDir) addModuleSearchPath(libDir);
    free(libDir);
    if (getenv("GG_LIB")) {
        int start = 0;
        char *lib = getenv("GG_LIB");
        for (int index = 0; lib[index]; index ++) {
            if (lib[index] == ':') {
                int length = index - start;
                if (length) {
                    char* path = malloc(length + 1);
                    memcpy(path, &lib[start], length);
                    path[length] = 0;
                    addModuleSearchPath(path);
                    free(path);
                }
                start = index + 1;
            }
        }
        int length = strlen(lib) - start;
        if (length) {
            char* path = malloc(length + 1);
            memcpy(path, &lib[start], length);
            path[length] = 0;
            addModuleSearchPath(path);
            free(path);
        }
    }
    addModuleSearchPath("/usr/lib/ggwren");
    if (tooManyModuleSearchPaths) {
        fprintf(stderr, "\x1b[33;1m[WARNING]\x1b[m ");
        fprintf(stderr, "Too many module search paths were added (the limit is %d); the extras\n"
                "were ignored.\n", MAX_MODULE_SEARCH_PATHS);
    }
    {
        Ext* ext = malloc(sizeof(Ext));
        ext->name = dupString("builtins");
        ext->handle = NULL;
        ext->classes = NULL;
        ext->methods = NULL;
        ext->next = extensions;
        extensions = ext;
        extBeingInitialized = ext;
        initBuiltins();
        extBeingInitialized = NULL;
    }
    switch (action) {
        case RUN_SCRIPT: if (status == OK) {
            wrenInitConfiguration(&config);
            config.writeFn = &apiConfig_write;
            config.errorFn = &apiConfig_error;
            config.bindForeignMethodFn = &apiConfig_bindForeignMethod;
            config.bindForeignClassFn = &apiConfig_bindForeignClass;
            config.loadModuleFn = &apiConfig_loadModule;
            config.resolveModuleFn = &apiConfig_resolveModule;
            vm = wrenNewVM(&config);
            WrenInterpretResult result = wrenInterpret(
                vm,
                scriptModuleName,
                scriptSource
            );
            if (result != WREN_RESULT_SUCCESS) {
                fprintf(stderr, "%s", fullError.bytes);
            }
            switch (result) {
                case WREN_RESULT_SUCCESS: { status = OK; } break;
                case WREN_RESULT_COMPILE_ERROR: { status = SCRIPT_COMPILATION_ERROR; } break;
                case WREN_RESULT_RUNTIME_ERROR: { status = SCRIPT_RUNTIME_ERROR; } break;
            }
        } break;
        case SHOW_HELP: {
            fprintf(stderr, HELP, argv[0]);
        } break;
        case LIST_SEARCH_PATHS: if (status == OK) {
            fprintf(stderr, "When importing modules, paths will be searched in the "
                    "following order:\n\n");
            for (size_t i = 0; i < moduleSearchPathCount; i ++) {
                if (moduleSearchPaths[i]) {
                    printf(" - %s\n", moduleSearchPaths[i]);
                } else {
                    printf(" - (the directory containing the root script)\n");
                }
            }
            fprintf(stderr, "\n");
        } break;
    }
    if (vm) wrenFreeVM(vm);
    Ext* nextExt;
    for (Ext *ext = extensions; ext; ext = nextExt) {
        if (ext->handle) {
            ggExt_FinishFn extFinish = getExtFn(ext->handle, "ggExt_finish");
            if (extFinish) extFinish();
            closeExt(ext->handle);
        }
        ExtClass* nextClass;
        for (ExtClass *class = ext->classes; class; class = nextClass) {
            nextClass = class->next;
            free(class);
        }
        ExtMethod* nextMethod;
        for (ExtMethod *method = ext->methods; method; method = nextMethod) {
            nextMethod = method->next;
            free(method);
        }
        nextExt = ext->next;
        free(ext->name);
        free(ext);
    }
    for (size_t i = 0; i < moduleSearchPathCount; i ++) {
        free(moduleSearchPaths[i]);
    }
    if (binPath) free(binPath);
    if (binDir) free(binDir);
    if (scriptPath) free(scriptPath);
    if (scriptSource) free(scriptSource);
    if (scriptModuleName) free(scriptModuleName);
    if (scriptDir) free(scriptDir);
    finishBuffer(&foreignMethodSignature);
    finishBuffer(&modulePath);
    finishBuffer(&moduleNameTemp);
    if (preboundModuleName) free(preboundModuleName);
    if (preboundModuleSource) free(preboundModuleSource);
    switch (status) {
        case OK:                            return scriptExitCode;
        case SCRIPT_RUNTIME_ERROR:          return EXITCODE_RUNTIME_ERROR;
        case SCRIPT_COMPILATION_ERROR:      return EXITCODE_COMPILATION_ERROR;
        case INVALID_COMMAND_LINE_ARGS:     return EXITCODE_INVALID_COMMAND_LINE_ARGS;
        case COULD_NOT_READ_SCRIPT_SOURCE:  return EXITCODE_COULD_NOT_READ_SCRIPT_SOURCE;
        case FATAL_ERROR:                   return EXITCODE_FATAL_ERROR;
    }
}
