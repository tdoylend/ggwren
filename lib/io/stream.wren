// An abstract class for stream-like interfaces.
class Stream {
    read() {
        Fiber.abort("%(this.type.name)s are not readable.")
    }

    read(count) {
        Fiber.abort("%(this.type.name)s are not partially-readable.")
    }

    write() {
        Fiber.abort("%(this.type.name)s are not writable.")
    }

    seek() {
        Fiber.abort("%(this.type.name)s are not seekable.")
    }

    tell() {
        Fiber.abort("%(this.type.name)s do not support tell(..).")
    }

    size {
        Fiber.abort("%(this.type.name)s do not have a size.")
    }

    blocking { Fiber.abort("%(this.type.name)s do not support non-blocking operation.") }
    blocking=(value) { Fiber.abort("%(this.type.name)s do not support non-blocking operation.") }
}
