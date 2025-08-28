// GGWren
// Copyright 2025 Thomas Doylend. All rights reserved.
// For licensing information, please view the LICENSE.txt file.

#include <limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include <fcntl.h>
#include <libgen.h>
#include <sys/stat.h>
#include <unistd.h>

#include "ggwren.h"

// Structs
typedef struct Buffer Buffer;
struct Buffer {
    uint8_t *bytes;
    size_t count;
    size_t capacity;
};
void write_buffer(Buffer *buffer, const uint8_t *bytes, size_t count);
void write_string_to_buffer(Buffer *buffer, const char *string);
void finish_buffer(Buffer *buffer);

typedef struct ForeignMethod ForeignMethod;
struct ForeignMethod {
    const char *class;
    const char *signature;
    WrenForeignMethodFn fn;
    ForeignMethod *next;
};

typedef struct ForeignClass ForeignClass;
struct ForeignClass {
    const char *name;
    WrenForeignMethodFn allocate;
    WrenFinalizerFn finalize;
    ForeignClass *next;
};

struct CModule {
    const char *name;
    ForeignMethod *foreignMethods;
    ForeignClass *foreignClasses;
    CModule *next;
};

// Globals
char **global_argv;
int    global_argc;
size_t search_dir_count = 0;
size_t search_dir_capacity = 0;
char **search_dirs = NULL;
int reported_compile_error_count = 0;
int hidden_compile_error_count = 0;
CModule *cmodules = NULL;
CModule *bound_cmodule = NULL;

const char *GG_SOURCE = 
    "class GG {\n"
    "foreign static version\n"
    "foreign static cmodules\n"
    "foreign static bind(cmodule)\n"
    "}\n"
;

// Wren configuration functions
WrenForeignMethodFn wren__bindForeignMethod(
    WrenVM *vm,
    const char *module,
    const char *class,
    bool isStatic,
    const char *raw_signature
);
WrenForeignClassMethods wren__bindForeignClass(WrenVM *vm, const char *module, const char *class);
void wren__write(WrenVM *vm, const char *text);
void wren__error(WrenVM *vm, WrenErrorType type, const char *module, int line, const char *message);
void wren__onLoadModuleComplete(WrenVM* vm, const char* name, struct WrenLoadModuleResult result);
WrenLoadModuleResult wren__loadModule(WrenVM *vm, const char *name);

////////////////////////////////////////////////////////

CModule *register_cmodule(
    const char *name
) {
    CModule *module = malloc(sizeof(CModule));
    module->name = name;
    module->foreignMethods = NULL;
    module->foreignClasses = NULL;
    module->next = cmodules;
    cmodules = module;
    return module;
}

void register_method(
    CModule *cmodule,
    const char *class,
    const char *signature,
    WrenForeignMethodFn fn
) {
    ForeignMethod *method = malloc(sizeof(ForeignMethod));
    method->class = class;
    method->signature = signature;
    method->fn = fn;
    method->next = cmodule->foreignMethods;
    cmodule->foreignMethods = method;
}

void register_class(
    CModule *cmodule,
    const char *name,
    WrenForeignMethodFn allocate,
    WrenFinalizerFn finalize
) {
    ForeignClass *class = malloc(sizeof(ForeignClass));
    class->name = name;
    class->allocate = allocate;
    class->finalize = finalize;
    class->next = cmodule->foreignClasses;
    cmodule->foreignClasses = class;
}

static void apiStatic__GG__cmodules__getter(WrenVM *vm) {
    wrenEnsureSlots(vm, 2);
    wrenSetSlotNewList(vm, 0);
    for (CModule *module = cmodules; module; module = module->next) {
        wrenSetSlotString(vm, 1, module->name);
        wrenInsertInList(vm, 0, -1, 1);
    }
}

static void apiStatic__GG__version__getter(WrenVM *vm) {
    wrenSetSlotString(vm, 0, GG_VERSION);
}

static void apiStatic__GG__bind__1(WrenVM *vm) {
    if (wrenGetSlotType(vm, 1) == WREN_TYPE_NULL) {
        bound_cmodule = NULL;
    } else {
        const char *name = wrenGetSlotString(vm, 1);
        bool found = false;
        for (bound_cmodule = cmodules; bound_cmodule; bound_cmodule = bound_cmodule->next) {
            if (strcmp(bound_cmodule->name, name) == 0) {
                found = true;
                break;
            }
        }
        if (!found) {
            Buffer temp = {0};
            write_string_to_buffer(&temp, "Your build of GGWren does not contain the cmodule `");
            write_string_to_buffer(&temp, name);
            write_string_to_buffer(&temp, "`.");
            wrenSetSlotBytes(vm, 0, temp.bytes, temp.count);
            wrenAbortFiber(vm, 0);
            finish_buffer(&temp);
        }
    }
}

WrenForeignMethodFn wren__bindForeignMethod(
    WrenVM *vm,
    const char *module,
    const char *class,
    bool isStatic,
    const char *signature_without_static
) {
    WrenForeignMethodFn result = NULL;
    char *signature = malloc(strlen(signature_without_static) + 12);
    strcpy(signature, isStatic ? "static " : "");
    strcat(signature, signature_without_static);
    if (strcmp(module, "gg") == 0) {
        if (strcmp(class, "GG") == 0) {
            if (strcmp(signature, "static bind(_)") == 0) result = &apiStatic__GG__bind__1;
            if (strcmp(signature, "static version") == 0) result = &apiStatic__GG__version__getter;
            if (strcmp(signature, "static cmodules")== 0) result = &apiStatic__GG__cmodules__getter;
        }
    }
    if (!result && !bound_cmodule) {
        fprintf(stderr, "Module `%s` declares foreign methods but did not call GG.bind(..).\n",
                module);
        exit(2);
    }
    if (!result) {
        for (
            ForeignMethod *entry = bound_cmodule->foreignMethods;
            !result && entry;
            entry = entry->next
        ) {
            if (
                (strcmp(class, entry->class) == 0) &&
                (strcmp(signature, entry->signature) == 0)
            ) {
                result = entry->fn;
            }
        }
    }
    if (!result) {
        fprintf(stderr, "Module %s defines class %s with foreign method `%s`,\n",
                module, class, signature);
        fprintf(stderr, "but it is not implemented in the bound cmodule `%s`.\n",
                bound_cmodule->name);
        exit(2);
    }
    free(signature);
    return result;
}

WrenForeignClassMethods wren__bindForeignClass(
    WrenVM *vm,
    const char *module,
    const char *class
) {
    if (!bound_cmodule) {
        fprintf(stderr, "Module `%s` declares foreign classes but did not call GG.bind(..).\n",
                module);
        exit(2);
    }
    for (ForeignClass *entry = bound_cmodule->foreignClasses; entry; entry = entry->next) {
        if (strcmp(class, entry->name) == 0) {
            WrenForeignClassMethods result = {0};
            result.allocate = entry->allocate;
            result.finalize = entry->finalize;
            return result;
        }
    }
    fprintf(stderr, "Module `%s` declares foreign class `%s`, but\n", module, class);
    fprintf(stderr, "it is not implemented by the bound cmodule `%s`.\n", bound_cmodule->name);
    exit(2);
}

void wren__write(WrenVM *vm, const char *text) {
    printf("%s", text);
}

void wren__error(
    WrenVM *vm,
    WrenErrorType type,
    const char *module,
    int line,
    const char *message
) {
    switch (type) {
        case WREN_ERROR_COMPILE: {
            if (reported_compile_error_count < 3) {
                fprintf(stderr, "[%s on line %d] %s\n", module, line, message);
                reported_compile_error_count ++;
            } else {
                hidden_compile_error_count ++;
            }
        } break;
        case WREN_ERROR_STACK_TRACE: {
            fprintf(stderr, "[%s on line %d] in %s\n", module, line, message);
        } break;
        case WREN_ERROR_RUNTIME: {
            fprintf(stderr, "[Error] %s\n", message);
        } break;
    }
}

WrenLoadModuleResult wren__loadModule(WrenVM *vm, const char *name) {
    WrenLoadModuleResult result;
    if (strcmp(name, "gg") == 0) {
        result.source = GG_SOURCE;
        result.onComplete = NULL;
    } else {
        Buffer path = {0};
        char *source = NULL;
        for (size_t search_index = 0; !source && (search_index < search_dir_count); search_index ++) {
            path.count = 0;
            write_string_to_buffer(&path, search_dirs[search_index]);
            write_string_to_buffer(&path, "/");
            size_t name_start = path.count;
            write_string_to_buffer(&path, name);
            for (size_t i = name_start; i < path.count; i ++) {
                if (path.bytes[i] == ':') {
                    path.bytes[i] = '/';
                }
            }
            write_string_to_buffer(&path, ".wren");
            uint8_t nul = 0;
            write_buffer(&path, &nul, 1);
            source = readEntireFile((const char *)(path.bytes));
        }
        result.source = source;
        result.onComplete = &wren__onLoadModuleComplete;
        finish_buffer(&path);
    }
    return result;
}


void wren__onLoadModuleComplete(WrenVM* vm, const char* name, struct WrenLoadModuleResult result) {
    if (result.source) {
        free((void*)result.source);
    }
}

char *readEntireFile(const char *path) {
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
    return ok ? buffer : NULL;
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

char *dup_string(const char *string) {
    char *result = malloc(strlen(string) + 1);
    strcpy(result, string);
    return result;
}

void push_search_dir(const char *path) {
    if (search_dir_count == search_dir_capacity) {
        search_dir_capacity = search_dir_capacity ? search_dir_capacity << 1 : 8;
        search_dirs = realloc(search_dirs, sizeof(char*)*search_dir_capacity);
    }
    search_dirs[search_dir_count] = path ? dup_string(path) : NULL;
    search_dir_count ++;
}

void write_buffer(Buffer *buffer, const uint8_t *bytes, size_t count) {
    bool need_resize = false;
    while ((buffer->count + count) > buffer->capacity) {
        buffer->capacity = buffer->capacity ? buffer->capacity << 1 : 256;
        need_resize = true;
    }
    if (need_resize) {
        buffer->bytes = realloc(buffer->bytes, buffer->capacity);
    }
    memcpy(&buffer->bytes[buffer->count], bytes, count);
    buffer->count += count;
}

void write_string_to_buffer(Buffer *buffer, const char *string) {
    write_buffer(buffer, (const uint8_t*)string, strlen(string));
}

void finish_buffer(Buffer *buffer) {
    if (buffer->bytes) free(buffer->bytes);
}

int main(int argc, char **argv) {
    const char *path = NULL;
    enum { RUN_CODE, HELP, LIST_SEARCH_DIRS, LIST_CMODULES, ERROR } mode = RUN_CODE;
    push_search_dir(NULL); // For the directory containing the root module
    char *env_search_dirs = getenv("GG_SEARCH_DIRS");
    if (env_search_dirs) env_search_dirs = dup_string(env_search_dirs);
    int env_search_dir_count = env_search_dirs ? 1 : env_search_dirs ? 1 : 0;
    for (char *cursor = env_search_dirs; cursor && *cursor; cursor ++) {
        if (*cursor == ':') {
            *cursor = 0;
            env_search_dir_count ++;
        }
    }
    char bin_path[PATH_MAX];
    ssize_t length = readlink("/proc/self/exe", bin_path, PATH_MAX - 1);
    if (length >= 0) {
        bin_path[length] = 0;
        char *real_bin_path = realpath(bin_path, NULL);
        char *bin_dir = dirname(real_bin_path);
        push_search_dir(bin_dir);
        free(real_bin_path);
    }
    #if defined(__linux__)
    push_search_dir("/usr/lib/ggwren");
    #endif

    size_t start = 0;
    for (size_t i = 0; i < env_search_dir_count; i ++) {
        push_search_dir(&env_search_dirs[start]);
        start += strlen(&env_search_dirs[start]) + 1;
    }
    if (env_search_dirs) free(env_search_dirs);
    enum { NORMAL } arg_mode = NORMAL;
    for (size_t i = 1; i < argc; i ++) {
        char *arg = argv[i];
        switch (arg_mode) {
            case NORMAL: {
                if (strcmp(arg, "--list-search-dirs") == 0) {
                    mode = LIST_SEARCH_DIRS;
                } else if (strcmp(arg, "--list-cmodules") == 0) {
                    mode = LIST_CMODULES;
                } else {
                    path = arg;
                    global_argv = &argv[i];
                    global_argc = argc - i;
                }
            } break;
        }
    }

    if ((mode == NORMAL) && !path) {
        mode = HELP;
    }

    loadCModules();

    switch (mode) {
        case RUN_CODE: {
            char *source = readEntireFile(path);
            if (source) {
                char *real_path = realpath(path, NULL);
                char *dir = dirname(real_path);
                search_dirs[0] = dup_string(dir);
                free(real_path);
            } else {
                fprintf(stderr, "Could not load `%s`.\n", path);
                mode = ERROR;
            }
            if (source) {
                WrenConfiguration config;
                wrenInitConfiguration(&config);
                config.writeFn = &wren__write;
                config.errorFn = &wren__error;
                config.loadModuleFn = &wren__loadModule;
                config.bindForeignMethodFn = &wren__bindForeignMethod;
                config.bindForeignClassFn = &wren__bindForeignClass;
                WrenVM *vm = wrenNewVM(&config);
                WrenInterpretResult result = wrenInterpret(
                    vm,
                    path,
                    source
                );
                if (hidden_compile_error_count > 0) {
                    fprintf(stderr, "(+%d more error%s)\n", hidden_compile_error_count,
                            hidden_compile_error_count != 1 ? "s" : "");
                }
                wrenFreeVM(vm);
                if (result != WREN_RESULT_SUCCESS) mode = ERROR;
            }
            if (source) free(source);
        } break;
        case HELP: {
            fprintf(stderr, "Usage:\n\n    %s [options] <path>\n\n", argv[0]);
        } break;
        case LIST_SEARCH_DIRS: {
            fprintf(stderr, "When loading modules, the following directories will be searched\n");
            fprintf(stderr, "in descending order:\n\n");
            for (size_t i = 0; i < search_dir_count; i ++) {
                if (search_dirs[i]) {
                    fprintf(stderr, " - %s\n", search_dirs[i]);
                } else {
                    fprintf(stderr, " - (the directory containing the root module)\n");
                }
            }
            fprintf(stderr, "\n");
        } break;
        case LIST_CMODULES: {
            fprintf(stderr, "The following cmodules are available:\n\n");
            for (CModule *cmodule = cmodules; cmodule; cmodule = cmodule->next) {
                fprintf(stderr, " - %s\n", cmodule->name);
            }
            fprintf(stderr, "\n");
        } break;
        case ERROR: {
            // do nothing
        } break;
    }
    for (size_t i = 0; i < search_dir_count; i ++) {
        if (search_dirs[i]) free(search_dirs[i]);
    }
    if (search_dirs) free(search_dirs);
    return mode == ERROR ? 2 : 0;
}
