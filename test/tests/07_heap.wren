import "lib/structures" for Heap
import "random" for Random
import "test" for Test

var random = Random.new(58412939850394)

for (i in 1..10) {
    Test.require("heap_pushes_and_pops_%(i)") {
        var heap = Heap.new()
        for (i in 0...10000) {
            heap.add(random.int(1,10000000))
            heap.add(random.int(1,10000000))
            heap.pop()
        }
        var min = 0
        while (heap.count > 0) {
            var elem = heap.pop()
            if (elem < min) Fiber.abort("Invariant violated!")
            min = elem
        }
        return true
    }
}
