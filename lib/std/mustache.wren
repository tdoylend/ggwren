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

// Logic-less templates.
// https://mustache.github.io/

import "meta" for Meta
import "std.buffer" for Buffer

var ValidSigils = "!#&*^/>="

class Tag {
    construct new(sigils, name, clearanceBefore, clearanceAfter) {
        _sigils = sigils
        _name = name
        _clearanceBeforeRaw = clearanceBefore
        _clearanceAfterRaw = clearanceAfter
        _emitBefore = ""
        _emitAfter = ""
        _content = null
        _closingTag = null
    }

    clearanceBeforeRaw { _clearanceBeforeRaw }
    clearanceAfterRaw { _clearanceAfterRaw }

    name { _name}
    sigils { _sigils }
    content { _content }

    isUnclosedBlock {
        if (_content) return false
        if (_sigils.contains("#")) return true
        if (_sigils.contains("^")) return true
        return false
    }

    canStandalone { 
        if (_sigils.contains("#")) return true
        if (_sigils.contains("^")) return true
        if (_sigils.contains("!")) return true
        if (_sigils.contains("=")) return true
        if (_sigils.contains(">")) return true
        return false
    }

    compile() {
        if ( canStandalone ) {
            if (_content) {
                if (_clearanceBeforeRaw && !_clearanceAfterRaw) _emitBefore = _clearanceBeforeRaw
                if (!_clearanceBeforeRaw && _clearanceAfterRaw) {
                    _content.insert(0, _clearanceAfterRaw)
                }
                if (_closingTag.clearanceBeforeRaw && !_closingTag.clearanceAfterRaw) {
                    _content.insert(-1, _closingTag.clearanceBeforeRaw)
                }
                if (!_closingTag.clearanceBeforeRaw && _closingTag.clearanceAfterRaw) {
                    _emitAfter = _closingTag.clearanceAfterRaw
                }
            } else {
                if (_clearanceBeforeRaw && !_clearanceAfterRaw) _emitBefore = _clearanceBeforeRaw
                if (!_clearanceBeforeRaw && _clearanceAfterRaw) _emitAfter = _clearanceAfterRaw
            }
        } else {
            if (_content) {
                _content.insert(0, _clearanceAfterRaw || "")
                _content.insert(-1, _closingTag.clearanceBeforeRaw || "")
                _emitBefore = _clearanceBeforeRaw || ""
                _emitAfter = _closingTag.clearanceAfterRaw || ""
            } else {
                _emitBefore = _clearanceBeforeRaw || ""
                _emitAfter  = _clearanceAfterRaw || ""
            }
        }
        if (_content) {
            for (elem in _content) {
                if (elem is Tag) elem.compile()
            }
        }
    }

    close(closingTag, content) {
        _closingTag = closingTag
        _content = content
    }

    isFalsey(value) {
        if (value == null) return true
        if (value == "") return true
        if ((value is List) && (value.count == 0)) return true
        if ((value is Map) && (value.count == 0)) return true
        if (value == false) return true
        return false
    }

    escape(string) { string.replace("&","&amp;").replace("\"","&quot;").
        replace("<","&lt;").replace(">","&gt;") }

    executeContent(ctx) {
        if (_content) {
            for (elem in _content) {
                if (elem is Tag) {
                    elem.execute(ctx)
                } else {
                    ctx.write(elem)
                }
            }
        }
    }

    execute(ctx) {
        ctx.write(_emitBefore)
        var raw = sigils.contains("&")
        if (sigils.contains("#")) {
            var value = ctx.find(_name)
            if (!isFalsey(value)) {
                if (value is List) {
                    for (elem in value) {
                        ctx.push(elem)
                        executeContent(ctx)
                        ctx.pop()
                    }
                } else {
                    ctx.push(value)
                    executeContent(ctx)
                    ctx.pop()
                }
            }
        } else if (sigils.contains("!") || sigils.contains("=")) {
            /* do nothing */
        } else if (sigils.contains(">")) {
            var partial = ctx.partials[name]
            if (partial) {
                var indent = (_clearanceBeforeRaw && _clearanceAfterRaw) ? _clearanceBeforeRaw : ""
                var held = ""
                if (partial[-1] == "\n") {
                    held = "\n"
                    partial = partial[0...partial.bytes.count-1]
                }
                partial = indent + partial.replace("\n", "\n"+indent)
                partial = partial + held
                Mustache.render_(partial, ctx)
            }
        } else if (sigils.contains("^")) {
            var value = ctx.find(name)
            if (isFalsey(value)) {
                ctx.push(value)
                executeContent(ctx)
                ctx.pop()
            } else {
                /* do nothing */
            }
        } else {
            var value = ctx.find(_name)
            if (!isFalsey(value)) {
                value = value.toString
                ctx.write(raw ? value : escape(value))
            }
        }
        ctx.write(_emitAfter)
    }

    toString { "Tag(%(_sigils),%(_name),%(_clearanceBefore),%(_clearanceAfter))" }
}

class Ctx {
    construct new(stack, partials) {
        _stack = stack
        _stream = Buffer.new()
        _partials = partials
    }

    find(name) {
        var result = null
        if (name == ".") {
            result = _stack[-1]
        } else {
            var parts = name.split(".")
            var first = parts[0]
            var rest = parts[1...parts.count]
            for (i in (_stack.count - 1)...-1) {
                if (_stack[i] is Map) {
                    if (_stack[i].containsKey(first)) {
                        result = _stack[i][first]
                        break
                    }
                }
            }
            for (part in rest) {
                if (result is Map) {
                    result = result[part]
                } else {
                    result = null
                    break
                }
            }
        }
        return result
    }

    push(element) {
        _stack.add(element)
    }

    pop() {
        _stack.removeAt(-1)
    }

    write(text) { _stream.write(text) }
    read() { _stream.read() }

    stream { _stream }
    partials { _partials }
}

var WideDelimiters = "{="
var MatchingWide = {"{":"}","=":"="}
var NonNLWhitespaceBytes = [9, 13, 32]

class Mustache {
    static render(template, data) { render(
        template,
        data,
        {}
    ) }
    
    static render(template, data, partials) {
        var ctx = Ctx.new([data], partials)
        render_(template, ctx)
        return ctx.read()
    }

    static render_(template, ctx) {
        var openDelimiter = "{{"
        var closeDelimiter = "}}"
        var segments = []
        var index = 0
        var name = Buffer.new()
        var sigils = Buffer.new()

        while (index < template.bytes.count) {
            var openStartIndex = template.indexOf(openDelimiter, index)
            openStartIndex = openStartIndex > -1 ? openStartIndex : null
            var openEndIndex = openStartIndex && openStartIndex + openDelimiter.bytes.count
            var closeStartIndex = null
            var closeEndIndex = null

            var closeDelimiterHere = closeDelimiter
            name.clear()
            sigils.clear()

            if (openEndIndex && (openEndIndex < template.bytes.count)) {
                if (template[openEndIndex] == "=") {
                    openEndIndex = openEndIndex + 1
                    sigils.write("=")
                    closeDelimiterHere = "=" + closeDelimiter
                } else if (template[openEndIndex] == "{") {
                    openEndIndex = openEndIndex + 1
                    sigils.write("&")
                    closeDelimiterHere = "}" + closeDelimiterHere
                }
            }

            if (openStartIndex) {
                closeStartIndex = template.indexOf(closeDelimiterHere, openEndIndex)
                closeStartIndex = closeStartIndex > 0 ? closeStartIndex : null
                closeEndIndex = closeStartIndex + closeDelimiterHere.bytes.count
            }

            if (openStartIndex && closeStartIndex) {
                var tagRawName = template[openEndIndex...closeStartIndex]

                var beforeClearanceStart = 0
                for (beforeIndex in (openStartIndex - 1)...-1) {
                    var byte = template.bytes[beforeIndex]
                    if (byte == 10) {
                        beforeClearanceStart = beforeIndex + 1
                        break
                    } else if ((byte == 13) || (byte == 9) || (byte == 32)) {
                        /* do nothing */
                    } else {
                        beforeClearanceStart = null
                        break
                    }
                }

                var afterClearanceEnd = template.bytes.count
                for (afterIndex in closeEndIndex...template.bytes.count) {
                    var byte = template.bytes[afterIndex]
                    if (byte == 10) {
                        afterClearanceEnd = afterIndex + 1
                        break
                    } else if ((byte == 13) || (byte == 9) || (byte == 32)) {
                        /* do nothing */
                    } else {
                        afterClearanceEnd = null
                        break
                    }
                }
                var chunk = template[index...(beforeClearanceStart || openStartIndex)]
                segments.add(chunk)
                for (char in tagRawName) {
                    if (" \t\n\r".contains(char)) {
                        /* do nothing */
                    } else if (ValidSigils.contains(char)) {
                        sigils.write(char)
                    } else {
                        name.write(char)
                    }
                }
                var clearanceBefore = beforeClearanceStart && 
                        template[beforeClearanceStart...openStartIndex]
                var clearanceAfter = afterClearanceEnd &&
                        template[closeEndIndex...afterClearanceEnd]
                var tag = Tag.new(sigils.read(), name.read(), clearanceBefore, clearanceAfter)

                if (tag.sigils.contains("=")) {
                    var parts = tagRawName.trim().split(" ")
                    openDelimiter = parts[0].trim()
                    closeDelimiter = parts.count >= 2 ? parts[1].trim() : "}}"
                } 
                if (tag.sigils.contains("/")) {
                    var contentReversed = []
                    var content = []
                    while (segments.count > 0) {
                        if ((segments[-1] is Tag) && (segments[-1].name == tag.name) &&
                                (segments[-1].isUnclosedBlock)) {
                            break
                        }
                        contentReversed.add(segments.removeAt(-1))
                    }
                    if (segments.count > 0) {
                        while (contentReversed.count > 0) content.add(contentReversed.removeAt(-1))
                        segments[-1].close(tag, content)
                    } else {
                        while (contentReversed.count > 0) segments.add(contentReversed.removeAt(-1))
                    }
                } else {
                    segments.add(tag)
                }
                index = afterClearanceEnd || closeEndIndex
            } else {
                var chunk = template[index...template.bytes.count]
                segments.add(chunk)
                index = index + chunk.bytes.count
            }
        }
        /*
        for (segment in segments) {
            if (segment is String) {
                System.print("STRING: <<<%(segment)>>>")
            } else {
                System.print("%(segment.toString)")
            }
        }
        */
        for (segment in segments) {
            if (segment is Tag) {
                segment.compile()
            }
        }
        for (element in segments) {
            if (element is Tag) {
                element.execute(ctx)
            } else {
                ctx.write(element)
            }
        }
    }
}

