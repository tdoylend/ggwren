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

import "lib/assert" for Assert
import "lib/named_singleton" for NamedSingleton
import "lib/structures" for Heap
import "lib/time" for Time
import "gg" for GG

class TaskExitSignal { 
    construct new(reason) {
        _reason = reason 
    }

    reason { _reason }
}

class Task {
    construct new(queue) {
        _rendezvous = 0
        _name = "(unnamed task)"
        _fiber = Fiber.new{ this.run( ) }
        _queue = queue
        _queue.add(this)
        _exited = false
    }

    name { _name }
    name=(value) { _name = value }
    fiber { _fiber }
    queue { _queue }
    toString { _name }
    rendezvous { _rendezvous }

    logError(msg) { System.print("[error in %(name)] %(msg)") }
    logExit(reason) { System.print("[%(name) exited early] %(reason)") }

    wake() {
        _rendezvous = 0
    }
    sleep(dt) {
        Fiber.yield(queue.now + dt)
    }
    sleep {
        Fiber.yield(Num.infinity)
    }
    yield { Fiber.yield() }
    exit(reason) { Fiber.yield(TaskExitSignal.new(reason)) }

    isDone { fiber.isDone || _exited }

    resume() {
        assert (!fiber.isDone)
        assert (!_exited)
        var r = fiber.try()
        if (r is Num) {
            _rendezvous = r
        } else if (r is TaskExitSignal) {
            _exited = true
            logExit(r.reason)
        }
        if (fiber.error) {
            logError(GG.error.trim())
        }
        return fiber.isDone || _exited
    }

    finish() {
        /* Override this method in your subclass to provide an endpoint to run after the main fiber
         * finishes. This is a good place to run cleanup code that closes files, frees textures,
         * etc. */
    }
    run() {
        Fiber.abort("This method is not implemented on Task; override it "+
                "in your subclass with your own implementation.")
    }
}
Assert.mixin(Task)

class TaskQueue is Heap {
    construct new() {
        super {|a, b| a.rendezvous <= b.rendezvous }
        _toKeep = []
        _now = Time.hpc / Time.hpcResolution
    }

    add(elem) {
        assert(elem is Task)
        super.add(elem)
    }

    now { _now }

    flush() {
        /* Run tasks until the queue is empty. */
        while (count > 0) {
            update()
            sleepUntilNext()
        }
    }

    update() {
        _now = Time.hpc / Time.hpcResolution
        while ((count > 0) && (top.rendezvous <= _now)) {
            var task = pop()
            var isDone = task.resume()
            if (isDone) {
                var f = Fiber.new{ task.finish() }
                f.try()
                if (f.error) {
                    task.logError(GG.error.trim())
                }
            } else {
                _toKeep.add(task)
            }
        }
        for (task in _toKeep) {
            add(task)
        }
        _toKeep.clear()
    }

    sleepUntilNext() {
        if (count > 0) {
            _now = Time.hpc / Time.hpcResolution
            if (top.rendezvous > _now) {
                Time.sleep(top.rendezvous - _now)
            }
        }
    }
}
Assert.mixin(TaskQueue)
