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

import "lib/time" for Time

import "config" for Config
import "task" for Task
import "world" for World
import "log" for Log
import "tasks/listen" for ListenTask

class Game {
    static running { __running }
    static running=(value) { __running = value }

    static queue { Task.queue }

    static play() {
        World.open(Config.dbPath)
        ListenTask.start(Config.host, Config.port)
        running = true
        Log.info("Running.")
        while (running) {
            var start = Time.now
            for (task in queue) {
                task.resume()
            }
            for (i in 0...queue.count) {
                var task = queue.removeAt(0)
                if (task.isDone) {
                    task.cleanUp()
                } else {
                    queue.add(task)
                }
            }
            var end = Time.now
            var elapsed = end - start
            if (!queue.any{ |task| task.isBusy } && (elapsed < Config.idleFrameTime)) {
                Time.sleep(Config.idleFrameTime - elapsed)
            }
        }
    }
}
