import "lib/string" for StringUtil as S
import "meta" for Meta

class StringMixins {
    find(substring) {
        var index = this.indexOf(substring)
        if (index < 0) {
            return null
        } else {
            return index
        }
    }
    
    find(substring, start) {
        var index = this.indexOf(substring, start)
        if (index < 0) {
            return null
        } else {
            return index
        }
    }

    upper { S.asciiUpper(this) }
    lower { S.asciiLower(this) }
    title { S.asciiTitle(this) }
    capitalize { S.asciiCapitalize(this) }

    splitOnce(substring) {
        var index = this.find(substring)
        if (index) {
            return [this[0...index], this[index+substring.bytes.count...this.bytes.count]]
        } else {
            return null
        }
    }
}

Meta.extend(String, StringMixins, ["upper", "lower", "find(_)", "find(_,_)", "title", "capitalize",
        "splitOnce(_)"])

class NumMixins {
    times(fn) {
        var i = this.floor.max(0)
        while (i > 0) {
            fn.call()
            i = i - 1
        }
    }
}

Meta.extend(Num, NumMixins, ["times(_)"])

class MapMixins {
    update(other) {
        for (entry in other) this[entry.key] = entry.value
    }

    | (other) {
        var result = {}
        for (entry in this) result[entry.key] = entry.value
        for (entry in other) result[entry.key] = entry.value
    }
}

Meta.extend(Map, MapMixins, ["update(_)","|(_)"])

class MaybeMixins {
    then(fn) { this ? fn.call(this) : this }
}
var MaybeMixinAPI = ["then(_)"]

Meta.extend(Bool, MaybeMixins, MaybeMixinAPI)
Meta.extend(Class, MaybeMixins, MaybeMixinAPI)
Meta.extend(Fiber, MaybeMixins, MaybeMixinAPI)
Meta.extend(Fn, MaybeMixins, MaybeMixinAPI)
Meta.extend(List, MaybeMixins, MaybeMixinAPI)
Meta.extend(Map, MaybeMixins, MaybeMixinAPI)
Meta.extend(Null, MaybeMixins, MaybeMixinAPI)
Meta.extend(Num, MaybeMixins, MaybeMixinAPI)
Meta.extend(Object, MaybeMixins, MaybeMixinAPI)
Meta.extend(Range, MaybeMixins, MaybeMixinAPI)
Meta.extend(Sequence, MaybeMixins, MaybeMixinAPI)
Meta.extend(String, MaybeMixins, MaybeMixinAPI)
