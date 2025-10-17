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

import "lib/buffer" for Buffer

var Parent = null

class Template {
    construct new(fn) {
        _fn = fn
    }

    render() {
        var output = Buffer.new()
        _fn.call(data, output)
        return output.toString
    }
}

class Embed {
    static template(source, target) {
        var result = Buffer.new()
        


        Parent = parent || Object
        result.write("Template.new{|data, buf_|

        }")
        return meta.compile(result).call()
    }
}
