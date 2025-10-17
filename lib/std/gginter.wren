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

// 0x00 - 0x7F: Integer, biased so 0x3F = 0
// 0x80 - 0xBF: String, length 0..63
// 0xC0 - 0xDF: List, length 0..31
// 0xE0 - 0xEF: Map: length 0..15
// 0xF0: String
// 0xF1: List
// 0xF2: Map
// 0xF3: Positive int
// 0xF4: Negative int
// 0xF5: Double
// 0xF6: true
// 0xF7: false
// 0xF8: null
// 0xF9-0xFF: reserved

class GGInter {
    static decode(string) {
    }

    static encodeInto(value, stream) {
        encodeValue_(value, stream)
    }

    static encode(value) {
        var result = Buffer.new()
        encodeValue_(value, buffer)
        return result.toString
    }

    static encodeVarInt_(value, stream) {
        while (value > 127) {
            stream.writeByte((value & 0x7F) | 0x80)
            value = (value / 128).floor
        }
        stream.writeByte(value)
    }

    static encodeValue_(value, stream) {
        if (value is Num) {
            if ((value >= Num.minSafeInteger) && (value <= Num.maxSafeInteger) && 
                    (value == value.floor)) {
                // Integer
                var biased = value - 0x3F
                if ((biased >= 0) && (biased <= 0x7F)) {
                    stream.writeByte(biased)
                } else if (value >= 0) {
                    stream.writeByte(0xF3)
                    encodeVarInt_(value, stream)
                } else {
                    stream.writeByte(0xF4)
                    encodeVarInt_(-value, stream)
                }
            } else {
                // Float
                stream.writeByte(0xF5)
                stream.write(Pack.numToLEBytes(value))
            }
        } else if (value is String) {
            if (value.bytes.count < 64) {
                stream.writeByte(0x80 + value.bytes.count)
            } else {
                stream.writeByte(0xF0)
                encodeVarInt_(value.bytes.count, stream)
            }
            stream.write(value)
        } else if (value is Bool) {
            stream.writeByte(value ? 0xF6 : 0xF7)
        } else if (value is Null) {
            stream.writeByte(0xF8)
        } else if (value is List) {
            if (value.count < 32) {
                stream.writeByte(0xC0 + value.count)
            } else {
                stream.writeByte(0xF1)
                encodeVarInt_(value.count, stream)
            }
            for (elem in value) {
                encodeValue_(elem, stream)
            }
        } else if (value is Map) {
            if (value.count < 16) {
                stream.writeByte(0xE0 + value.count)
            } else {
                stream.writeByte(0xF2)
                encodeVarInt_(value.count, stream)
            }
            for (entry in value) {
                encodeValue_(entry.key, stream)
                encodeValue_(entry.value, stream)
            }
        } else {
            encodeValue_(value.encode, stream)
        }
    }
}
