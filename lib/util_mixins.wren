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

    upper { S.asciiUpper(this) }
    lower { S.asciiLower(this) }
    title { S.asciiTitle(this) }
    capitalize { S.asciiCapitalize(this) }
}

Meta.extend(String, StringMixins, ["upper", "lower", "find(_)", "title", "capitalize"])

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
