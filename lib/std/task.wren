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

import "std.assert" for Assert
import "std.io.poll" for Poll
import "std.named_singleton" for NamedSingleton
import "std.structures" for Deque
import "std.time" for Time
import "gg" for GG

class TaskExitSignal { 
    construct new(reason) {
        _reason = reason 
    }
    reason { _reason }
}

class Listener {
    construct new() {
        _fd = null
        _events = null
    }

    events { _events }
    events=(value) { _events = value }
    fd { _fd }
    fd=(value) { _fd = value }
}

class Task {
    construct new(queue) {
        _rendezvous = 0
        _name = null
        _fiber = Fiber.new{ this.run( ) }
        _exited = false

        _queue = queue
        _entry = _queue.add(this)
    }

    name { _name || this.type.name }
    name=(value) { _name = value }
    fiber { _fiber }
    queue { _queue }
    toString { _name }

    logError(msg) { System.print("[error in %(name)] %(msg)") }
    logExit(reason) {
        if (reason) System.print("[%(name) exited early] %(reason)")
    }

    wake() {
        _entry.wake()
    }
    sleep(dt) {
        _entry.active = false
        _entry.wakeAt = _queue.now + dt
        Fiber.yield()
    }
    sleep {
        _entry.active = false
        Fiber.yield()
    }
    yield {
        Fiber.yield()
    }
    sleepFD(fd, events) {
        _listener = _listener || Listener.new()
        _listener.fd = fd
        _listener.events = events
        _entry.active = false
        _entry.listeners.clear()
        _entry.listeners.add(_listener)
        Fiber.yield()
    }
    sleepFD(fd, events, timeout) {
        _listener = _listener || Listener.new()
        _listener.fd = fd
        _listener.events = events
        _entry.active = false
        _entry.listeners.clear()
        _entry.listeners.add(_listener)
        _entry.wakeAt = _queue.now + timeout
        Fiber.yield()
    }

    exit(reason) { Fiber.yield(TaskExitSignal.new(reason)) }
    static exit(reason) { Fiber.yield(TaskExitSignal.new(reason)) }

    isDone { fiber.isDone || _exited }

    resume() {
        assert (!fiber.isDone)
        assert (!_exited)
        var r = fiber.try()
        if (r is Num) {
            _entry.wakeTime = r
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

class TaskEntry {
    construct new(task) {
        _id = Object.address(task)
        _task = task
        _active = true
        _wakeAt = null
        _listeners = []
    }

    wake() {
        _active = true
        _wakeAt = null
        _listeners.clear()
    }

    active { _active }
    active=(value) { _active=value }

    wakeAt { _wakeAt }
    wakeAt=(value) { _wakeAt=value }

    listeners { _listeners }
    task { _task }

    id { _id }
}

class TaskQueue {
    construct new() {
        _tasks = Deque.new()
        _running = null

        _wakeAfterSleep = []

        _poll = null

        _pollFDs = []
        _pollEvents = []
        _pollEntries = []
    }

    add(task) { 
        var entry = TaskEntry.new(task)
        _tasks.addFront(entry)
        return entry
    }

    count { _tasks.count + (_running ? 1 : 0) }

    now { Time.now }

    flush() {
        while (count > 0) update()
    }

    update() {
        var now = this.now
        var nextWake = null
        var anyActiveNow = false
        _wakeAfterSleep.clear()
        for (i in 0..._tasks.count) {
            _running = _tasks.popBack()
            if (_running.wakeAt) {
                if (_running.wakeAt <= now) {
                    _running.wake()
                } else if (!nextWake || (nextWake > _running.wakeAt)) {
                    _wakeAfterSleep.clear()
                    nextWake = _running.wakeAt
                    _wakeAfterSleep.add(_running)
                } else if (nextWake == _running.wakeAt) {
                    _wakeAfterSleep.add(_running)
                }
            }
            for (listener in _running.listeners) {
                _pollFDs.add(listener.fd)
                _pollEvents.add(listener.events)
                _pollEntries.add(_running)
            }
            if (_running.active) anyActiveNow = true
            _tasks.addFront(_running)
            _running = null
        }

        var timeout
        if (anyActiveNow) {
            timeout = 0
            _wakeAfterSleep.clear()
        } else if (nextWake) {
            timeout = nextWake - now
        } else {
            timeout = -1
        }

        if (_pollFDs.count > 0) {
            if (!_poll) _poll = Poll.new()
            var result = _poll.poll(_pollFDs, _pollEvents, timeout)
            for (i in 0..._pollEvents.count) {
                if (_pollEvents[i] > 0) {
                    _pollEntries[i].wake()
                }
            }
            if (result == 0) {
                for (entry in _wakeAfterSleep) entry.wake()
            }
            _pollFDs.clear()
            _pollEvents.clear()
            _pollEntries.clear()
        } else {
            if (timeout > 0) {
                Time.sleep(timeout)
                for (entry in _wakeAfterSleep) entry.wake()
            } else if (timeout == 0) {
                /* do nothing */
            } else {
                Fiber.abort("All tasks are sleeping. Please send a handsome prince.")
            }
        }
        _wakeAfterSleep.clear()

        for (i in 0..._tasks.count) {
            _running = _tasks.popBack()
            if (_running.active) {
                var done = _running.task.resume()
                if (done) {
                    var f = Fiber.new{ _running.task.finish() }
                    f.try()
                    if (f.error) {
                        _running.task.logError(GG.error.trim())
                    }
                } else {
                    _tasks.addFront(_running)
                }
            } else {
                _tasks.addFront(_running)
            }
            _running = null
        }
    }
}
Assert.mixin(TaskQueue)
