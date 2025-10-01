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

class Deque is Sequence {
    construct new() {
        _contents = [null, null, null, null]
        _head = 0
        _tail = 0
        _count = 0
        _capacity = 4
    }

    construct new(sequence) {
        addAll(sequence)
    }

    iterate(iterator) {
        if (iterator == null) {
            iterator = 0
        } else {
            iterator = iterator + 1
        }
        if (iterator == _count) {
            return false
        } else {
            return iterator
        }
    }

    iteratorValue(iterator) {
        return _contents[(_tail + iterator) % _capacity]
    }

    foreign static fastCopy_(list, dest, src, count)

    addAll(sequence) {
        for (elem in sequence) {
            addFront(elem)
        }
    }

    clear() {
        _count = 0
    }

    ensure_() {
        if (_count == _capacity) {
            _capacity = _capacity * 2
            while (_contents.count < _capacity) _contents.add(null)
            Deque.fastCopy_(_contents, _tail + _count, _tail, _count - _tail) 
            _tail = _tail + _count
        }
    }

    addFront(elem) {
        ensure_()
        _contents[_head] = elem
        _head = (_head + 1) % _capacity
        _count = _count + 1
    }
    addBack(elem) {
        ensure_()
        _contents[_tail] = elem
        _tail = (_tail + _capacity - 1) % _capacity
        _count = _count + 1
    }

    popFront() {
        if (_count > 0) {
            _count = _count - 1
            _head = (_head + _capacity - 1) % _capacity
            return _contents[_head]
        } else {
            Fiber.abort("Cannot pop from empty Deque.")
        }
    }

    popBack() {
        if (_count > 0) {
            _count = _count - 1
            var value = _contents[_tail]
            _tail = (_tail + 1) % _capacity
            return value
        } else {
            Fiber.abort("Cannot pop from empty Deque.")
        }
    }

    count { _count }
}

class Heap is Sequence {
    construct new(key) {
        _key = key
        _heap = []
    }

    construct new() {
        _key = Fn.new{|a, b| a <= b}
        _heap = []
    }

    top {
        if (_heap.count == 0) Fiber.abort("Cannot view top of empty Heap.")
        return _heap[0]
    }

    pop() {
        if (_heap.count == 0) Fiber.abort("Cannot pop from empty Heap.")
        _heap.swap(0, -1)
        var result = _heap.removeAt(-1)
        var parent = 0
        var bubbling = true
        while (bubbling) {
            var childLeft = parent*2 + 1
            var childRight = parent*2 + 2
            if (childLeft >= _heap.count) {
                bubbling = false
            } else if (childRight >= _heap.count) {
                if (!_key.call(_heap[parent], _heap[childLeft])) {
                    _heap.swap(parent, childLeft)
                }
                bubbling = false
            } else {
                var minChild = _key.call(_heap[childLeft], _heap[childRight]) ?
                        childLeft : childRight
                if (_key.call(_heap[parent], _heap[minChild])) {
                    bubbling = false
                } else {
                    _heap.swap(parent, minChild)
                    parent = minChild
                }
            }
        }
        return result
    }

    add(elem) {
        var child = _heap.count
        _heap.add(elem)
        while (child > 0) {
            var parent = ((child - 1)/2).floor
            if (_key.call(_heap[parent], _heap[child])) {
                // All's right with the world.
                break
            } else {
                _heap.swap(parent, child)
                child = parent
            }
        }
    }

    addAll(sequence) {
        if ((sequence.count * 4) > _heap.count) {
            _heap.addAll(sequence)
            _heap.sort()
        }
    }

    count { _heap.count }
}

GG.bind(null)
