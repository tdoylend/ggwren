#include <stdint.h>
#include <string.h>

#include "ggwren.h"

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

void apiInit__stdlib(void) {
    REGISTER_CLASS("stdlib", "ByteBuffer", &apiAllocate__ByteBuffer, &apiFinalize__ByteBuffer);
    REGISTER("stdlib", "ByteBuffer", "write(_)", &api__ByteBuffer__write__1);
    REGISTER("stdlib", "ByteBuffer", "writeByte(_)", &api__ByteBuffer__writeByte__1);
    REGISTER("stdlib", "ByteBuffer", "read()", &api__ByteBuffer__read__0);
    REGISTER("stdlib", "ByteBuffer", "size", &api__ByteBuffer__size__getter);
    REGISTER("stdlib", "ByteBuffer", "truncate(_)", &api__ByteBuffer__truncate__1);
    REGISTER("stdlib", "ByteBuffer", "clear()", &api__ByteBuffer__clear__0);
}
