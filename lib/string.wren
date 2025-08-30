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

    static left(text, width) { left(text, width, " ") }

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
