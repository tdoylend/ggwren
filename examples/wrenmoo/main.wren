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

// Comphrehensive flag list:
//
// z - Wizard
// w - World-writable
// r - World-readable
// x - World-executable
// p - player
// g - generic
// G - guest
// A - active

if (Fiber.new{ 
    import "gg"
}.try() is String) {
    System.print("This Wren program must be run within GGWren.")
    System.print()
    System.print("https://github.com/tdoylend/ggwren/")
    return
}

class Blank {}
if (Fiber.new{
    import "meta" for Meta
    Meta.extend(Blank, Blank, [])
}.try() is String) {
    System.print("This Wren program requires the tdoylend fork of Wren.")
    System.print()
    System.print("https://github.com/tdoylend/wren/")
}

import "lib/util_mixins" /* VERY MAGIC */

import "log" for Log
import "game" for Game
import "config" for Config

Log.announce("WrenMOO v%(Config.version)")

Game.play()
