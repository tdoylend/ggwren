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

#include <errno.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>

#include <wren.h>

// Platform-specific includes
#ifdef __linux__
#include <dirent.h>
#include <fcntl.h>
#include <netdb.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>
extern char **environ;
#elif defined(_WIN32)
#error
#endif

#include "gg.h"

bool hpcInitialized = false;
uint64_t hpcEpoch;

typedef struct Buffer Buffer;
struct Buffer {
    uint8_t *bytes;
    size_t count;
    size_t capacity;
};

static void apiAllocate_Buffer(WrenVM *vm) {
    Buffer *buffer = wrenSetSlotNewForeign(vm, 0, 0, sizeof(Buffer));
    memset(buffer, 0, sizeof(Buffer));
}

static void apiFinalize_Buffer(void *raw) {
    Buffer *buffer = raw;
    if (buffer->bytes) free(buffer->bytes);
}

static void writeBuffer(Buffer *buffer, const uint8_t *bytes, size_t count) {
    if (count > 0) {
        if ((buffer->count + count) > buffer->capacity) {
            buffer->capacity = nextPowerOfTwo(buffer->count + count);
            buffer->bytes = realloc(buffer->bytes, buffer->capacity);
        }
        memcpy(&buffer->bytes[buffer->count], bytes, count);
        buffer->count += count;
    }
}

static void api_Buffer_write_1(WrenVM *vm) {
    Buffer *buffer = wrenGetSlotForeign(vm, 0);
    int count;
    if (wrenGetSlotType(vm, 1) == WREN_TYPE_STRING) {
        const uint8_t *bytes = wrenGetSlotBytes(vm, 1, &count);
        writeBuffer(buffer, bytes, (size_t)count);
        wrenSetSlotNull(vm, 0);
    } else {
        wrenSetSlotString(vm, 0, "Cannot write a non-String to Buffer.");
        wrenAbortFiber(vm, 0);
    }
}

static void api_Buffer_writeByte_1(WrenVM *vm) {
    Buffer *buffer = wrenGetSlotForeign(vm, 0);
    if (wrenGetSlotType(vm, 1) == WREN_TYPE_NUM) {
        uint8_t byte = (uint8_t)wrenGetSlotDouble(vm, 1);
        writeBuffer(buffer, &byte, 1);
        wrenSetSlotNull(vm, 0);
    } else {
        wrenSetSlotString(vm, 0, "You must provide a Num as the byte to write.");
        wrenAbortFiber(vm, 0);
    }
}

static void api_Buffer_read_0(WrenVM *vm) {
    Buffer *buffer = wrenGetSlotForeign(vm, 0);
    if (buffer->bytes) {
        wrenSetSlotBytes(vm, 0, buffer->bytes, buffer->count);
    } else {
        wrenSetSlotString(vm, 0, "");
    }
}

static void api_Buffer_size_getter(WrenVM *vm) {
    Buffer *buffer = wrenGetSlotForeign(vm, 0);
    wrenSetSlotDouble(vm, 0, (double)buffer->count);
}

static void api_Buffer_truncate_1(WrenVM *vm) {
    Buffer *buffer = wrenGetSlotForeign(vm, 0);
    if (wrenGetSlotType(vm, 1) == WREN_TYPE_NUM) {
        size_t count = (size_t)wrenGetSlotDouble(vm, 1);
        if (count <= buffer->count) {
            wrenSetSlotBytes(vm, 0, &buffer->bytes[count], buffer->count - count);
            buffer->count = count;
        } else {
            wrenSetSlotNull(vm, 0);
        }
    } else {
        wrenSetSlotString(vm, 0, "The parameter to truncate(_) must be a Num.");
    }
}

static void api_Buffer_clear_0(WrenVM *vm) {
    Buffer *buffer = wrenGetSlotForeign(vm, 0);
    buffer->count = 0;
    wrenSetSlotNull(vm, 0);
}

static void apiStatic_Platform_name_getter(WrenVM *vm) {
    const char *result = "Unknown";
    #ifdef _linux_
        result = "Linux";
    #endif
    #ifdef _APPLE_
        result = "OS X";
    #endif
    #ifdef _WIN32
        result = "Windows"
    #endif
    wrenSetSlotString(vm, 0, result);
}

static void apiStatic_Platform_isPosix_getter(WrenVM *vm) {
    bool isPosix = 
    #if defined(_unix_) || (defined(_APPLE_) && defined(_MACH))
        true
    #else
        false
    #endif
    ;
    wrenSetSlotBool(vm, 0, isPosix);
}

static void apiStatic_Platform_isWindows_getter(WrenVM *vm) {
    bool isWindows = 
    #ifdef _WIN32
        true
    #else
        false
    #endif
    ;
    wrenSetSlotBool(vm, 0, isWindows);
}

static void apiStatic_Platform_arch_getter(WrenVM *vm) {
    const char *arch =
    #if defined(_x64_64_)
    "x86_64"
    #elif defined(_i386)
    "i386"
    #elif defined(_aarch64_)
    "aarch64"
    #elif defined(_arm_)
    "arm"
    #else
    "unknown"
    #endif
    ;

    wrenSetSlotString(vm, 0, arch);
}

static void abortErrno(WrenVM *vm, int e) {
    char *s = strerror(e);
    char *message = malloc(strlen(s) + 32);
    strcpy(message, s);
    sprintf(&message[strlen(message)], " (OS error %d)", e);
    wrenSetSlotString(vm, 0, message);
    free(message);
    wrenAbortFiber(vm, 0);
}

static void apiOpGetIndex_Environ(WrenVM *vm) {
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

static void apiOpSetIndex_Environ_1(WrenVM *vm) {
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
            abortErrno(vm, errno);
        } else {
            wrenSetSlotNull(vm, 0);
        }
    }
}

static
void api_Environ_keyAt_1(WrenVM *vm) {
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
void api_Environ_valueAt_1(WrenVM *vm) {
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
void apiStatic_Process_arguments_getter(WrenVM *vm) {
    wrenEnsureSlots(vm, 2);
    wrenSetSlotNewList(vm, 0);
    for (size_t i = 0; i < scriptArgc; i ++) {
        wrenSetSlotString(vm, 1, scriptArgv[i]);
        wrenInsertInList(vm, 0, -1, 1);
    }
}

static
void apiStatic_Process_exit_1(WrenVM* vm) {
    exit((int)wrenGetSlotDouble(vm,1));
}

typedef struct File File;
struct File {
    int fd;
};

static void apiAllocate_File(WrenVM *vm) {
    const char *path = wrenGetSlotString(vm, 1);
    const char *mode = wrenGetSlotString(vm, 2);
    bool reading = false;
    bool writing = false;
    bool appending = false;
    bool exclusive = false;
    for (const char *cursor = mode; *cursor; cursor ++) {
        char c = *cursor;
        if (c == 'r') {
            reading = true;
        } else if (c == 'w') {
            writing = true;
        } else if (c == 'a') {
            appending = true;
        } else if (c == 't') {
            // do nothing; Wren makes no distinction between text and binary
        } else if (c == 'b') {
            // do nothing; Wren makes no distinction between text and binary
        } else if (c == 'x') {
            exclusive = true;
        } else if (c == '+') {
            reading = true;
            writing = true;
        }
    }
    File *file = wrenSetSlotNewForeign(vm, 0, 0, sizeof(File));
    int flags = 0;
    if (reading && (writing || appending)) flags |= O_RDWR;
    else if (reading) flags |= O_RDONLY;
    else if (writing || appending) flags |= O_WRONLY;
    if (exclusive) flags |= O_EXCL;
    if (writing || appending) flags |= O_CREAT;
    if (writing) flags |= O_TRUNC;
    if (appending) flags |= O_APPEND;
    file->fd = open(path, flags, (writing || appending) ? 0644 : 0);
    if (file->fd < 0) {
        abortErrno(vm, errno);
    } else {
        // do nothing
    }
}

static void apiFinalize_File(void *file_raw) {
    File *file = file_raw;
    if (file->fd >= 0) {
        close(file->fd);
    }
}

static void api_File_size_getter(WrenVM *vm) {
    File *file = wrenGetSlotForeign(vm, 0);
    if (file->fd >= 0) {
        struct stat st; 
        if (fstat(file->fd, &st) < 0) {
            abortErrno(vm, errno);
        } else {
            wrenSetSlotDouble(vm, 0, (double)(st.st_size));
        }
    } else {
        wrenSetSlotString(vm, 0, "The file has already been closed.");
        wrenAbortFiber(vm, 0);
    }
}

static void api_File_read_1(WrenVM *vm) {
    File *file = wrenGetSlotForeign(vm, 0);
    size_t count = (size_t)wrenGetSlotDouble(vm, 1);
    if (file->fd >= 0) {
        char short_buffer[4096];
        char *buffer = short_buffer;
        bool buffer_is_long = false;
        if (count > 4096) {
            buffer = malloc(count);
            buffer_is_long = true;
        }
        ssize_t bytes_read = read(file->fd, buffer, count);
        if (bytes_read >= 0) {
            wrenSetSlotBytes(vm, 0, buffer, bytes_read);
        } else {
            abortErrno(vm, errno);
        }
        if (buffer_is_long) free(buffer);
    } else {
        wrenSetSlotString(vm, 0, "The file has already been closed.");
        wrenAbortFiber(vm, 0);
    }
}

void api_File_seek_1(WrenVM *vm) {
    File *file = wrenGetSlotForeign(vm, 0);
    size_t where = (size_t)wrenGetSlotDouble(vm, 1);
    if (file->fd >= 0) {
        if (lseek(file->fd, where, SEEK_SET) < 0) {
            abortErrno(vm, errno);
        } else {
            wrenSetSlotNull(vm, 0);
        }
    } else {
        wrenSetSlotString(vm, 0, "The file has already been closed.");
        wrenAbortFiber(vm, 0);
    }
}

void api_File_tell_0(WrenVM *vm) {
    File *file = wrenGetSlotForeign(vm, 0);
    if (file->fd >= 0) {
        off_t where = lseek(file->fd, 0, SEEK_CUR);
        if (where < 0) {
            abortErrno(vm, errno);
        } else {
            wrenSetSlotDouble(vm, 0, (double)where);
        }
    } else {
        wrenSetSlotString(vm, 0, "The file has already been closed.");
        wrenAbortFiber(vm, 0);
    }
}

void api_File_write_1(WrenVM *vm) {
    File *file = wrenGetSlotForeign(vm, 0);
    if (file->fd >= 0) {
        int length;
        const uint8_t *data = wrenGetSlotBytes(vm, 1, &length);
        ssize_t bytes_written = write(file->fd, data, length);
        if (bytes_written < 0) {
            abortErrno(vm, errno);
        } else {
            wrenSetSlotDouble(vm, 0, (double)bytes_written);
        }
    } else {
        wrenSetSlotString(vm, 0, "The file has already been closed.");
        wrenAbortFiber(vm, 0);
    }
}

void api_File_close_0(WrenVM *vm) {
    File *file = wrenGetSlotForeign(vm, 0);
    if (file->fd >= 0) {
        close(file->fd);
    } else {
        wrenSetSlotString(vm, 0, "The file has already been closed.");
        wrenAbortFiber(vm, 0);
    }
    file->fd = -1;
}

void apiStatic_Fs_pathSep_getter(WrenVM *vm) {
    const char *pathSep =
    #ifdef _WIN32
    "\\"
    #else
    "/"
    #endif
    ;
    wrenSetSlotString(vm, 0, pathSep);
}

void apiStatic_Fs_canonical_1(WrenVM *vm) {
    char *path = realpath(wrenGetSlotString(vm, 1), NULL);
    if (path != NULL) {
        wrenSetSlotString(vm, 0, path);
        free(path);
    } else {
        if (errno == ENOENT) {
            wrenSetSlotNull(vm, 0);
        } else {
            abortErrno(vm, errno);
        }
    }
}

void apiStatic_Fs_listDir_1(WrenVM *vm) {
    DIR *dir;
    struct dirent *entry;
    dir = opendir(wrenGetSlotString(vm, 1));
    if (dir) {
        errno = 0;
        wrenSetSlotNewList(vm, 0);
        while (entry = readdir(dir)) {
            if (strcmp(entry->d_name, ".") && strcmp(entry->d_name, "..")) {

                wrenSetSlotString(vm, 1, entry->d_name);
                wrenInsertInList(vm, 0, -1, 1);
            }
        }
        if (errno) {
            abortErrno(vm, errno);
        }
        closedir(dir);
    } else {
        abortErrno(vm, errno);
    }
}

void apiStatic_Fs_fileSize_1(WrenVM *vm) {
    struct stat st;
    if (stat(wrenGetSlotString(vm, 1), &st) >= 0) {
        wrenSetSlotDouble(vm, 0, (double)(st.st_size));
    } else {
        abortErrno(vm, errno);
    }
}

void apiStatic_Fs_readLink_1(WrenVM *vm) {
    size_t buf_cap = 256;
    char *buf = malloc(buf_cap);
    errno = 0;
    const char *path = wrenGetSlotString(vm, 1);
    while (readlink(path, buf, buf_cap) == buf_cap) {
        buf_cap <<= 1;
        buf = realloc(buf, buf_cap);
    }
    if (errno) {
        abortErrno(vm, errno);
    } else {
        wrenSetSlotString(vm, 0, buf);
    }
    free(buf);
}

void apiStatic_Fs_exists_1(WrenVM *vm) {
    struct stat st;
    if (stat(wrenGetSlotString(vm, 1), &st) >= 0) {
        wrenSetSlotBool(vm, 0, true);
    } else {
        if (errno == ENOENT) {
            wrenSetSlotBool(vm, 0, false);
        } else {
            abortErrno(vm, errno);
        }
    }
}

void apiStatic_Fs_isFile_1(WrenVM *vm) {
    struct stat st;
    if (stat(wrenGetSlotString(vm, 1), &st) >= 0) {
        wrenSetSlotBool(vm, 0, st.st_mode & S_IFREG);
    } else {
        if (errno == ENOENT) {
            wrenSetSlotBool(vm, 0, false);
        } else {
            abortErrno(vm, errno);
        }
    }
}

void apiStatic_Fs_isDir_1(WrenVM *vm) {
    struct stat st;
    if (stat(wrenGetSlotString(vm, 1), &st) >= 0) {
        wrenSetSlotBool(vm, 0, st.st_mode & S_IFDIR);
    } else {
        if (errno == ENOENT) {
            wrenSetSlotBool(vm, 0, false);
        } else {
            abortErrno(vm, errno);
        }
    }
}

void apiStatic_Fs_isLink_1(WrenVM *vm) {
    struct stat st;
    if (lstat(wrenGetSlotString(vm, 1), &st) >= 0) {
        wrenSetSlotBool(vm, 0, st.st_mode & S_IFLNK);
    } else {
        if (errno == ENOENT) {
            wrenSetSlotBool(vm, 0, false);
        } else {
            abortErrno(vm, errno);
        }
    }
}

void apiStatic_Time_now_getter(WrenVM* vm) {
    struct timespec now;
    (void)clock_gettime(CLOCK_REALTIME, &now);

    double result = (double)(now.tv_nsec) * 0.000000001;
    result += (double)(now.tv_sec);
    wrenSetSlotDouble(vm, 0, result);
}

void apiStatic_Time_sleep_1(WrenVM* vm) {
    usleep((uint64_t)(wrenGetSlotDouble(vm, 1) * 1000000.0));
    wrenSetSlotNull(vm, 0);
}

void apiStatic_Time_hpc_getter(WrenVM* vm) {
    struct timespec now;
    (void)clock_gettime(CLOCK_MONOTONIC_RAW, &now);

    uint64_t hpcNow = now.tv_sec * 100000000 + (now.tv_nsec / 10);

    if (!hpcInitialized) {
        hpcInitialized = true;
        hpcEpoch = hpcNow;
        wrenSetSlotDouble(vm, 0, 0.0f);
    } else {
        wrenSetSlotDouble(vm, 0, (double)(hpcNow - hpcEpoch));
    }
}

void apiStatic_Time_hpcResolution_getter(WrenVM* vm) {
    wrenSetSlotDouble(vm, 0, 100000000.0f);
}
void apiAllocate_TcpListener(WrenVM* vm) {
    bool ok = true;
    int gaiResult = 0;
    int* listener = wrenSetSlotNewForeign(vm, 0, 0, sizeof(int));
    struct addrinfo *res = NULL;
    *listener = socket(AF_INET, SOCK_STREAM, 0);
    if (listener < 0) ok = false;
    if (ok) {
        int enable = 1;
        (void)setsockopt(*listener, SOL_SOCKET, SO_REUSEADDR, &enable, sizeof(int));
        (void)setsockopt(*listener, SOL_SOCKET, SO_REUSEPORT, &enable, sizeof(int));
    }
    if (ok) {
        struct addrinfo hints;
        memset(&hints, 0, sizeof(hints));
        hints.ai_family = AF_INET;
        hints.ai_socktype = SOCK_STREAM;
        hints.ai_protocol = 0;
        gaiResult = getaddrinfo(wrenGetSlotString(vm, 1), wrenGetSlotString(vm, 2), &hints, &res);
        if (gaiResult != 0) {
            ok = false;
        }
    }
    if (ok) {
        if (bind(*listener, res->ai_addr, res->ai_addrlen) < 0) {
            ok = false;
        }
    }
    if (ok) {
        if (listen(*listener, 10)) ok = false;
    }
    if (res) freeaddrinfo(res);
    if (!ok) {
        if (gaiResult) {
            wrenSetSlotString(vm, 0, gai_strerror(gaiResult));
            wrenAbortFiber(vm, 0);
        } else {
            abortErrno(vm, errno);
        }
        if (*listener >= 0) (void)close(*listener);
    }
}

void apiFinalize_socket(void* data) {
    int* sock = data;
    if (*sock >= 0) {
        (void)close(*sock);
    }
}

void api_socket_blocking_getter(WrenVM* vm) {
    int* sock = wrenGetSlotForeign(vm, 0);
    int flags = fcntl(*sock, F_GETFL, 0);
    if (flags < 0) {
        abortErrno(vm, errno);
    } else {
        wrenSetSlotBool(vm, 0, !(flags & O_NONBLOCK));
    }
}

void api_socket_blocking_setter(WrenVM* vm) {
    int* sock = wrenGetSlotForeign(vm, 0);
    int flags = fcntl(*sock, F_GETFL, 0);
    if (flags < 0) {
        abortErrno(vm, errno);
    } else {
        bool blocking = wrenGetSlotBool(vm, 1);
        flags = blocking ? flags & ~O_NONBLOCK : flags | O_NONBLOCK;
        if (fcntl(*sock, F_SETFL, flags) < 0) {
            abortErrno(vm, errno);
        }
    }
}

void api_socket_close_0(WrenVM *vm) {
    int* sock = wrenGetSlotForeign(vm, 0);
    if (*sock >= 0) {
        close(*sock);
        *sock = -1;
    } else {
        wrenSetSlotString(vm, 0, "Socket has already been closed.");
        wrenAbortFiber(vm, 0);
    }
}

void api_socket_isOpen_getter(WrenVM* vm) {
    int* sock = wrenGetSlotForeign(vm, 0);
    wrenSetSlotBool(vm, 0, *sock >= 0);
}

void apiAllocate_TcpStream(WrenVM* vm) {
    int* sock = wrenSetSlotNewForeign(vm, 0, 0, sizeof(int));

    /*@todo*/
}

void api_TcpStream_peerAddress_getter(WrenVM* vm) {
    int* sock = wrenGetSlotForeign(vm, 0);
    struct sockaddr_storage addr;
    socklen_t addrlen = sizeof(addr);
    char host[512];
    char port[64];
    int gniResult = 0;
    if (getpeername(*sock, (struct sockaddr*)(&addr), &addrlen) < 0) {
        abortErrno(vm, errno);
    } else if (gniResult = getnameinfo((struct sockaddr*)(&addr), addrlen, host, 512, port,
            64, NI_NUMERICHOST)) {
        wrenSetSlotString(vm, 0, gai_strerror(gniResult));
        wrenAbortFiber(vm, 0);
    } else {
        wrenSetSlotString(vm, 0, host);
    }
}

void api_TcpStream_peerPort_getter(WrenVM* vm) {
    int* sock = wrenGetSlotForeign(vm, 0);
    struct sockaddr addr;
    socklen_t addrlen = sizeof(addr);
    char host[512];
    char port[64];
    int gniResult = 0;
    if (getpeername(*sock, &addr, &addrlen) < 0) {
        abortErrno(vm, errno);
    } else if (gniResult = getnameinfo(&addr, addrlen, host, 512, port, 64, NI_NUMERICHOST)) {
        wrenSetSlotString(vm, 0, gai_strerror(gniResult));
        wrenAbortFiber(vm, 0);
    } else {
        wrenSetSlotString(vm, 0, port);
    }
}

void apiStatic_TcpStream_acceptFrom__1(WrenVM* vm) {
    int* listener = wrenGetSlotForeign(vm, 1);
    int clientFd = accept(*listener, NULL, NULL);
    if (clientFd >= 0) {
        int* client = wrenSetSlotNewForeign(vm, 0, 0, sizeof(int));
        *client = clientFd;
    } else if ((errno == EWOULDBLOCK) || (errno == EAGAIN)) {
        wrenSetSlotNull(vm, 0);
    } else {
        abortErrno(vm, errno);
    }
}

void api_TcpStream_read_1(WrenVM* vm) {
    int* sock = wrenGetSlotForeign(vm, 0);
    size_t count = (size_t)wrenGetSlotDouble(vm, 1);
    char buf[count];
    ssize_t bytes_read = read(*sock, buf, count);
    if (bytes_read >= 0) {
        wrenSetSlotBytes(vm, 0, buf, bytes_read);
    } else if ((errno == EWOULDBLOCK) || (errno == EAGAIN)) {
        wrenSetSlotNull(vm, 0);
    } else {
        abortErrno(vm, errno);
    }
}

void api_TcpStream_write_1(WrenVM* vm) {
    int* sock = wrenGetSlotForeign(vm, 0);
    int count;
    const char* bytes = wrenGetSlotBytes(vm, 1, &count);
    ssize_t bytes_written = write(*sock, bytes, count);
    if (bytes_written >= 0) {
        wrenSetSlotDouble(vm, 0, (double)bytes_written);
    } else if ((errno == EWOULDBLOCK) || (errno == EAGAIN)) {
        wrenSetSlotNull(vm, 0);
    } else {
        abortErrno(vm, errno);
    }
}

void apiStatic_Deque_fastCopy__4(WrenVM *vm) {
    // list, destStart, sourceStart, count
    // Moves count items from [sourceStart...sourceStart+count] to [destStart...destStart+count].
    // The items are assumed to be non-overlapping.
    size_t dest = (size_t)wrenGetSlotDouble(vm, 2);
    size_t src = (size_t)wrenGetSlotDouble(vm, 3);
    size_t count = (size_t)wrenGetSlotDouble(vm, 4);
    for (size_t i = 0; i < count; i ++) {
        wrenGetListElement(vm, 1, src + i, 4);
        wrenSetListElement(vm, 1, dest + i, 4);
    }
    wrenSetSlotNull(vm, 0);
}

void apiStatic_Term_prompt_0(WrenVM* vm) {
    char* result = NULL;
    size_t n = 0;
    ssize_t length = getline(&result, &n, stdin);
    if (length < 0) {
        abortErrno(vm, errno);
    } else {
        if (length && (result[length - 1] == '\n')) length --;
        if (length && (result[length - 1] == '\r')) length --;
        wrenSetSlotBytes(vm, 0, result, length);
    }
    free(result);
}

void initBuiltins(void) {
    ggRegisterClass("Buffer", &apiAllocate_Buffer, &apiFinalize_Buffer);
    ggRegisterMethod("Buffer", "write(_)", &api_Buffer_write_1);
    ggRegisterMethod("Buffer", "writeByte(_)", &api_Buffer_writeByte_1);
    ggRegisterMethod("Buffer", "read()", &api_Buffer_read_0);
    ggRegisterMethod("Buffer", "size", &api_Buffer_size_getter);
    ggRegisterMethod("Buffer", "truncate(_)", &api_Buffer_truncate_1);
    ggRegisterMethod("Buffer", "clear()", &api_Buffer_clear_0);

    ggRegisterMethod("Platform", "static name", &apiStatic_Platform_name_getter);
    ggRegisterMethod("Platform", "static isPosix", &apiStatic_Platform_isPosix_getter);
    ggRegisterMethod("Platform", "static isWindows",
            &apiStatic_Platform_isWindows_getter);
    ggRegisterMethod("Platform", "static arch", &apiStatic_Platform_arch_getter);

    ggRegisterMethod("Environ", "[_]", &apiOpGetIndex_Environ);
    ggRegisterMethod("Environ", "[_]=(_)", &apiOpSetIndex_Environ_1);
    ggRegisterMethod("Environ", "keyAt_(_)", &api_Environ_keyAt_1);
    ggRegisterMethod("Environ", "valueAt_(_)", &api_Environ_valueAt_1);

    ggRegisterMethod("Process", "static arguments", &apiStatic_Process_arguments_getter);
    ggRegisterMethod("Process", "static exit(_)", &apiStatic_Process_exit_1);


    ggRegisterClass("File", &apiAllocate_File, &apiFinalize_File);
    ggRegisterMethod("File", "size", &api_File_size_getter);
    ggRegisterMethod("File", "read(_)", &api_File_read_1);
    ggRegisterMethod("File", "seek(_)", &api_File_seek_1);
    ggRegisterMethod("File", "tell()", &api_File_tell_0);
    ggRegisterMethod("File", "write(_)", &api_File_write_1);
    ggRegisterMethod("File", "close()", &api_File_close_0);
    //ggRegisterMethod("File", "blocking", &api_File_blocking_getter);
    //ggRegisterMethod("File", "blocking=(_)", &api_File_blocking_setter_1);
    ggRegisterMethod("Fs", "static pathSep", &apiStatic_Fs_pathSep_getter);
    ggRegisterMethod("Fs", "static canonical(_)", &apiStatic_Fs_canonical_1);
    ggRegisterMethod("Fs", "static listDir(_)", &apiStatic_Fs_listDir_1);
    ggRegisterMethod("Fs", "static fileSize(_)", &apiStatic_Fs_fileSize_1);
    ggRegisterMethod("Fs", "static readLink(_)", &apiStatic_Fs_readLink_1);
    ggRegisterMethod("Fs", "static exists(_)", &apiStatic_Fs_exists_1);
    ggRegisterMethod("Fs", "static isFile(_)", &apiStatic_Fs_isFile_1);
    ggRegisterMethod("Fs", "static isDir(_)", &apiStatic_Fs_isDir_1);
    ggRegisterMethod("Fs", "static isLink(_)", &apiStatic_Fs_isLink_1);

    ggRegisterMethod("Time", "static now", &apiStatic_Time_now_getter);
    ggRegisterMethod("Time", "static sleep(_)", &apiStatic_Time_sleep_1);
    ggRegisterMethod("Time", "static hpc", &apiStatic_Time_hpc_getter);
    ggRegisterMethod("Time", "static hpcResolution", &apiStatic_Time_hpcResolution_getter);

    ggRegisterClass("TcpListener", &apiAllocate_TcpListener, &apiFinalize_socket);
    ggRegisterMethod("TcpListener", "blocking", &api_socket_blocking_getter);
    ggRegisterMethod("TcpListener", "blocking=(_)", &api_socket_blocking_setter);
    ggRegisterMethod("TcpListener", "close()", &api_socket_close_0);
    ggRegisterMethod("TcpListener", "isOpen", &api_socket_isOpen_getter);

    ggRegisterClass("TcpStream", &apiAllocate_TcpStream, &apiFinalize_socket);
    ggRegisterMethod("TcpStream", "static acceptFrom_(_)", &apiStatic_TcpStream_acceptFrom__1);
    ggRegisterMethod("TcpStream", "blocking", &api_socket_blocking_getter);
    ggRegisterMethod("TcpStream", "blocking=(_)", &api_socket_blocking_setter);
    ggRegisterMethod("TcpStream", "close()", &api_socket_close_0);
    ggRegisterMethod("TcpStream", "read(_)", &api_TcpStream_read_1);
    ggRegisterMethod("TcpStream", "peerAddress", &api_TcpStream_peerAddress_getter);
    ggRegisterMethod("TcpStream", "peerPort", &api_TcpStream_peerPort_getter);
    ggRegisterMethod("TcpStream", "write(_)", &api_TcpStream_write_1);

    ggRegisterMethod("Deque", "static fastCopy_(_,_,_,_)", &apiStatic_Deque_fastCopy__4);
    ggRegisterMethod("Term", "static prompt()", &apiStatic_Term_prompt_0);
}
