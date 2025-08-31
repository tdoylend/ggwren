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

import "lib/string" for StringUtil as S
import "lib/io/stream" for Stream
import "lib/buffer" for Buffer

import "gg" for GG

GG.bind("builtins")

foreign class File is Stream {
    construct open(path, mode) {}
    static open(path) { File.open(path, "r") }

    foreign size

    foreign read(bytes)

    read() {
        var buffer = Buffer.new()
        var reading = true
        while (reading) {
            var text = read(4096)
            if (text.bytes.count > 0) {
                buffer.write(text)
            } else {
                reading = false
            }
        }
        return buffer.read()
    }

    foreign seek(offset)
    foreign tell()

    foreign write(bytes)

    // foreign blocking
    // foreign blocking=(value)

    foreign close()
}

class Fs {
    // Provides functions for manipulating paths and the filesystem.
    //
    // Paths are a tricky subject. In the first place, their encoding varies depending on OS;
    // Windows uses ASCII or UTF-16 encodings (depending on if you use the *A or *W versions of
    // the winapi functions) with some additional rules about forbidden characters, while Linux
    // Just Doesn't Care (you can even have newlines in them *barf*). They also use different
    // path separator characters (but Windows still recognizes backslashes just in case). And the
    // existence of drive letters on Windows makes the concept of a "root directory" somewhat
    // ill-defined (but did you know "\" is a valid path on Windows? It points to C:).
    //
    // So, to bring some order to the mess, here are our rules:
    //
    // (1) We don't care about encodings. A path is a sequence of bytes with some separators
    //     in it.
    //
    // (2) On non-Windows operating systems, a "root path" is one which starts with a "/"
    //     character; on Windows, a root path is one which starts with either "/" or "\", or one
    //     which starts with a letter followed by a colon.
    //
    // (3) Path canonicalization: Windows does support symlinks but is case-sensitive. When
    //     canonicalizing paths, we (a) follow all symlinks, and (b) respect the case stored
    //     on disk; e.g. ("c:\program files" canonicalizes to "C:\Program Files").
    //
    // (4) Empty paths always count the same as ".".
    //
    // (5) Functions like dirname and basename strip trailing sepators 

    // Read the entire contents of a file as a string. Keep in mind that Wren's strings are
    // limited to 2GB!
    static readEntireFile(path) {
        var f = File.open(path)
        var data = f.read()
        f.close()
        return data
    }

    // Return the path separator character on this operating system; this is "\" on Windows
    // and "/" everywhere else.
    foreign static pathSep

    // Return the canonical path; which is the path such that if canonical(a) == canonical(b),
    // then a and b are the same file (even if a != b).
    //
    // If the path does not exist, returns null. Aborts if the path contains too many symlinks.
    //
    // canonical(..) is non-atomic and is consequently vulnerable to filesystem race conditions.
    foreign static canonical(path)

    // basename(..) and dirname(..) are complementary methods. The dirname of a path is everything
    // up to but not including the final path separator, whereas the basename is everything after
    // (but not including) the final path separator. Trailing separators are removed; i.e. "/a//"
    // becomes dirname="/", basename="a".
    //
    // If the path contains no separators, dirname(path) is "." and basename(path) is the path
    // itself. If the path is empty, both dirname(path) and basename(path) are ".".
    //
    // In general concatenating dirname(path)+"/"+basename(path) returns a valid path, although
    // not always the most efficient one.
    //
    // For root paths, both dirname(path) and basename(path) return the root path itself, EXCEPT
    // ON WINDOWS because this would break the rule about concatenation. We compromise thus: if
    // we are on Windows and the root path is a single separator, do as on non-Windows; otherwise,
    // dirname(path) is the root path, while basename(path) is "". This is horrible but less
    // horrible than the alternatives.
    //
    // Note that this definition of basename(..) and dirname(..) matches the POSIX definition
    // *but not* Python's behavior, which is broken.
    static basename(path) {
        // @todo
        Fiber.abort("Not yet implemented.")
    }

    static dirname(path) {
        // @todo
        Fiber.abort("Not yet implemented.")
    }

    // List the files in a directory. Subdirectories are presented WITHOUT trailing slashes.
    foreign static listDir(path)

    // Return the size of a file, in bytes.
    foreign static fileSize(path)

    // Return the path pointed to by a link.
    foreign static readLink(path)

    // Check whether the given path exists. For links, this checks whether the
    // link TARGET exists, not the link itself; use isLink to determine the latter question.
    foreign static exists(path)

    // Check whether path is a file (ie not a directory). Returns false if it does not exist.
    foreign static isFile(path)
    
    // Check whether path is a directory. Returns false if it does not exist.
    foreign static isDir(path)

    // Check whether the object pointed to by path is a link.
    foreign static isLink(path)

    // Return whether a given path is absolute or not. This is subject to several
    // Windows-specific caveats; see above.
    static isAbsolute(path) {
        if (path == "") {
            return false
        } else if (path[0] == "/") {
            return true
        } else {
            if (pathSep == "\\") {
                // We are on Windows. Activate the "special behavior".
                if (path[0] == "\\") {
                    return true
                } else if (path.count >= 2) {
                    if (S.isAlpha(path[0]) && (path[1] == ":")) {
                        return true
                    } else {
                        return false
                    }
                } else {
                    return false
                }
            } else {
                return false
            }
        }
    }

    // @todo
    // Remove trailing separators from a path. If the path ends in a separator, one separator
    // will be left and the remainder will be taken: e.g. "a/b/c///" -> "a/b/c/".
    static stripTrailingSeparators(path) {
        var index = path.bytes.count - 1
        var backslashByte = "/".bytes[0]
        var pathSepByte = pathSep.bytes[0]
        var running = true
        while (running && (index >= 0)) {
            if ((path.bytes[index] == backslashByte) || (path.bytes[index] == pathSepByte)) {
                index = index - 1
            } else {
                running = false
            }
        }
        return path[0..index]
    }
    
    // Join several path components with the OS separator. Components which are absolute paths
    // cause the previous components to be discarded: e.g., ["b", "/a", "c"] -> "/a/c".
    static join(components) { components.reduce{|a, b| join(a, b) } }

    // Same as above, but only joins two components.
    static join(a, b) {
        if (a.count == 0) return b
        if (b.count == 0) return a
        if (isAbsolute(b)) return b
        a = stripTrailingSeparators(a)
        var sep = ((a != "") && ((a[-1] == "/") || (a[-1] == pathSep))) ? "" : pathSep
        return a + sep + b
    }

    // Walk a path; this returns the path itself plus every subdirectory and file recursively.
    // The resulting WalkIterator is non-atomic and consequently vulnerable to race-conditions;
    // do not modify the file tree while the walk is in progress.
    static walk(path) {
        // @todo
        Fiber.abort("Not yet implemented.")
    }
}

GG.bind(null)
