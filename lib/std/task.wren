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
import "std.structures" for Deque
import "std.time" for Time

import "gg" for GG

class Entry {
    construct new(task) {
        _task = task
        _wakeTime = -Num.infinity
        _wakeFD = null
        _wakeFDEvents = null
        _wakeTask = null
        _isDone = false
    }
    isDone { _isDone = _isDone || _task.isDone }
    task { _task }
    active { _active }
    active=(v) { _active = v }
    wakeTime { _wakeTime }
    wakeTime=(v) { _wakeTime = v }
    wakeFD { _wakeFD }
    wakeFD=(v) { _wakeFD = v }
    wakeFDEvents { _wakeFDEvents }
    wakeFDEvents=(v) { _wakeFDEvents=(v) }
    wakeTask { _wakeTask }
    wakeTask=(v) { _wakeTake = v }
    wake() {
        _wakeTime = -Num.infinity
        _wakeFD = null
        _wakeFDEvents = null
        _wakeTask = null
    }
}

class Task {
    construct new(queue) {
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

    isDone { _fiber.isDone || _exited }

    logError(message) { System.print("[error in %(name)] %(message)") }

    wake() { _entry.wake() }

    sleep(dt) {
        _entry.wakeTime = _queue.now + dt
        Fiber.yield()
    }

    sleepUntil(time) {
        _entry.wakeTime = time
        Fiber.yield()
    }

    sleep {
        _entry.wakeTime = Num.infinity
        Fiber.yield()
    }

    sleepOnIO(stream, events) { sleepOnIO(stream, events, Num.infinity) }
    sleepOnIO(stream, events, timeout) {
        _entry.wakeFD = stream.fd
        _entry.wakeFDEvents = events
        _entry.wakeTime = _queue.now + timeout
        Fiber.yield()
    }

    sleepOnTask(task) { sleepOnTask(task, Num.infinity) }
    sleepOnTask(task, timeout) {
        _entry.wakeTask = task
        _entry.wakeTime = _queue.now + timeout
        _entry.active = false
        Fiber.yield()
    }

    yield {
        Fiber.yield()
    }

    exit {
        _exited = true
        Fiber.yield()
    }

    resume() {
        Assert.assert (!isDone)
        var result = fiber.try()
        if (fiber.error) logError(GG.error.trim())
        return result
    }

    finish() {
    }

    run() {
        Fiber.abort("This method is not implemented on Task; override it " +
                "in your subclass with your own implementation.")
    }
}

class TaskQueue is Sequence {
    construct new() {
        _entries = Deque.new()
        _toResume = []
        _poll = null
        _pollFDs = []
        _pollEvents = []
        _pollEntries = []
    }

    iterate(iterator) { _entries.iterate(iterator) }
    iteratorValue(iterator) { _entries.iteratorValue(iterator).task }
    count { _entries.count }

    add(task) {
        var entry = Entry.new(task)
        _entries.addFront(entry)
        return entry
    }

    now { Time.now }

    flush() {
        while (count > 0) update()
    }

    update() {
        var now = this.now
        var timeout = Num.infinity
        for (i in 0..._entries.count) {
            var entry = _entries.popBack()
            if (entry.isDone) continue
            var entrySleepTime
            if (entry.wakeTask && entry.wakeTask.isDone) {
                entrySleepTime = 0
            } else if (entry.wakeTime <= now) {
                entrySleepTime = 0
            } else {
                entrySleepTime = entry.wakeTime - now
            }
            if (entrySleepTime == timeout) {
                _toResume.add(entry)
            } else if (entrySleepTime < timeout) {
                timeout = entrySleepTime
                _toResume.clear()
                _toResume.add(entry)
            }
            if (entry.wakeFD) {
                _pollFDs.add(entry.wakeFD)
                _pollEvents.add(entry.wakeFDEvents)
                _pollEntries.add(entry)
            }
            _entries.addFront(entry)
        }
        // If, for example, we sleep for 500ms but get interrupted by a signal 250ms into the
        // sleep, we don't call anything in _toResumeIfSleepCompletes, because they're waiting
        // for 500ms.
        if (timeout == Num.infinity) timeout = -1

        if (_pollFDs.count > 0) {
            _poll = _poll || Poll.new()
            var result = _poll.poll(_pollFDs, _pollEvents, timeout)
            if (result > 0) {
                _toResume.clear()
                for (i in 0..._pollEvents.count) {
                    if (_pollEvents[i] > 0) {
                        var entry = _pollEntries[i]
                        _toResume.add(entry)
                    }
                }
            }
            _pollFDs.clear()
            _pollEvents.clear()
            _pollEntries.clear()
        } else {
            if (timeout > 0) {
                Time.sleep(timeout)
            } else if (timeout == 0) {
                /* do nothing */
            } else {
                Fiber.abort("All tasks are sleeping. Please send a handsome prince.")
            }
        }

        for (entry in _toResume) {
            entry.wake()
            entry.task.resume()
            if (entry.isDone) {
                var f = Fiber.new{ entry.task.finish() }
                f.try()
                if (f.error) entry.task.logError(GG.error.trim())
            }
        }
        _toResume.clear()
    }
}
