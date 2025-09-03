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

import "lib/io/net" for TcpListener
import "lib/io/fs" for Fs
import "lib/sqlite3" for SQLite3
import "gg" for GG

var DbPath = Fs.join(GG.scriptDir, "main.db")
var DbInitScriptPath = Fs.join(GG.scriptDir, "init.sql")
var NeedToInitializeDb = false

if (!Fs.exists(DbPath)) NeedToInitializeDb = true

var Db = SQLite3.open(DbPath)

if (NeedToInitializeDb) {
    System.print("Initializing database... ")
    Db.executeScript(Fs.readEntireFile(DbInitScriptPath))
    System.print("Complete.")
}

// var Listener = TcpListener.bind("127.0.0.1", "9999")
// Listener.blocking = false

// while (true) {
//
//  }
