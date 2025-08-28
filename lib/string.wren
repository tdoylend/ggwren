import "lib:buffer" for ByteBuffer

class StringUtil {
    // Check is a string is valid UTF-8.
    static isValidUTF8(text) {
        return text.codePoints.all{|c| c >= 0}
    }

    // Convert an ASCII string to uppercase.
    static asciiUpper(text) {
        var result = ByteBuffer.new()
        for (byte in text.bytes) {
            if ((byte >= 97) && (byte <= 122)) byte = byte - 32
            result.addByte(byte)
        }
        return result.toString
    }

    // Convert an ASCII string to lowercase.
    static asciiLower(text) {
        var result = ByteBuffer.new()
        for (byte in text.bytes) {
            if ((byte >= 65) && (byte <= 90)) byte = byte + 32
            result.addByte(byte)
        }
        return result.toString
    }

    // Functionally identical to Sequence.join(..), but faster for large output due to 
    // using a Buffer to avoid having to perform so many copies.
    static join(iterable, joiner) {
        var result = ByteBuffer.new()
        var first = true
        for (element in iterable) {
            if (!first) result.write(joiner.toString)
            first = false
            result.push(element.toString)
        }
        return result.read()
    }
}
