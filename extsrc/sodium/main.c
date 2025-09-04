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

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define GG_EXT_IMPLEMENTATION
#include <ggwren.h>

#include <sodium.h>

bool sodium_available = false;

void abortNoSodium(WrenVM *vm) {
    wrenSetSlotString(vm, 0, "sodium is not available (failed with a -1 initialization code");
    wrenAbortFiber(vm, 0);
}

void abortSodium(WrenVM* vm) {
    wrenSetSlotString(vm, 0, "sodium returned a -1 error code");
    wrenAbortFiber(vm, 0);
}

void apiStatic_sodium_hash_3(WrenVM* vm) {
    if (sodium_available) {
        char result[crypto_pwhash_STRBYTES];
        int passwdlen;
        const char* passwd = wrenGetSlotBytes(vm, 1, &passwdlen);
        unsigned long long opslimit = (unsigned long long)wrenGetSlotDouble(vm, 2);
        size_t memlimit = (size_t)wrenGetSlotDouble(vm, 3);
        if (crypto_pwhash_str(result, passwd, passwdlen, opslimit, memlimit) == 0) {
            wrenSetSlotString(vm, 0, result);
        } else {
            abortSodium(vm);
        }
    } else {
        abortNoSodium(vm);
    }
}

void apiStatic_sodium_verify_2(WrenVM* vm) {
    if (sodium_available) {
        char hashtext[crypto_pwhash_STRBYTES];
        strcpy(hashtext, wrenGetSlotString(vm, 1));
        int passwdlen;
        const char* passwd = wrenGetSlotBytes(vm, 2, &passwdlen);
        int result = crypto_pwhash_str_verify(hashtext, passwd, passwdlen);
        wrenSetSlotBool(vm, 0, result == 0);
    } else {
        abortNoSodium(vm);
    }
}

void apiStatic_sodium_needsRehash_3(WrenVM* vm) {
    if (sodium_available) {
        char hashtext[crypto_pwhash_STRBYTES];
        strcpy(hashtext, wrenGetSlotString(vm, 1));
        unsigned long long opslimit = (unsigned long long)wrenGetSlotDouble(vm, 2);
        size_t memlimit = (size_t)wrenGetSlotDouble(vm, 3);
        int result = crypto_pwhash_str_needs_rehash(hashtext, opslimit, memlimit);
        wrenSetSlotBool(vm, 0, result == 0);
    } else {
        abortNoSodium(vm);
    }
}

void ggExt_init(void) {
    if (sodium_init() != -1) sodium_available = true;

    ggRegisterMethod("PasswordHash", "static hash(_,_,_)", &apiStatic_sodium_hash_3);
    ggRegisterMethod("PasswordHash", "static verify(_,_)", &apiStatic_sodium_verify_2);
    ggRegisterMethod("PasswordHash", "static needsRehash(_,_,_)", &apiStatic_sodium_needsRehash_3);
}
