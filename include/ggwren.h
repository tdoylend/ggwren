#ifndef GGWREN_H
#define GGWREN_H

#ifndef GG_HOST

#include <stdbool.h>
#include <stddef.h>

typedef struct WrenVM WrenVM;
typedef struct WrenHandle WrenHandle;
typedef void (*WrenForeignMethodFn)(WrenVM* vm);
typedef void (*WrenFinalizerFn)(void* data);

enum WrenType {
  WREN_TYPE_BOOL,
  WREN_TYPE_NUM,
  WREN_TYPE_FOREIGN,
  WREN_TYPE_LIST,
  WREN_TYPE_MAP,
  WREN_TYPE_NULL,
  WREN_TYPE_STRING,
  WREN_TYPE_UNKNOWN,
  WREN_TYPE_MAX
};
typedef enum WrenType WrenType;

#endif 

typedef const char WrenByte;

#define GG_ABI_ENTRIES(_) \
/*Return type  Name                  Parameters with types                      Params w/o types */\
_(int,         wrenGetVersionNumber, (void),                                    ()                )\
_(void,        wrenCollectGarbage,   (WrenVM *vm),                              (vm)              )\
_(void,        wrenReleaseHandle,    (WrenVM *vm, WrenHandle *handle),          (vm, handle)      )\
_(int,         wrenGetSlotCount,     (WrenVM *vm),                              (vm)              )\
_(void,        wrenEnsureSlots,      (WrenVM *vm, int count),                   (vm, count)       )\
_(WrenType,    wrenGetSlotType_,     (WrenVM *vm, int slot),                    (vm, slot)        )\
_(bool,        wrenGetSlotBool,      (WrenVM *vm, int slot),                    (vm, slot)        )\
_(WrenByte*,   wrenGetSlotBytes,     (WrenVM *vm, int slot, int *len),          (vm, slot, len)   )\
_(double,      wrenGetSlotDouble,    (WrenVM *vm, int slot),                    (vm, slot)        )\
_(void*,       wrenGetSlotForeign,   (WrenVM *vm, int slot),                    (vm, slot)        )\
_(const char*, wrenGetSlotString,    (WrenVM *vm, int slot),                    (vm, slot)        )\
_(WrenHandle*, wrenGetSlotHandle,    (WrenVM *vm, int slot),                    (vm, slot)        )\
_(void,        wrenSetSlotBool,      (WrenVM *vm, int slot, bool val),          (vm, slot, val)   )\
_(void,     wrenSetSlotBytes,(WrenVM *vm,int slot,WrenByte *bytes,size_t len), (vm,slot,bytes,len))\
_(void,        wrenSetSlotDouble,    (WrenVM *vm, int slot, double val),        (vm, slot, val)   )\
_(void*,       wrenSetSlotNewForeign,(WrenVM *vm, int slot,int cls,size_t size),(vm,slot,cls,size))\
_(void,        wrenSetSlotNewList,   (WrenVM *vm, int slot),                    (vm, slot)        )\
_(void,        wrenSetSlotNewMap,    (WrenVM *vm, int slot),                    (vm, slot)        )\
_(void,        wrenSetSlotNull,      (WrenVM *vm, int slot),                    (vm, slot)        )\
_(void,        wrenSetSlotString,    (WrenVM *vm, int slot, const char *string),(vm, slot, string))\
_(void,        wrenSetSlotHandle,    (WrenVM *vm, int slot, WrenHandle *handle),(vm, slot, handle))\
_(int,         wrenGetListCount,     (WrenVM *vm, int slot),                    (vm, slot)        )\
_(void,        wrenGetListElement,   (WrenVM *vm, int list, int idx, int elem), (vm,list,idx,elem))\
_(void,        wrenSetListElement,   (WrenVM *vm, int list, int idx, int elem), (vm,list,idx,elem))\
_(void,        wrenInsertInList,     (WrenVM *vm, int list, int idx, int elem), (vm,list,idx,elem))\
_(int,         wrenGetMapCount,      (WrenVM *vm, int slot),                    (vm, slot)        )\
_(bool,        wrenGetMapContainsKey,(WrenVM *vm, int map, int key),            (vm, map, key)    )\
_(void,        wrenGetMapValue,      (WrenVM *vm, int map, int key, int val),   (vm,map, key, val))\
_(void,        wrenSetMapValue,      (WrenVM *vm, int map, int key, int val),   (vm,map, key, val))\
_(void,        wrenRemoveMapValue,   (WrenVM *vm, int map, int key, int val),   (vm,map, key, val))\
_(void,        wrenAbortFiber,       (WrenVM *vm, int slot),                    (vm, slot)        )\
_(void,        ggRegisterClass,      (const char *name, WrenForeignMethodFn allocate,              \
                                          WrenFinalizerFn finalize),            (name, allocate,   \
                                                                                     finalize)    )\
_(void,        ggRegisterMethod,     (const char *cls, const char *sig,                            \
                                          WrenForeignMethodFn fn),              (cls, sig, fn)    )

typedef struct GG_ABI GG_ABI;
struct GG_ABI {

    #define GG_ABI_ENTRY(returnType, name, signature, params) returnType (*name) signature;
    GG_ABI_ENTRIES(GG_ABI_ENTRY)
    #undef GG_ABI_ENTRY
};

typedef int (*ggExt_BootstrapFn)(GG_ABI *abi);
typedef void (*ggExt_InitFn)(void);
typedef void (*ggExt_FinishFn)(void);

#define GG_BOOTSTRAP_OK                0

#ifndef GG_HOST

int ggExt_bootstrap(GG_ABI* abi);
extern GG_ABI* ggABI;

void ggExt_init(void);
void ggExt_finish(void);

#define GG_API(returnType, name, signature, params) \
    static returnType name signature { return ggABI->name params; }
GG_ABI_ENTRIES(GG_API)
#undef GG_API

// A special definition of wrenGetSlotType is in play here, in case future version of
// wren add more types to this enum; we coerce the new ones down to WREN_TYPE_UNKNOWN.
static WrenType wrenGetSlotType(WrenVM *vm, int slot) {
    WrenType result = wrenGetSlotType_(vm, slot);
    if (result >= WREN_TYPE_MAX) result = WREN_TYPE_UNKNOWN;
    return result;
    
}

#ifdef GG_EXT_IMPLEMENTATION

GG_ABI* ggABI = NULL;
int ggExt_bootstrap(GG_ABI* abi) {
    ggABI = abi;
    return GG_BOOTSTRAP_OK;
}

#endif

#endif

#endif
