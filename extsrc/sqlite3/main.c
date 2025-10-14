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

#include <sqlite3.h>

void abortSqlite(WrenVM* vm, sqlite3* db) {
    const char* sqliteError = sqlite3_errmsg(db);
    char* buffer = malloc(128 + strlen(sqliteError));
    strcpy(buffer, "[SQLite3 error] ");
    strcat(buffer, sqliteError);
    wrenSetSlotString(vm, 0, buffer);
    wrenAbortFiber(vm, 0);
    free(buffer);
}

void apiAllocate_SQLite3(WrenVM* vm) {
    sqlite3** db_ptr = wrenSetSlotNewForeign(vm, 0, 0, sizeof(sqlite3*));
    *db_ptr = NULL;
    int result = sqlite3_open(wrenGetSlotString(vm, 1), db_ptr);
    if (result != SQLITE_OK) {
        abortSqlite(vm, *db_ptr);
    }
}

void apiFinalize_SQLite3(void* data) {
    sqlite3* db = *(sqlite3**)(data);
    (void)sqlite3_close_v2(db);
}

void api_SQLite3_executeScript_1(WrenVM* vm) {
    sqlite3* db = *(sqlite3**)wrenGetSlotForeign(vm, 0);
    const char* script = wrenGetSlotString(vm, 1);
    char* errorMessage;
    (void)sqlite3_exec(db, script, NULL, NULL, &errorMessage);
    
    if (errorMessage) {
        char* buffer = malloc(128 + strlen(errorMessage));
        strcpy(buffer, "[SQLite3 error] ");
        strcat(buffer, errorMessage);
        wrenSetSlotString(vm, 0, buffer);
        wrenAbortFiber(vm, 0);
        free(buffer);
        sqlite3_free(errorMessage);
    } else {
        wrenSetSlotNull(vm, 0);
    }
}

void api_SQLite3_close_0(WrenVM* vm) {
    sqlite3** db_ptr = (sqlite3**)wrenGetSlotForeign(vm, 0);
    if (*db_ptr) {
        (void)sqlite3_close_v2(*db_ptr);
        *db_ptr = NULL;
    } else {
        wrenSetSlotString(vm, 0, "The database has already been closed.");
        wrenAbortFiber(vm, 0);
    }
}

typedef struct Statement Statement;
struct Statement {
    sqlite3* db;
    sqlite3_stmt* stmt;
};

void apiAllocate_Statement(WrenVM* vm) {
    Statement* statement = wrenSetSlotNewForeign(vm, 0, 0, sizeof(Statement));    
    statement->db = *(sqlite3**)wrenGetSlotForeign(vm, 1);
    const char* query = wrenGetSlotString(vm, 2);
    int result = sqlite3_prepare_v2(statement->db, query, -1, &statement->stmt, NULL);
    if (result != SQLITE_OK) {
        abortSqlite(vm, statement->db);
    }
}

void apiFinalize_Statement(void* data) {
    Statement* statement = (Statement*)(data);
    sqlite3_finalize(statement->stmt);
}

bool validateUTF8(const uint8_t *bytes, int length) {
    int multibyte = 0;
    for (int i = 0; i < length; i ++) {
        uint8_t byte = bytes[i];
        if (multibyte) {
            if ((byte & 0xC0) != 0xC0) return false;
            multibyte --;
        } else {
            if (byte & 0x80) {
                if      ((byte & 0xE0) == 0xC0) multibyte = 1;
                else if ((byte & 0xF0) == 0xE0) multibyte = 2;
                else if ((byte & 0xF8) == 0xF0) multibyte = 3;
                else {
                    return false;
                }
            } else if (byte == 0) {
                return false;
            }
        }
    }
    return multibyte ? false : true;
}

void api_Statement_bind_2(WrenVM* vm) {
    Statement* statement = (Statement*)wrenGetSlotForeign(vm, 0);
    bool typeError = false;
    int index = (int)wrenGetSlotDouble(vm, 1);
    WrenType type = wrenGetSlotType(vm, 2);
    int result;
    if (type == WREN_TYPE_NUM) {
        result = sqlite3_bind_double(statement->stmt, index, wrenGetSlotDouble(vm, 2));
    } else if (type == WREN_TYPE_NULL) {
        result = sqlite3_bind_null(statement->stmt, index);
    } else if (type == WREN_TYPE_BOOL) {
        result = sqlite3_bind_int(statement->stmt, index, wrenGetSlotBool(vm, 2) ? 1 : 0);
    } else if (type == WREN_TYPE_STRING) {
        int length;
        const char *bytes = wrenGetSlotBytes(vm, 2, &length);
        if (validateUTF8(bytes, length)) {
            result = sqlite3_bind_text(statement->stmt, index, bytes, length, SQLITE_TRANSIENT);
        } else {
            result = sqlite3_bind_blob(statement->stmt, index, bytes, length, SQLITE_TRANSIENT);
        }
    } else {
        typeError = true;
    }
    if (typeError) {
        wrenSetSlotString(vm, 0,
                "The value is not a bindable type (must be String, Num, Bool, or Null).");
        wrenAbortFiber(vm, 0);
    } else if (result != SQLITE_OK) {
        abortSqlite(vm, statement->db);
    } else {
        wrenSetSlotNull(vm, 0);
    }
}

void api_Statement_step_0(WrenVM* vm) {
    Statement* statement = (Statement*)wrenGetSlotForeign(vm, 0);
    int result = sqlite3_step(statement->stmt);
    if (result == SQLITE_DONE) {
        wrenSetSlotBool(vm, 0, false);
    } else if (result == SQLITE_ROW) {
        wrenSetSlotBool(vm, 0, true);
    } else {
        abortSqlite(vm, statement->db);
    }
}

void api_Statement_column_1(WrenVM* vm) {
    Statement* statement = (Statement*)wrenGetSlotForeign(vm, 0);
    int index = (int)wrenGetSlotDouble(vm, 1);
    switch (sqlite3_column_type(statement->stmt, index)) {
        case SQLITE_INTEGER:
        case SQLITE_FLOAT:
        { 
            wrenSetSlotDouble(vm, 0, sqlite3_column_double(statement->stmt, index));
        } break;
        case SQLITE_TEXT:
        case SQLITE_BLOB:
        {
            wrenSetSlotBytes(
                    vm,
                    0,
                    sqlite3_column_blob(statement->stmt, index),
                    sqlite3_column_bytes(statement->stmt, index)
            );
        } break;
        case SQLITE_NULL:
        {
            wrenSetSlotNull(vm, 0);
        } break;
    }
}

void api_Statement_columnName_1(WrenVM* vm) {
    Statement* statement = (Statement*)wrenGetSlotForeign(vm, 0);
    int index = (int)wrenGetSlotDouble(vm, 1);
    wrenSetSlotString(vm, 0, sqlite3_column_name(statement->stmt, index));
}

void api_Statement_columnCount_getter(WrenVM* vm) {
    Statement* statement = (Statement*)wrenGetSlotForeign(vm, 0);
    wrenSetSlotDouble(vm, 0, (double)sqlite3_column_count(statement->stmt));
}

void api_Statement_reset_0(WrenVM* vm) {
    Statement* statement = (Statement*)wrenGetSlotForeign(vm, 0);
    int result = sqlite3_reset(statement->stmt);
    if (result != SQLITE_OK) {
        abortSqlite(vm, statement->db);
    }
}

void api_Statement_close_0(WrenVM* vm) {
    Statement* statement = (Statement*)wrenGetSlotForeign(vm, 0);
    int result = sqlite3_finalize(statement->stmt);
    statement->stmt = NULL;
    if (result != SQLITE_OK) {
        abortSqlite(vm, statement->db);
    }
}

void ggExt_init(void) {
    ggRegisterClass("SQLite3", &apiAllocate_SQLite3, apiFinalize_SQLite3);
    ggRegisterMethod("SQLite3", "executeScript(_)", &api_SQLite3_executeScript_1);
    ggRegisterMethod("SQLite3", "close()", &api_SQLite3_close_0);
    
    ggRegisterClass("Statement", &apiAllocate_Statement, &apiFinalize_Statement);
    ggRegisterMethod("Statement", "bind(_,_)", &api_Statement_bind_2);
    ggRegisterMethod("Statement", "step()", &api_Statement_step_0);
    ggRegisterMethod("Statement", "column(_)", &api_Statement_column_1);
    ggRegisterMethod("Statement", "columnName(_)", &api_Statement_columnName_1);
    ggRegisterMethod("Statement", "columnCount", &api_Statement_columnCount_getter);
    ggRegisterMethod("Statement", "reset()", &api_Statement_reset_0);
    ggRegisterMethod("Statement", "close()", &api_Statement_close_0);
}
