// GGWren
// Copyright 2025 Thomas Doylend. All rights reserved.
// For licensing information, please view the LICENSE.txt file.

#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Platform-specific includes

#ifdef __linux__

#include <dlfcn.h>
#include <libgen.h>
#include <unistd.h>

#elif _WIN32
#error
#endif

typedef struct Buffer Buffer;
struct Buffer {
    uint8_t *bytes;
    size_t count;
    size_t capacity_including_nul;
};
void pushBuffer(Buffer *buffer, const char *string);
void printfBuffer(Buffer *buffer, const char *format, ...);
void finishBuffer(Buffer *buffer);

char* asprintf(const char *format, ...);

typedef void* ExtHandle;
ExtHandle openExt(const char *name);
void closeExt(ExtHandle handle);
void* getExtFn(ExtHandle handle, const char *name);

static inline char *dupString(const char *string);
size_t nextPowerOfTwo(size_t x);
void addModuleSearchPath(const char *path);

// Global variables
char **argv;
int argc;

char* binPath = NULL;
char* binDir  = NULL;
char* scriptPath = NULL;
char* scriptDir = NULL;

const char *extError = NULL;

#define MAX_MODULE_SEARCH_PATHS 64
char* moduleSearchPaths[MAX_MODULE_SEARCH_PATHS];
int moduleSearchPathCount = 0;
bool tooManyModuleSearchPaths = false;

// Function implementations

char* asprintf(const char *format, ...) {
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

ExtHandle openExt(const char *name) {
    char* extPath = asprintf("%s/bin/%s.ggwren.so", binDir, name);
    printf("ding 2\n");
    ExtHandle handle = dlopen(extPath, 0);
    free(extPath);
    if (!handle) extError = dlerror();
}

void closeExt(ExtHandle handle) {
    (void)dlclose(handle);
}

void* getExtFn(ExtHandle handle, const char *name) {
    printf("ding 3\n");
    void* sym = dlsym(handle, name);
    printf("ding 4\n");
    if (!sym) extError = dlerror();
    return sym;
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
        moduleSearchPaths[moduleSearchPathCount] = dupString(path);
        moduleSearchPathCount ++;
    } else {
        tooManyModuleSearchPaths = true;
    }
}

int main(int argc_, char** argv_) {
    argc = argc_;
    argv = argv_;
    printf("[Program start]\n");
    bool ok = true;
    if (ok) {
        // Detect the binPath. Keep it NULL if this fails.
        size_t capacity = 0;
        ssize_t length = 0;
        while (ok && (length >= capacity)) {
            capacity = capacity ? capacity << 1 : 256;
            binPath = realloc(binPath, capacity);
            length = readlink("/proc/self/exe", binPath, capacity);
            if (length < 0) ok = false;
        }
        if (ok) {
            char *realBinPath = realpath(binPath, NULL);
            if (realBinPath) {
                free(binPath);
                binPath = realBinPath;
            } else {
                ok = false;
            }
        } 
        if (!ok) {
            if (binPath) free(binPath);
            binPath = NULL;
        }
    }
    if (binPath) {
        char *tempBinPath = dupString(binPath);
        binDir = dupString(dirname(tempBinPath));
        free(tempBinPath);
    }
    {
        ExtHandle test = openExt("test");
        printf("test = %llx\n", test);
        printf("dlerror = %s\n", dlerror());
        if (test) {
            void* extFn = getExtFn(test, "ggExt_bootstrap");
            printf("test.ggExt_bootstrap = %llx\n", extFn);
        }
    }
    if (tooManyModuleSearchPaths) {
        fprintf(stderr, "\x1b[33;1m[WARNING]\x1b[m ");
        fprintf(stderr, "Too many module search paths were added (the limit is %s); the extras\n"
                "were ignored.", MAX_MODULE_SEARCH_PATHS);
    }
    for (size_t i = 0; i < moduleSearchPathCount; i ++) {
        free(moduleSearchPaths[i]);
    }
    if (binPath) free(binPath);
    if (binDir) free(binDir);
    if (scriptPath) free(scriptPath);
    if (scriptDir) free(scriptDir);
    printf("[Program complete]\n");
    return 0;
}
