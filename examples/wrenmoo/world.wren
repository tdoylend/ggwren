import "lib/ext/sqlite3" for SQLite3

class World {
    static open(path) {
        __db = SQLite3.open(path)
    }

    static db { __db }

    static close() {
    }
}

class Obj {
    static [id] {
        return null
    }
}
