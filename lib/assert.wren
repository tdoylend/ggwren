import "meta" for Meta

class Assert {
    static enabled=(value) { __disabled = !value }

    static enabled { !__disabled }

    static mixin(target) { 
        Meta.extend(target, Assert.type, ["assert(_)"])
        Meta.extend(target.type, Assert.type, ["assert(_)"])
    }

    static assert(condition) {
        if (Assert.enabled) {
            if (!condition) {
                Fiber.abort("Assertion failed")
            }
        }
    }
}
