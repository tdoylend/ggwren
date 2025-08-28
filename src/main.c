// GGWren
// Copyright 2025 Thomas Doylend. All rights reserved.
// For licensing information, please view the LICENSE.txt file.

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

// Globals
size_t search_dir_count = 0;
size_t search_dir_capacity = 0;
char **search_dirs = NULL;
MethodEntry *methods = NULL;
ClassEntry *classes = NULL;
int reported_compile_error_count = 0;
int hidden_compile_error_count = 0;

// Wren configuration functions
WrenForeignMethodFn wren__bindForeignMethod(
    WrenVM *vm,
    const char *module,
    const char *class,
    bool isStatic,
    const char *signature_without_static
);
WrenForeignClassMethods wren__bindForeignClass(WrenVM *vm, const char *module, const char *class);
void wren__write(WrenVM *vm, const char *text);
void wren__error(WrenVM *vm, WrenErrorType type, const char *module, int line, const char *message);
void wren__onLoadModuleComplete(WrenVM* vm, const char* name, struct WrenLoadModuleResult result);
WrenLoadModuleResult wren__loadModule(WrenVM *vm, const char *name);

////////////////////////////////////////////////////////

void link_method_(MethodEntry *entry) {
    entry->next = methods;
    methods = entry;
}
void link_class_(ClassEntry *entry) {
    entry->next = classes;
    classes = entry;
}

WrenForeignMethodFn wren__bindForeignMethod(
    WrenVM *vm,
    const char *module,
    const char *class,
    bool isStatic,
    const char *signature_without_static
) {
    // @todo isStatic
    const char *cmodule = NULL;
    char *signature = malloc(strlen(signature_without_static) + 12);
    strcpy(signature, isStatic ? "static " : "");
    strcat(signature, signature_without_static);
    WrenForeignMethodFn result = NULL;
    wrenEnsureSlots(vm, 1);
    if (wrenHasVariable(vm, module, "CModule_")) {
        wrenGetVariable(vm, module, "CModule_", 0);
        if (wrenGetSlotType(vm, 0) == WREN_TYPE_STRING) {
            cmodule = wrenGetSlotString(vm, 0);
        } else {
            fprintf(stderr, "Module `%s` defines `CModule_` as an invalid type.\n", module);
            exit(2);
        }
    } else {
        fprintf(stderr, "Module `%s` declares foreign class `%s`, but\n", module, class);
        fprintf(stderr, "does not define a `CModule_`.\n");
        exit(2);
    }
    for (MethodEntry *entry = methods; entry; entry = entry->next) {
        if (
            (strcmp(cmodule, entry->cmodule) == 0) &&
            (strcmp(class, entry->class) == 0) &&
            (strcmp(signature, entry->signature) == 0)
        ) {
            result = entry->method;
            break;
        }
    }

    if (!result) {
        fprintf(stderr, "Module %s defines class %s with foreign method `%s`,\n",
                module, class, signature);
        fprintf(stderr, "but it is not implemented in C.\n");
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
    const char *cmodule = NULL;
    wrenEnsureSlots(vm, 1);
    if (wrenHasVariable(vm, module, "CModule_")) {
        wrenGetVariable(vm, module, "CModule_", 0);
        if (wrenGetSlotType(vm, 0) == WREN_TYPE_STRING) {
            cmodule = wrenGetSlotString(vm, 0);
        } else {
            fprintf(stderr, "Module `%s` defines `CModule_` as an invalid type.\n", module);
            exit(2);
        }
    } else {
        fprintf(stderr, "Module `%s` declares foreign class `%s`, but\n", module, class);
        fprintf(stderr, "does not define a `CModule_`.\n");
        exit(2);
    }
    for (ClassEntry *entry = classes; entry; entry = entry->next) {
        if (
            (strcmp(cmodule, entry->cmodule) == 0) &&
            (strcmp(class, entry->class) == 0)
        ) {
            WrenForeignClassMethods result = {0};
            result.allocate = entry->allocate;
            result.finalize = entry->finalize;
            return result;
        }
    }
    fprintf(stderr, "Module `%s` declares foreign class `%s`, but\n", module, class);
    fprintf(stderr, "it is not defined by cmodule `%s`.\n", cmodule);
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
    finish_buffer(&path);
    WrenLoadModuleResult result;
    result.source = source;
    result.onComplete = &wren__onLoadModuleComplete;
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
    WrenConfiguration config;

    wrenInitConfiguration(&config);
    config.writeFn = &wren__write;
    config.errorFn = &wren__error;
    config.loadModuleFn = &wren__loadModule;
    config.bindForeignMethodFn = &wren__bindForeignMethod;
    config.bindForeignClassFn = &wren__bindForeignClass;

    loadCModules();

    const char *path = NULL;
    char *script = NULL;
    bool ok = true;
    bool run_code = true;
    bool show_help = false;
    bool list_search_dirs = false;

    push_search_dir(NULL); // For program's working directory

    char *env_search_dirs = getenv("GG_SEARCH_DIRS");
    if (env_search_dirs) env_search_dirs = dup_string(env_search_dirs);
    int env_search_dir_count = env_search_dirs ? 1 : env_search_dirs ? 1 : 0;
    for (char *cursor = env_search_dirs; cursor && *cursor; cursor ++) {
        if (*cursor == ':') {
            *cursor = 0;
            env_search_dir_count ++;
        }
    }
    size_t start = 0;
    for (size_t i = 0; i < env_search_dir_count; i ++) {
        push_search_dir(&env_search_dirs[start]);
        start += strlen(&env_search_dirs[start]) + 1;
    }
    if (env_search_dirs) free(env_search_dirs);
    enum { NORMAL } mode = NORMAL;
    for (size_t i = 1; i < argc; i ++) {
        char *arg = argv[i];
        switch (mode) {
            case NORMAL: {
                if (strcmp(arg, "--list-search-dirs") == 0) {
                    list_search_dirs = true;
                } else {
                    path = arg;
                }
            } break;
        }
    }

    if (!path) {
        show_help = true;
        ok = false;
    }

    if (show_help) {
        fprintf(stderr, "Usage:\n\n    %s [options] <path>\n\n", argv[0]);
        run_code = false;
    }

    if (list_search_dirs) {
        run_code = false;
        fprintf(stderr, "When loading modules, the following directories will be searched\n");
        fprintf(stderr, "in descending order:\n\n");
        for (size_t i = 0; i < search_dir_count; i ++) {
            if (search_dirs[i]) {
                fprintf(stderr, " - %s\n", search_dirs[i]);
            } else {
                fprintf(stderr, " - (the folder containing the root module)\n");
            }
        }
        fprintf(stderr, "\n");
    }

    if (ok && run_code) {
        script = readEntireFile(path);
        if (script) {
            char *script_real_path = realpath(path, NULL);
            char *script_dir = dirname(script_real_path);
            search_dirs[0] = dup_string(script_dir);
            free(script_real_path);
        } else {
            fprintf(stderr, "Could not load `%s`.\n", path);
            run_code = false;
        }
    }

    if (run_code) {
        WrenVM *vm = wrenNewVM(&config);
        WrenInterpretResult result = wrenInterpret(
            vm,
            path,
            script
        );
        if (hidden_compile_error_count > 0) {
            fprintf(stderr, "(+%d more error%s)\n", hidden_compile_error_count,
                    hidden_compile_error_count != 1 ? "s" : "");
        }
        wrenFreeVM(vm);
        if (result != WREN_RESULT_SUCCESS) ok = false;
    }

    if (script) free(script);

    for (size_t i = 0; i < search_dir_count; i ++) {
        if (search_dirs[i]) free(search_dirs[i]);
    }
    if (search_dirs) free(search_dirs);

    printf("Execution complete.\n");

    return ok ? 0 : 1;
}
