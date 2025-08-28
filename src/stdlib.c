#include <errno.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>

#include "ggwren.h"

extern char **environ;

typedef struct ByteBuffer ByteBuffer;
struct ByteBuffer {
    uint8_t *bytes;
    size_t count;
    size_t capacity;
};

static void apiAllocate__ByteBuffer(WrenVM *vm) {
    ByteBuffer *buffer = wrenSetSlotNewForeign(vm, 0, 0, sizeof(ByteBuffer));
    memset(buffer, 0, sizeof(ByteBuffer));
}

static void apiFinalize__ByteBuffer(void *raw) {
    ByteBuffer *buffer = raw;
    if (buffer->bytes) free(buffer->bytes);
}

static void write_bytebuffer(ByteBuffer *buffer, const uint8_t *bytes, size_t count) {
    if (count > 0) {
        if ((buffer->count + count) > buffer->capacity) {
            buffer->capacity = nextPowerOfTwo(buffer->count + count);
            buffer->bytes = realloc(buffer->bytes, buffer->capacity);
        }
        memcpy(&buffer->bytes[buffer->count], bytes, count);
        buffer->count += count;
    }
}

static void api__ByteBuffer__write__1(WrenVM *vm) {
    ByteBuffer *buffer = wrenGetSlotForeign(vm, 0);
    int count;
    if (wrenGetSlotType(vm, 1) == WREN_TYPE_STRING) {
        const uint8_t *bytes = wrenGetSlotBytes(vm, 1, &count);
        write_bytebuffer(buffer, bytes, (size_t)count);
        wrenSetSlotNull(vm, 0);
    } else {
        wrenSetSlotString(vm, 0, "Cannot write a non-String to ByteBuffer.");
        wrenAbortFiber(vm, 0);
    }
}

static void api__ByteBuffer__writeByte__1(WrenVM *vm) {
    ByteBuffer *buffer = wrenGetSlotForeign(vm, 0);
    if (wrenGetSlotType(vm, 1) == WREN_TYPE_NUM) {
        uint8_t byte = (uint8_t)wrenGetSlotDouble(vm, 1);
        write_bytebuffer(buffer, &byte, 1);
        wrenSetSlotNull(vm, 0);
    } else {
        wrenSetSlotString(vm, 0, "You must provide a Num as the byte to write.");
        wrenAbortFiber(vm, 0);
    }
}

static void api__ByteBuffer__read__0(WrenVM *vm) {
    ByteBuffer *buffer = wrenGetSlotForeign(vm, 0);
    if (buffer->bytes) {
        wrenSetSlotBytes(vm, 0, buffer->bytes, buffer->count);
    } else {
        wrenSetSlotString(vm, 0, "");
    }
}

static void api__ByteBuffer__size__getter(WrenVM *vm) {
    ByteBuffer *buffer = wrenGetSlotForeign(vm, 0);
    wrenSetSlotDouble(vm, 0, (double)buffer->count);
}

static void api__ByteBuffer__truncate__1(WrenVM *vm) {
    ByteBuffer *buffer = wrenGetSlotForeign(vm, 0);
    if (wrenGetSlotType(vm, 1) == WREN_TYPE_NUM) {
        size_t count = (size_t)wrenGetSlotDouble(vm, 1);
        if (count < buffer->count) buffer->count = count;
        wrenSetSlotNull(vm, 0);
    } else {
        wrenSetSlotString(vm, 0, "The parameter to truncate(_) must be a Num.");
    }
}

static void api__ByteBuffer__clear__0(WrenVM *vm) {
    ByteBuffer *buffer = wrenGetSlotForeign(vm, 0);
    buffer->count = 0;
    wrenSetSlotNull(vm, 0);
}

static void apiStatic__Platform__name__getter(WrenVM *vm) {
    const char *result = "Unknown";
    #ifdef __linux__
        result = "Linux";
    #endif
    #ifdef __APPLE__
        result = "OS X";
    #endif
    #ifdef _WIN32
        result = "Windows"
    #endif
    wrenSetSlotString(vm, 0, result);
}

static void apiStatic__Platform__isPosix__getter(WrenVM *vm) {
    bool isPosix = 
    #if defined(__unix__) || (defined(__APPLE__) && defined(__MACH))
        true
    #else
        false
    #endif
    ;
    wrenSetSlotBool(vm, 0, isPosix);
}

static void apiStatic__Platform__isWindows__getter(WrenVM *vm) {
    bool isWindows = 
    #ifdef _WIN32
        true
    #else
        false
    #endif
    ;
    wrenSetSlotBool(vm, 0, isWindows);
}

static void apiStatic__Platform__arch__getter(WrenVM *vm) {
    const char *arch =
    #if defined(__x64_64__)
    "x86_64"
    #elif defined(__i386)
    "i386"
    #elif defined(__aarch64__)
    "aarch64"
    #elif defined(__arm__)
    "arm"
    #else
    "unknown"
    #endif
    ;

    wrenSetSlotString(vm, 0, arch);
}

static void abortWithErrno(WrenVM *vm, int e) {
    char *s = strerror(e);
    char *message = malloc(strlen(s) + 32);
    strcpy(message, s);
    sprintf(&message[strlen(message)], "(OS error %d)", e);
    wrenSetSlotString(vm, 0, message);
    free(message);
    wrenAbortFiber(vm, 0);
}

static void apiOpGetIndex__Environ(WrenVM *vm) {
    const char *key;
    bool ok = true;
    if (wrenGetSlotType(vm, 1) == WREN_TYPE_STRING) {
        key = wrenGetSlotString(vm, 1);
    } else {
        ok = false;
        wrenSetSlotString(vm, 0, "Environ keys must be strings.");
        wrenAbortFiber(vm, 0);
    }
    if (ok) {
        char *var = getenv(key);
        if (var) {
            wrenSetSlotString(vm, 0, var);
        } else {
            wrenSetSlotNull(vm, 0);
        }
    }
}

static void apiOpSetIndex__Environ__1(WrenVM *vm) {
    bool ok = true;
    const char *key;
    const char *value;
    if (wrenGetSlotType(vm, 1) != WREN_TYPE_STRING) {
        ok = false;
        wrenSetSlotString(vm, 0, "Environ keys must be strings.");
        wrenAbortFiber(vm, 0);
    }
    if (wrenGetSlotType(vm, 2) != WREN_TYPE_STRING) {
        ok = false;
        wrenSetSlotString(vm, 0, "Environ values must be strings.");
        wrenAbortFiber(vm, 0);
    }
    if (ok) {
        key = wrenGetSlotString(vm, 1);
        value = wrenGetSlotString(vm, 2);
        bool invalid_key = false;
        for (size_t i = 0; key[i]; i ++) {
            if (key[i] == '=') {
                invalid_key = true;
                break;
            }
        }
        if (invalid_key) {
            wrenSetSlotString(vm, 0, "Environ keys may not contain the `=` character.");
            wrenAbortFiber(vm, 0);
            ok = false;
        }
    }
    if (ok) {
        int result = setenv(key, value, 1);
        if (result < 0) {
            abortWithErrno(vm, errno);
        } else {
            wrenSetSlotNull(vm, 0);
        }
    }
}

static
void api__Environ__keyAt__1(WrenVM *vm) {
    size_t index = (size_t)wrenGetSlotDouble(vm, 1);
    if (environ[index]) {
        size_t i;
        for (i = 0; environ[index][i]; i ++) {
            if (environ[index][i] == '=') break;
        }
        wrenSetSlotBytes(vm, 0, environ[index], i);
    } else {
        wrenSetSlotNull(vm, 0);
    }
}

static
void api__Environ__valueAt__1(WrenVM *vm) {
    size_t index = (size_t)wrenGetSlotDouble(vm, 1);
    if (environ[index]) {
        size_t i;
        for (i = 0; environ[index][i]; i ++) {
            if (environ[index][i] == '=') break;
        }
        i ++;
        wrenSetSlotBytes(vm, 0, &environ[index][i], strlen(environ[index])-i);
    } else {
        wrenSetSlotNull(vm, 0);
    }
}

static
void apiStatic__Process__arguments__getter(WrenVM *vm) {
    wrenEnsureSlots(vm, 2);
    wrenSetSlotNewList(vm, 0);
    for (size_t i = 0; i < global_argc; i ++) {
        wrenSetSlotString(vm, 1, global_argv[i]);
        wrenInsertInList(vm, 0, -1, 1);
    }
}

void apiInit__stdlib(void) {
    CModule *gg_stdlib = register_cmodule("gg_stdlib");

    register_class(gg_stdlib, "ByteBuffer", &apiAllocate__ByteBuffer, &apiFinalize__ByteBuffer);
    register_method(gg_stdlib, "ByteBuffer", "write(_)", &api__ByteBuffer__write__1);
    register_method(gg_stdlib, "ByteBuffer", "writeByte(_)", &api__ByteBuffer__writeByte__1);
    register_method(gg_stdlib, "ByteBuffer", "read()", &api__ByteBuffer__read__0);
    register_method(gg_stdlib, "ByteBuffer", "size", &api__ByteBuffer__size__getter);
    register_method(gg_stdlib, "ByteBuffer", "truncate(_)", &api__ByteBuffer__truncate__1);
    register_method(gg_stdlib, "ByteBuffer", "clear()", &api__ByteBuffer__clear__0);

    register_method(gg_stdlib, "Platform", "static name", &apiStatic__Platform__name__getter);
    register_method(gg_stdlib, "Platform", "static isPosix", &apiStatic__Platform__isPosix__getter);
    register_method(gg_stdlib, "Platform", "static isWindows",
            &apiStatic__Platform__isWindows__getter);
    register_method(gg_stdlib, "Platform", "static arch", &apiStatic__Platform__arch__getter);

    register_method(gg_stdlib, "Environ", "[_]", &apiOpGetIndex__Environ);
    register_method(gg_stdlib, "Environ", "[_]=(_)", &apiOpSetIndex__Environ__1);
    register_method(gg_stdlib, "Environ", "keyAt_(_)", &api__Environ__keyAt__1);
    register_method(gg_stdlib, "Environ", "valueAt_(_)", &api__Environ__valueAt__1);

    register_method(gg_stdlib, "Process", "static arguments",
            &apiStatic__Process__arguments__getter);
}
