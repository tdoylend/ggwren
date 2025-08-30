#define GG_EXT_IMPLEMENTATION
#include <ggwren.h>

#include <stdio.h>

void api_Test_square(WrenVM *vm) {
    double value = wrenGetSlotDouble(vm, 1);
    wrenSetSlotDouble(vm, 0, value * value);
}

void ggExt_init(void) {
    ggRegisterMethod("Test", "static square(_)", &api_Test_square);
}
