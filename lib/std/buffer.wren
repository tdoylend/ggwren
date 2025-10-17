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

    // Clip the buffer down to `count` bytes. Returns the part removed, or null if the
    // buffer was shorter than `count` bytes (returns "" if they were equal.)
    foreign truncate(size)

    // Clear the buffer. Equivalent to truncate(0).
    foreign clear()
}

GG.bind(null)
