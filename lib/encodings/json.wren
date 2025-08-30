import "lib/buffer" for Buffer

var Hex = "0123456789abcdef"

class Stream {
    construct new(data) {
        _data = data
        _index = 0
        _line = 1
    }

    peek() {
        if (_index == _data.bytes.count) {
            return null
        } else {
            return _data[_index]
        }
    }
    
    next() {
        var c = peek()
        if (c != null) {
            _index = _index + c.bytes.count
        }
        if (c == "\n") _line = _line + 1
        return c
    }

    expect(expected) {
        var c = next()
        if (c != expected) {
            Fiber.abort(traceback + "Expected `%(expected)`, but found `%(c || "EOF")` instead.")
        }
    }

    match(char) {
        if (peek() == char) {
            next()
            return true
        } else {
            return false
        }
    }

    traceback {
        return "[JSON line %(_line)] "
    }
}

class JSON {
    static decode(string) {
        var stream = Stream.new(string)
        var result = decodeValue_(stream)
        if (stream.peek() != null) Fiber.abort(stream.traceback + "Trailing data after JSON value.")
        return result
    }

    static encode(data) {
        var buffer = Buffer.new()
        encodeValue_(data, buffer)
        return buffer.read()
    }
    
    static encodeInto(data, stream) {
        encodeValue_(data, stream)
    }

    static encodeValue_(data, stream) {
        if (data is Num) {
            if (data.isNan) {
                stream.write("null")
            } else if (data.isInfinity) {
                if (Num < 0) {
                    stream.write("-")
                }
                stream.write("1e9999")
            } else {
                stream.write(data.toString)
            }
        } else if (data is String) {
            stream.write("\"")
            for (char in data.codePoints) {
                if (char == -1) {
                    stream.write("?")
                } else if (char == 34) {
                    stream.write("\\\"")
                } else if (char == 92) {
                    stream.write("\\\\")
                } else if ((char < 32) || (char > 126)) {
                    if (char < 0xFFFF) {
                        stream.write("\\u")
                        stream.write(Hex[(char >> 12) & 0xF])
                        stream.write(Hex[(char >>  8) & 0xF])
                        stream.write(Hex[(char >>  4) & 0xF])
                        stream.write(Hex[ char        & 0xF])
                    } else {
                        stream.write(String.fromCodePoint(char))
                    }
                } else {
                    stream.writeByte(char)
                }
            }
            stream.write("\"")
        } else if (data is List) {
            stream.write("[")
            var first = true
            for (elem in data) {
                if (!first) stream.write(",")
                first = false
                encodeValue_(elem, stream)
            }
            stream.write("]")
        } else if (data is Map) {
            stream.write("{")
            var first = true
            for (entry in data) {
                if (!first) stream.write(",")
                first = false
                encodeValue_(entry.key.toString, stream)
                stream.write(":")
                encodeValue_(entry.value, stream)
            }
            stream.write("}")
        } else if (data is Bool) {
            if (data) {
                stream.write("true")
            } else {
                stream.write("false")
            }
        } else if (data == null) {
            stream.write("null")
        } else {
            stream.write(data.toJSON)
        }
    }

    static decodeWhitespace_(stream) {
        while (stream.peek() && " \r\n\t".contains(stream.peek())) stream.next()
    }

    static decodeHexDigit_(stream) {
        if (stream.peek() == null) {
            Fiber.abort(stream.traceback + "Expected hex digit.")
        } else if ("0123456789".contains(stream.peek())) {
            return stream.next().bytes[0] - 48
        } else if ("ABCDEF".contains(stream.peek())) {
            return stream.next().bytes[0] - 55
        } else if ("abcdef".contains(stream.peek())) {
            return stream.next().bytes[0] - 87
        } else {
            Fiber.abort(stream.traceback + "Invalid hex digit: `%(stream.peek())`.")
        }
    }

    static decodeEscapeSequence_(stream) {
        stream.expect("\\")
        if (stream.match("\"")) return "\""
        if (stream.match("\\")) return "\\"
        if (stream.match("/")) return "/"
        if (stream.match("b")) return "\b"
        if (stream.match("f")) return "\f"
        if (stream.match("n")) return "\n"
        if (stream.match("r")) return "\r"
        if (stream.match("t")) return "\t"
        if (stream.match("u")) {
            var codepoint = 0
            codepoint = codepoint * 16 + decodeHexDigit_(stream)
            codepoint = codepoint * 16 + decodeHexDigit_(stream)
            codepoint = codepoint * 16 + decodeHexDigit_(stream)
            codepoint = codepoint * 16 + decodeHexDigit_(stream)
            return String.fromCodePoint(codepoint)
        }
        Fiber.abort(stream.traceback + "Invalid escape sequence in JSON string.")
    }

    static decodeString_(stream) {
        stream.expect("\"")
        var buffer = Buffer.new()
        while (!stream.match("\"")) {
            if (stream.peek() == null) {
                Fiber.abort(stream.traceback + "This JSON string is not properly terminated.")
            } else if ((stream.peek() == "") || (stream.peek().codePoints[0] < 0)) {
                Fiber.abort(stream.traceback + "Invalid Unicode codepoint in JSON string.")
            } else if (stream.peek().codePoints[0] < 32) {
                Fiber.abort(stream.traceback + "Control characters (including newlines) are not "+
                        "allowed in JSON strings.")
            } else if (stream.peek() == "\\") {
                buffer.write(decodeEscapeSequence_(stream))
            } else {
                buffer.write(stream.next())
            }
        }
        return buffer.read()
    }

    static decodeNumber_(stream) {
        var buffer = Buffer.new()
        if (stream.match("-")) buffer.write("-")
        if (stream.match("0")) {
            buffer.write("0")
        } else {
            if (stream.peek() == null) {
                Fiber.abort(stream.traceback + "Expected a JSON number but found EOF instead.")
            } else if (!"123456789".contains(stream.peek())) {
                Fiber.abort(stream.traceback + "Non-numeric character in JSON number.")
            } else {
                buffer.write(stream.next())
                while (stream.peek() && ("0123456789".contains(stream.peek()))) {
                    buffer.write(stream.next())
                }
            }
        }
        if (stream.match(".")) {
            buffer.write(".")
            var foundDigit = false
            while (stream.peek() && ("0123456789".contains(stream.peek()))) {
                buffer.write(stream.next())
                foundDigit = true
            }
            if (!foundDigit) Fiber.abort(stream.traceback + "At least one digit is required after "+
                    "the decimal point.")
        }
        if (stream.match("e") || stream.match("E")) {
            buffer.write("e")
            if (stream.match("-")) {
                buffer.write("-")
            } else if (stream.match("+")) {
                buffer.write("+")
            }
            var foundDigit = false
            while (stream.peek() && ("0123456789".contains(stream.peek()))) {
                buffer.write(stream.next())
                foundDigit = true
            }
            if (!foundDigit) Fiber.abort(stream.traceback + "At least one digit is required after "+
                    "the exponent.")
        }
        var result
        if (Fiber.new{ result = Num.fromString(buffer.read()) }.try() is String) {
            Fiber.abort(stream.traceback + "Number out of range.")
        }
        return result
    }

    static decodeObject_(stream) {
        stream.expect("{")
        decodeWhitespace_(stream)
        var result = {}
        if (!stream.match("}")) {
            var parsing = true
            while (parsing) {
                decodeWhitespace_(stream)
                var key = decodeString_(stream)
                decodeWhitespace_(stream)
                stream.expect(":")
                var value = decodeValue_(stream)
                if (stream.match("}")) {
                    parsing = false
                } else {
                    stream.expect(",")
                }
            }
        }
        return result
    }

    static decodeArray_(stream) {
        stream.expect("[")
        decodeWhitespace_(stream)
        var result = []
        if (!stream.match("]")) {
            var parsing = true
            while (parsing) {
                result.add(decodeValue_(stream))
                if (stream.match("]")) {
                    parsing = false
                } else {
                    stream.expect(",")
                }
            }
        }
        return result
    }

    static decodeTrue_(stream) {
        stream.expect("t")
        stream.expect("r")
        stream.expect("u")
        stream.expect("e")
        return true
    }

    static decodeFalse_(stream) {
        stream.expect("f")
        stream.expect("a")
        stream.expect("l")
        stream.expect("s")
        stream.expect("e")
        return false
    }

    static decodeNull_(stream) {
        stream.expect("n")
        stream.expect("u")
        stream.expect("l")
        stream.expect("l")
    }

    static decodeValue_(stream) {
        var result
        decodeWhitespace_(stream)
        if (stream.peek() == null) {
            Fiber.abort(stream.traceback + "Expected a JSON value but found EOF instead.")
        } else if (stream.peek() == "\"") {
            result = decodeString_(stream)
        } else if ("-0123456789".contains(stream.peek())) {
            result = decodeNumber_(stream)
        } else if (stream.peek() == "{") {
            result = decodeObject_(stream)
        } else if (stream.peek() == "[") {
            result = decodeArray_(stream)
        } else if (stream.peek() == "t") {
            result = decodeTrue_(stream)
        } else if (stream.peek() == "f") {
            result = decodeFalse_(stream)
        } else if (stream.peek() == "n") {
            result = decodeNull_(stream)
        } else {
            Fiber.abort(stream.traceback + "Invalid character in JSON value: `%(stream.peek())`.")
        }
        decodeWhitespace_(stream)
        return result
    }
}
