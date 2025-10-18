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

import "gg" for GG

GG.bind("builtins")

class Platform {
    foreign static name
    foreign static arch
    foreign static isPosix
    foreign static isWindows
}

class IndexIterator is Sequence {
    construct new(fn) {
        _fn = fn
    }

    iterate(iterator) {
        if (iterator) {
            iterator = iterator + 1
        } else {
            iterator = 0
        }
        if (_fn.call(iterator)) {
            return iterator
        } else {
            return false
        }
    }

    iteratorValue(iterator) { _fn.call(iterator) }
}

class EnvironEntry {
    construct new(key, value) {
        _key = key
        _value = value
    }

    key { _key }
    value { _value } 
}

class Environ is Sequence {
    // Get or set an environment variable. Changing it here changes the environment.
    construct init() { }

    foreign [key]
    foreign [key]=(value)

    foreign keyAt_(index)
    foreign valueAt_(index)

    count {
        var index = 0
        while (keyAt_(index)) index = index + 1
        return index
    }

    containsKey(key) { this[name] != null }

    keys { IndexIterator.new{|index| keyAt_(index) } }
    values { IndexIterator.new{|index| valueAt_(index) } }
    
    iterate(iterator) { 
        if (iterator) {
            iterator = iterator + 1
        } else {
            iterator = 0
        }
        if (keyAt_(iterator)) {
            return iterator
        } else {
            return false
        }
    }

    iteratorValue(iterator) {
        return EnvironEntry.new(keyAt_(iterator), valueAt_(iterator))
    }
}
Environ = Environ.init()

class Process {
    // The command-line arguments with which the process was called.
    foreign static arguments
    foreign static system(command)
    foreign static exit(code)
    static exit() { exit(0) }
}

GG.bind(null)
