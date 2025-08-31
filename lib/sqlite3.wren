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
// have a getter for each column. These getters are the column names casted into Wren's
// dromedaryCase syntax; so for example:
//
//      SELECT first_name, last_name FROM Persons WHERE uid=?;
//
// -- will return instances of a Row class on which Row.firstName, Row.lastName are the
// defined getters.
//
// Columns whose name is not expressible as a Wren identifier -- e.g. "COUNT(*)" -- and
// columns whose name matches a previous column will be renamed using a mangled row*
// identifier. You can either use AS to make sure you collect the right one, or you can
// use [..] to get columns by their original names.
//
// As always, you are advised to familiarize yourself with the SQLite documentation.
// https://sqlite.org/docs.html

import "lib/buffer" for Buffer
import "lib/string" for StringUtil as S
import "gg" for GG
import "meta" for Meta

GG.bind("sqlite3")

foreign class Statement {
    // This corresponds to a sqlite3_stmt in the underlying C layer.
    construct prepare(db, statement) {}
    foreign bind(index, value)
    foreign step()
    foreign column(index)
    foreign columnName(index)
    foreign columnCount
    foreign reset()
}

var Rows = {}

class QueryResult is Sequence {
    construct new(query, statement) {
        _statement = statement
        _query = query
        _row = Rows[query]
        if (_row == null) initRowFromStatement_()
        _first = step()
        _current = first
        _iterateAvailable = true
    }

    step() {
        if (_statement.step()) {
            _current = _row.new(_statement)
        } else {
            _current = null
        }
        return _current
    }

    static fixCase(name) {
        // "Fix" a statement's case.
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

    initRowFromStatement_() {
        var columnCount = _statement.columnCount
        var columnNames = (0...columnCount).
                map{|index| QueryResult.fixCase(_statement.columnName(index)) }.toList

        var columnInstantiators = (0...columnCount).
                map{|index| "_%(columnNames[index]) = statement.column(%(index))"}.join("\n")

        var columnGetters = (0...columnCount).
                map{|index| "%(columnNames[index]) { _%(columnNames[index]) }"}.join("\n")

        var source = "
            class Row {
                construct new(statement) {
                    %(columnInstantiators)
                }
                %(columnGetters)
            }
            return Row
        "
        _row = Meta.compile(source).call()
        Rows[_query] = _row
    }

    first { _first }

    iterate(iterator) {
        if (iterator == null) {
            iterator = _first || false
            if (_iterateAvailable) {
                _iterateAvailable = false
            } else {
                Fiber.abort("It is not possible to iterate twice over a QueryResult. Use .toList "+
                        "if need all the data in memory at once.")
            }
        } else {
            iterator = step() || false
        }
        return iterator
    }

    iteratorValue(iterator) {
        return iterator
    }
}

// A connection to a SQLite3 database.
foreign class SQLite3 {
    // Open the connection. A blank database file will be created if one does
    // not exist at `path`.
    construct open(path) {}

    // Execute a query. Bindings should be a List of values to bind to the query.
    // The returned value is a QueryResult, which can be iterated over.
    sql(query) { QueryResult.new(query, Statement.prepare(this, query)) }
    sql(query, bindings) {
        var statement = Statement.prepare(this, query)
        for (index in 0...bindings.count) {
            statement.bind(index + 1, bindings[index])
        }
        return QueryResult.new(query, statement)
    }

    // Close the database connection.
    foreign close()
}

GG.bind(null)
