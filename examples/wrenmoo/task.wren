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

import "log" for Log
import "config" for Config

class Task {
    construct start() {
        if (Object.same(this.type, Task)) {
            Fiber.abort("Cannot instantiate Task directly.")
        }

        _id = (__idCounter || 0) + 1
        __idCounter = _id
        
        Task.queue.add(this)

        _name = "unnamed task (%(_id))"
        _fiber = Fiber.new{ this.run() }
        _isBusy = false
        _isDone = false
    }

    cleanUp() {}

    name { _name }
    name=(value) { _name=(value) }
    fiber { _fiber }

    isBusy { _isBusy }
    isBusy=(value) { _isBusy = value }

    isDone { _isDone || _fiber.isDone }

    static queue { __queue = __queue || [] }

    finish() {
        _isDone = true
        Log.info("[%(name)] Task finished.")
        Fiber.yield()
    }

    resume() {
        if (Config.debugMode) {
            _fiber.call()
        } else {
            _fiber.try()
        }
    }

    run() {
        Fiber.abort("Cannot call run(..) on abstract Task; must call on a subclass.")
    }
}
