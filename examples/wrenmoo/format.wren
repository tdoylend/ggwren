import "lib/string" for StringUtil as S
import "lib/buffer" for Buffer

var Plurals = {
    "is": "are",
    "was": "were"
}

var ColorSequences = {
//          None   ANSI         True
     0x01: ["",    "\x1b[0m",   "\x1b[0m",                ], // Reset effects
     0x02: ["",    "\x1b[1m",   "\x1b[1m",                ], // Bold
     0x11: ["",    "\x1b[31m",  "\x1b[38;2;233;30;30m",   ], // Red
     0x12: ["",    "\x1b[31m",  "\x1b[38;2;255;166;166m", ], // Pink
     0x13: ["",    "\x1b[33m",  "\x1b[38;2;192;98;67m",   ], // Brown
     0x14: ["",    "\x1b[33m",  "\x1b[38;2;235;135;58m",  ], // Orange
     0x15: ["",    "\x1b[33m",  "\x1b[38;2;243;195;34m",  ], // Yellow
     0x16: ["",    "\x1b[32m",  "\x1b[38;2;140;228;32m",  ], // Lime
     0x17: ["",    "\x1b[32m",  "\x1b[38;2;66;183;63m",   ], // Green
     0x18: ["",    "\x1b[36m",  "\x1b[38;2;63;183;125m",  ], // Aquamarine
     0x19: ["",    "\x1b[36m",  "\x1b[38;2;0;218;215m",   ], // Cyan
     0x1A: ["",    "\x1b[34m",  "\x1b[38;2;116;178;204m", ], // Frosty blue
     0x1B: ["",    "\x1b[34m",  "\x1b[38;2;53;80;226m",   ], // Blue
     0x1C: ["",    "\x1b[35m",  "\x1b[38;2;124;73;237m",  ], // Indigo
     0x1D: ["",    "\x1b[35m",  "\x1b[38;2;154;64;198m",  ], // Purple
     0x1E: ["",    "\x1b[35m",  "\x1b[38;2;178;48;116m"   ], // Fuchsia
    "end of message": ["", "\x1b[m", "\x1b[m"]
}

class Fmt {
    static NO_COLOR { "no color" }
    static ANSI { "ANSI color" }
    static TRUE { "true color" }

    construct new() {
        _width = 71
        _colorMode = Fmt.ANSI
    }

    format(text) {
        var colorModeIndex
        if (_colorMode == Fmt.NO_COLOR) {
            colorModeIndex = 0
        } else if (_colorMode == Fmt.ANSI) {
            colorModeIndex = 1
        } else if (_colorMode == Fmt.TRUE) {
            colorModeIndex = 2
        } else {
            colorModeIndex = 0
        }

        var out = Buffer.new()
        var indent = 0
        var column = 0
        var breakIndex = null
        var breakColumn = null
        for (byte in text.bytes) {
            if (ColorSequences.containsKey(byte)) {
                out.write(ColorSequences[byte][colorModeIndex])
                byte = null
            } else if (byte == 32) {
                breakIndex = out.size + 1
                breakColumn = column + 1
            } else if (byte == 7) {
                indent = column
                byte = null
            } else if (byte == 13) {
                /* do nothing */
            } else if (byte == 10) {
                byte = null
            } else if ((byte < 32) || (byte > 126)) {
                byte = 63
            }

            if (byte) {
                out.writeByte(byte)
                column = column + 1
                if ((column > _width) && breakIndex) {
                    column = indent + column - breakColumn
                    var carryOver = out.toString[breakIndex...out.size]
                    out.truncate(breakIndex - 1)
                    out.write("\r\n")
                    out.write(" "*indent)
                    out.write(carryOver)
                    breakIndex = null
                    breakColumn = null
                }
            }
        }
        return out.toString + ColorSequences["end of message"][colorModeIndex] + "\r\n"
    }


    static pl(word, count) {
        if (count == 1) {
            return word
        } else {
            var lower = S.asciiLower(word)
            if (Plurals.contains(lower)) {
                var plural = Plurals[lower]
                if (S.asciiLower(word[0]) == word[0]) {
                    return plural
                } else {
                    return S.asciiUpper(plural[0]) + plural[1...plural.bytes.count]
                }
            } else if (word.endsWith("x") || word.endswith("s")) {
                return word + "es"
            } else {
                return word + "s"
            }
        }
        
    }
}
