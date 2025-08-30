import "gg" for GG
import "lib/io/stream" for Stream

GG.bind("builtins")

// A Buffer is essentially a modifiable string.
foreign class Buffer is Stream {
    // Create an empty buffer.
    construct new() {}

    // Create a buffer pre-filled with the contents of `text`.
    construct new(text) {
        write(text)
    }

    // Append to the buffer.
    foreign write(text)

    // Append a numeric value to the buffer as a byte.
    foreign writeByte(byte)

    // Return the contents of the buffer as a string.
    foreign read()

    // Equivalent to read().
    toString { read() }

    // Get the number of bytes stored in the buffer.
    foreign size

    // Clip the buffer down to `count` bytes.
    foreign truncate(size)

    // Clear the buffer. Equivalent to truncate(0).
    foreign clear()
}

GG.bind(null)
