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

import "lib/buffer" for Buffer

class StringUtil {
    // Check is a string is valid UTF-8.
    static isValidUTF8(text) {
        return text.codePoints.all{|c| c >= 0}
    }

    // Left-justify `text` to `width`, using `fill` to fill in the extra space.
    static left(text, width, fill) {
        var textWidth = text.count
        var result = text
        if (text.count < width) {
            var spaceRemaining = width - textWidth

            result = text + fill * (spaceRemaining / fill.count).floor
            result = result + fill[0...(spaceRemaining % fill.count)]
        }
        return result
    }

    // Right-justify `text` to `width`, using `fill` to fill in the extra space.
    static right(text, width, fill) {
        var textWidth = text.count
        var result = text
        if (text.count < width) {
            var spaceRemaining = width - textWidth
            result = fill * (spaceRemaining / fill.count).floor
            result = result + fill[0...(spaceRemaining % fill.count)] + text
        }
        return result
    }

    // Center `text` in `width`, using `fill` to fill in the extra space.
    static center(text, width, fill) {
        var textWidth = text.count
        var result = text
        if (text.count < width) {
            var leftSpace = ((width - textWidth) / 2).floor
            var rightSpace = (width - textWidth) - leftSpace
            result = fill*(leftSpace / fill.count).floor + fill[0...(leftSpace % fill.count)]
            result = result + text
            result = result + fill*(rightSpace / fill.count).floor
            result = result + fill[0...(rightSpace % fill.count)]
        }
        return result
    }

    static left(text, width) { left(text, width, " ") }
    static center(text, width) { center(text, width, " ") }
    static right(text, width) { right(text, width, " ") }

    // Convert an ASCII string to uppercase.
    static asciiUpper(text) {
        var result = Buffer.new()
        for (byte in text.bytes) {
            if ((byte >= 97) && (byte <= 122)) byte = byte - 32
            result.writeByte(byte)
        }
        return result.toString
    }

    // Convert an ASCII string to lowercase.
    static asciiLower(text) {
        var result = Buffer.new()
        for (byte in text.bytes) {
            if ((byte >= 65) && (byte <= 90)) byte = byte + 32
            result.writeByte(byte)
        }
        return result.toString
    }

    static asciiTitle(text) {
        var result = Buffer.new()
        var upper = true
        for (char in text) {
            if (upper) {
                result.write(asciiUpper(char))
            } else {
                result.write(char)
            }
            if (isAlpha(char) || (char == "'")) {
                upper = false
            } else {
                upper = true
            }
        }
        return result.read()
    }

    static asciiCapitalize(text) {
        var result = Buffer.new()
        var upper = true
        for (char in text) {
            if (upper) {
                result.write(asciiUpper(char))
            } else {
                result.write(char)
            }
            if (upper) {
                if (isAlpha(char)) {
                    upper = false
                }
            }
        }
        return result.read()
    }

    static isAlpha(text) {
        return (text != "") && text.bytes.all{ |byte| ((byte >= 65) && (byte <= 90)) || 
                ((byte >= 97) && (byte <= 122)) }
    }

    // Functionally identical to Sequence.join(..), but faster for large output due to 
    // using a Buffer to avoid having to perform so many copies.
    static join(iterable, joiner) {
        var result = Buffer.new()
        var first = true
        for (element in iterable) {
            if (!first) result.write(joiner.toString)
            first = false
            result.write(element.toString)
        }
        return result.read()
    }
}

var BytewiseLexicalOrdering = Fn.new{|a, b|
    var index = 0
    a = a.bytes
    b = b.bytes
    while (true) {
        if (a.count == index) {
            return false
        } else if (b.count == index) {
            return true
        } else {
            if (a[index] > b[index]) {
                return false
            } else if (a[index] < b[index]) {
                return true
            } else {
                index = index + 1
            }
        }
    }
}
