import "lib/structures" for Deque
import "random" for Random
import "test" for Test

var random = Random.new(23018539502123)

for (i in 1..10) {
    Test.require("deque_pushes_and_pops_%(i)") {
        var deque = Deque.new()

        var inCounter = 1
        var outCounter = 0

        for (i in 0...10000) {
            for (push in 0...random.int(1, 21)) {
                deque.addFront(inCounter)
                inCounter = inCounter + 1
            }
            for (pop in 0...random.int(1, random.int(1, 21).min(deque.count))) {
                var elem = deque.popBack()
                if (elem <= outCounter) Fiber.abort("Invariant violated!")
                outCounter = elem
            }
        }
        return true
    }
}
