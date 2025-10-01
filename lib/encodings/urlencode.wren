import "meta" for Meta
import "lib/buffer" for Buffer

var AllowedInURLEncodeRaw = 
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-~".bytes.toList

var AllowedInQuotedURL = []

for (byte in 0..255) {
    AllowedInQuotedURL.add(AllowedInURLEncodeRaw.contains(byte))
}

var Hex = "0123456789ABCDEF".bytes.toList

var HexDecode = List.filled(256, null)

var fill = Fn.new{|string, base|
    for (byte in string.bytes) {
        HexDecode[byte] = byte + base - string.bytes[0]
    }
}
fill.call("0123456789",0)
fill.call("ABCDEF",10)
fill.call("abcdef",10)
fill = null

class URLEncode {
    static encode(string) {
        var result = Buffer.new()
        for (byte in string.bytes) {
            if (AllowedInQuotedURL[byte]) {
                result.writeByte(byte)
            } else {
                result.writeByte(37)
                result.writeByte(Hex[byte >> 4])
                result.writeByte(Hex[byte & 0xF])
            }
        }
        return result.read()
    }

    static decode(string) {
        var result = Buffer.new()
        var countdown = null
        for (byte in string.bytes) {
            result.writeByte(byte)
            if (countdown) {
                countdown = countdown - 1
                if (countdown == 0) {
                    var hexValues = result.read()[-2..-1].bytes
                    if (HexDecode[hexValues[0]] && HexDecode[hexValues[1]]) {
                        result.truncate(result.size - 3)
                        result.writeByte((HexDecode[hexValues[0]] << 4) | HexDecode[hexValues[1]])
                    }
                    countdown = null
                } 
            } else {
                if (byte == 37) countdown = 2
            }
        }
        return result.read()
    }

    static mixin() {
        Meta.extend(String, URLEncodeMixin, ["quote","unquote"])
    }
}

class URLEncodeMixin {
    quote { URLEncode.encode(this) }
    unquote { URLEncode.decode(this) }
}
