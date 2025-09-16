import "lib/io/fs" for Fs
import "lib/ext/sqlite3" for SQLite3

import "gg" for GG

import "log" for Log

var DBPath = Fs.join(GG.scriptDir, "main.db")
Log.debug("Database path is %(DBPath)")
var mustInitializeDB = !Fs.exists(DBPath)

var DB = SQLite3.open(DBPath)

if (mustInitializeDB) DB.executeScript(Fs.readEntireFile(Fs.join(GG.scriptDir,"init.sql")))

class Config {
    static [name] { 
        var value = DB.sql("SELECT value FROM Configuration WHERE key=?", [name]).first
        if (value) value = value.toString
        if (value == "") {
            value = null
        }
        return value
    }

    static [name]=(value) {
        if ((value == null) || (value == "")) {
            DB.sql("DELETE Configuration WHERE key = ?", [key])
        } else {
            DB.sql("INSERT INTO Configuration (key, value) VALUES (?,?) ON CONFLIGHT (key) DO
                    UPDATE SET value = excluded.value", [name, value.toString])
        }
    }
}

class PropView {
    construct new(obj) {
        _obj = obj
    }

    [name] { 
        name = name.trim()
        _obj.ensureExists
        var value = DB.sql("SELECT value FROM Property WHERE object=? AND LOWER(name)=LOWER(?)",
                [_obj.id,name]).first
        if (value == "") value = null
        return value
    }

    [name]=(value) {
        name = name.trim()
        if (value && value.bytes.count == 0) value = null
        _obj.ensureExists
        if (value) {
            var current = DB.sql("SELECT value FROM Property WHERE id=? AND LOWER(name)=LOWER(?)",
                    [_obj.id, name]).first
            if (current) {
                DB.sql("UPDATE Property SET value=? WHERE id=? AND LOWER(name)=LOWER(?)",
                        [value, _obj.id, name])
            } else {
                DB.sql("INSERT INTO Property (object, name, value, flags) VALUES (?,?,?,?)",
                        [_obj.id, name, value, ""])
            }
        } else {
            DB.sql("DELETE Property WHERE id=? AND LOWER(name)=LOWER(?)", [_obj.id, name])
        }
        return value
    }
}

class PropFlagsView {
    construct new(obj) {
        _obj = obj
    }
    
    /*@todo */
}

class Obj {
    construct new(id) {
        if (id is Obj) {
            _id = id.id
        } else if (id == null) {
            _id = 0
        } else if (id is Num) {
            _id = id.max(0).floor
        } else {
            Fiber.abort("The parameter to Obj::new(..) must be an Obj, Null, or Num, not "+
                    "%(id.type.name)")
        }
        _propView = PropView.new(this)
        _propFlagsView = PropFlagsView.new(this)
        _conn = null
    }

    static players {
        return DB.sql("SELECT id FROM Object WHERE flags GLOB '*p*'").map{|id| Obj.new(id) }.toList
    }

    isConnected {
        for (task in Task.queue) {
            if (task is Connection) {
                if (task.player.id == id) {
                    return true
                }
            }
        }
        return false
    }

    conn { _conn }
    conn=(value) { _conn = value }

    static [id] {
        var obj = this.new(id)
        return obj.exists ? obj : null
    }

    answersTo(string) {
        for (alias in allNames) {
            if (alias.lower == string.squish.lower) {
                return true
            }
        }
        return false
    }

    id { _id }

    exists {
        var count = DB.sql("SELECT COUNT(*) FROM Object WHERE id=?",[id]).first
        return count > 0
    }

    ensureExists {
        if (!exists) Fiber.abort("Object #%(id) no longer exists.")
        return true
    }

    allNames { ensureExists && DB.sql("SELECT name FROM Object WHERE id=?",[id]).
            first.split(",").toList }

    rename(newNames) {
        if (newNames is Sequence) newNames = newNames.join(",")

        var parts = newNames.split(",").toList
        for (i in 0...parts.count) {
            parts[i] = parts[i].squish
        }

        parts = parts.filter{|part| part.bytes.count > 0}.toList

        if (parts) {
            ensureExists
            DB.sql("UPDATE Object SET name=? WHERE id=?", [newNames, id])
        } else {
            Fiber.abort("You must provide a valid name to rename %(name) to.")
        }
    }

    props { _propView }
    propflags { _propFlagsView }

    name { (props["article"] ? "the " : "") + allNames[0] }

    pronoun(index) { 
        var pronouns = props["pronouns"]
        if (!pronouns) {
            pronouns = "it,it,its"
        }
        pronouns = pronouns.split(",")
        if (pronouns.count <= index) return ["it","it","its"][index]
        return pronouns[index]
    }

    subjPn { pronoun(0) }
    objPn { pronoun(1) }
    possPn { pronoun(2) }

    loc { ensureExists && DB.sql("SELECT location FROM Object WHERE id=?",[id]).
            first.then{|x| Obj[x] }}

    contents { 
        if (exists) {
            return DB.sql("SELECT id FROM Object WHERE loc=?",[id]).map{|id| Obj[id]}.toList
        } else {
            return []
        }
    }

    move(dest) {
        var chain = dest
        while (chain) {
            if (chain == this) Fiber.abort("Doing so would cause %(fullName) to contain "+
                    "%(objPn)self.")
            chain = chain.loc
        }
        DB.sql("UPDATE Object SET loc=? WHERE id=?",[dest, id])
    }

    hear(speaker, msg) {
        // @todo
    }

    say(msg) {
        for (obj in this.loc.contents) {
            if (obj != this) {
                obj.hear(this, msg)
            }
        }
    }

    == (other) { this.id == other.id }
    != (other) { this.id != other.id }
}
