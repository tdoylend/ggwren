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

// SQLite3 bindings for GGWren.
//
// The SQLite3 class is the only one you should need to instantiate manually; the rest of
// the classes are created for you as necessary.
//
// The SQLite3.sql(..) function performs a query and returns a QueryResult. This supports
// all the usual Sequence operations, along with a .first method if you're only receiving
// one row of data. Data is returned in Row classes which are custom-defined per-query to
// have a getter for each column. These getters are the column names cast into Wren's
// dromedaryCase syntax; so for example:
//
//      SELECT first_name, last_name FROM Persons WHERE uid=?;
//
// -- will return instances of a Row class on which Row.firstName, Row.lastName are the
// defined getters.
//
// Columns whose name is not expressible as a Wren identifier -- e.g. "COUNT(*)" -- and
// columns whose name matches a previous column will not have distinct getters. You can either
// use AS to make sure you collect the right one, or you can use [..] to get columns by their
// original names (or indices).
//
// As always, you are advised to familiarize yourself with the SQLite documentation.
// https://sqlite.org/docs.html

import "lib/buffer" for Buffer
import "lib/string" for StringUtil as S
import "lib/util_mixins"
import "gg" for GG
import "meta" for Meta

var AlphaLower = "abcdefghijklmnopqrstuvwxyz"
var AlphaUpper = AlphaLower.upper
var Alpha = AlphaLower + AlphaUpper
var IdentStart = AlphaLower
var IdentAny = Alpha + "0123456789_"

GG.bind("sqlite3")

var StatementRowObjects = {}

class StatementResult is Sequence {
    construct new(text, statement) {
        _statement = statement
        _text = text
        _row = null
        if (_statement.columnCount > 1) {
            _row = StatementRowObjects[_text] || initRowFromStatement_()
        }
        _stepCount = 0
        _finished = false
        _current = null

        step()
        _first = _current
    }

    first { _first }
    current { _current }
    close() { _statement.close() }

    step() {
        if (_statement.step()) {
            _stepCount = _stepCount + 1
            if (_statement.columnCount == 0) {
                _current = null
            } else if (_statement.columnCount == 1) {
                _current = _statement.column(0)
            } else {
                _current = _row.new(_statement)
            }
        } else {
            _current = null
        }
    }

    iterate(iterator) {
        if (iterator== null) {
            if (_stepCount == 0) {
                return null
            } else if (_stepCount == 1) {
                return 1
            } else {
                Fiber.abort("You cannot iterate through an SQL query twice. Use .toList if you "+
                        "wish to load all results into memory at once.")
            }
        } else {
            if (iterator== _stepCount) {
                step()
                if (_stepCount > iterator) {
                    return _stepCount
                } else {
                    return null
                }
            } else {
                Fiber.abort("You cannot iterate through an SQL query twice. Use .toList if you "+
                        "wish to load all results into memory at once.")
            }
        }
    }

    iteratorValue(iterator) {
        if (iterator == _stepCount) {
            return _current
        } else {
            Fiber.abort("You cannot iterate through an SQL query twice. Use .toList if you "+
                    "wish to load all results into memory at once.")
        }
    }

    columnNames { (0..._statement.columnCount).map{|index| _statement.columnName(index) }.toList }

    toCamel(name) {
        var first = true
        if (!__buf) __buf = Buffer.new()
        __buf.clear()
        var underscore = false
        for (char in name) {
            if (first) {
                __buf.write(S.asciiLower(char))
                first = false
            } else if (char == "_") {
                underscore = true
            } else if (underscore) {
                __buf.write(S.asciiUpper(char))
            } else {
                __buf.write(char)
            }
        }
        return __buf.read()
    }

    isValidIdentifier(name) {
        if (name.count == 0) {
            return false
        } else {
            if (IdentStart.contains(name[0])) {
                for (char in name[1...name.bytes.count]) {
                    if (!(IdentAny.contains(char))) return false
                }
                return true
            } else {
                return false
            }
        }
    }

    initRowFromStatement_() {
        var niceColumnIndices = {}
        var rawColumnIndices = {}
        for (column in 0..._statement.columnCount) {
            rawColumnIndices[_statement.columnName(column)] = column
        }
        for (entry in rawColumnIndices) {
            var camel = toCamel(entry.key)
            if (isValidIdentifier(camel)) niceColumnIndices[camel] = entry.value
        }
        var rowSource = """
        {
            class Row {
                static columnIndices=(value) { __columnIndices = value }
                construct new(statement) {
                    _cells = (0...statement.columnCount).map{|i| statement.column(i)}.toList
                }

                [index] { 
                    if (index is Num) {
                        return _cells[index]
                    } else if (__columnIndices.containsKey(index)) {
                        return _cells[__columnIndices[index]]
                    } else {
                        Fiber.abort("No such column: %(index)")
                    }
                }

                $getters$
            }
            return Row
        }
        """.replace("$getters$", niceColumnIndices.toList
                .map{|entry| "%(entry.key) { _cells[%(entry.value)] }" }.join("\n"))
        
        var row = Meta.compile(rowSource).call()
        row.columnIndices = rawColumnIndices

        StatementRowObjects[_text] = row
        return row

    }
}

foreign class Statement {
    // This corresponds to a sqlite3_stmt in the underlying C layer.
    construct prepare(db, text) {}
    foreign bind(index, value)
    foreign step()
    foreign column(index)
    foreign columnName(index)
    foreign columnCount
    foreign reset()
    foreign close()
}

var Dispatch = [
    null,
    null,
    Fn.new{|fn, stmt| fn.call(stmt.column(0),stmt.column(1))},
    Fn.new{|fn, stmt| fn.call(stmt.column(0),stmt.column(1),stmt.column(2))},
    Fn.new{|fn, stmt| fn.call(stmt.column(0),stmt.column(1),stmt.column(2),stmt.column(3))},
    Fn.new{|fn, stmt| fn.call(stmt.column(0),stmt.column(1),stmt.column(2),stmt.column(3),
            stmt.column(4))},
    Fn.new{|fn, stmt| fn.call(stmt.column(0),stmt.column(1),stmt.column(2),stmt.column(3),
            stmt.column(4),stmt.column(5))},
    Fn.new{|fn, stmt| fn.call(stmt.column(0),stmt.column(1),stmt.column(2),stmt.column(3),
            stmt.column(4),stmt.column(5),stmt.column(6))},
    Fn.new{|fn, stmt| fn.call(stmt.column(0),stmt.column(1),stmt.column(2),stmt.column(3),
            stmt.column(4),stmt.column(5),stmt.column(6),stmt.column(7))},
    Fn.new{|fn, stmt| fn.call(stmt.column(0),stmt.column(1),stmt.column(2),stmt.column(3),
            stmt.column(4),stmt.column(5),stmt.column(6),stmt.column(7),
            stmt.column(8))},
    Fn.new{|fn, stmt| fn.call(stmt.column(0),stmt.column(1),stmt.column(2),stmt.column(3),
            stmt.column(4),stmt.column(5),stmt.column(6),stmt.column(7),
            stmt.column(8),stmt.column(9))},
    Fn.new{|fn, stmt| fn.call(stmt.column(0),stmt.column(1),stmt.column(2),stmt.column(3),
            stmt.column(4),stmt.column(5),stmt.column(6),stmt.column(7),
            stmt.column(8),stmt.column(9),stmt.column(10))},
    Fn.new{|fn, stmt| fn.call(stmt.column(0),stmt.column(1),stmt.column(2),stmt.column(3),
            stmt.column(4),stmt.column(5),stmt.column(6),stmt.column(7),
            stmt.column(8),stmt.column(9),stmt.column(10),stmt.column(11))},
    Fn.new{|fn, stmt| fn.call(stmt.column(0),stmt.column(1),stmt.column(2),stmt.column(3),
            stmt.column(4),stmt.column(5),stmt.column(6),stmt.column(7),
            stmt.column(8),stmt.column(9),stmt.column(10),stmt.column(11),
            stmt.column(12))},
    Fn.new{|fn, stmt| fn.call(stmt.column(0),stmt.column(1),stmt.column(2),stmt.column(3),
            stmt.column(4),stmt.column(5),stmt.column(6),stmt.column(7),
            stmt.column(8),stmt.column(9),stmt.column(10),stmt.column(11),
            stmt.column(12),stmt.column(13))},
    Fn.new{|fn, stmt| fn.call(stmt.column(0),stmt.column(1),stmt.column(2),stmt.column(3),
            stmt.column(4),stmt.column(5),stmt.column(6),stmt.column(7),
            stmt.column(8),stmt.column(9),stmt.column(10),stmt.column(11),
            stmt.column(12),stmt.column(13),stmt.column(14))},
    Fn.new{|fn, stmt| fn.call(stmt.column(0),stmt.column(1),stmt.column(2),stmt.column(3),
            stmt.column(4),stmt.column(5),stmt.column(6),stmt.column(7),
            stmt.column(8),stmt.column(9),stmt.column(10),stmt.column(11),
            stmt.column(12),stmt.column(13),stmt.column(14),stmt.column(15))}
]

foreign class SQLite3 {
    construct open(path) {}

    sql(text) {
        var statement = Statement.prepare(this, text)
        return finish_(statement, text, null)
    }

    sql(text, alpha) {
        var statement = Statement.prepare(this, text)
        if (alpha is Fn) {
            return finish_(statement, text, alpha)
        } else {
            bindParameters_(statement, alpha)
            return finish_(statement, text, null)
        }
    }

    sql(text, bindings, rowFn) {
        var statement = Statement.prepare(this, text)
        bindParameters_(statement, bindings)
        return finish_(statement, text, rowFn)
    }

    bindParameters_(statement, bindings) {
        if ((bindings is Sequence) && !(bindings is String)) {
            bindings.each{ |elem, idx| statement.bind(idx + 1, elem) }
        } else {
            statement.bind(1, bindings)
        }
    }

    transact(fn) {
        sql("BEGIN TRANSACTION")
        fn.call()
        sql("COMMIT TRANSACTION")
    }

    finish_(statement, text, rowFn) {
        var result = null
        if (statement.columnCount == 0) {
            if (rowFn) {
                while (statement.step()) {
                    if (rowFn.call(null) == false) break
                }
            } else {
                statement.step()
            }
        } else if (statement.columnCount == 1) {
            if (rowFn) {
                while (statement.step()) {
                    if (rowFn.call(statement.column(0)) == false) break
                }
            } else {
                if (statement.step()) result = statement.column(0)
            }
        } else {
            if (rowFn) {
                if (rowFn.arity == statement.columnCount) {
                    var a = rowFn.arity
                    while (statement.step()) {
                        if (Dispatch[a].call(rowFn, statement) == false) break
                    }
                } else {
                    var rowClass = getRowFactory(statement, text)
                    while (statement.step()) {
                        if (rowFn.call(rowClass.new(statement)) == false) break
                    }
                }
            } else {
                var rowClass = getRowFactory(statement, text)
                if (statement.step()) result = rowClass.new(statement)
            }
        }
        statement.close()
        return result
    }

    [text] { sql(text) }
    [text, alpha] { sql(text, alpha) }
    [text, alpha, rowFn] { sql(text, alpha, rowFn) }

    foreign executeScript(script)

    // Close the database connection.
    foreign close()
}

GG.bind(null)
