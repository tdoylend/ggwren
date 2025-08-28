import "gg" for GG

GG.bind("gg_stdlib")

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
}

GG.bind(null)
