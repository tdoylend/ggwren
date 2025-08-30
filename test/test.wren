if (Fiber.new{
    import "gg"
}.try()) {
    System.print("This script requires GGWren to run.")
}

import "gg" for GG
import "lib/io/fs" for Fs
import "lib/os" for Process
import "lib/string" for StringUtil as S, BytewiseLexicalOrdering
import "lib/time" for Time
import "meta" for Meta

var Try = true

if (Process.arguments.contains("--no-try")) {
    Try = false
}

class Test {
    static init() {
        __passedTotal = 0
        __failedTotal = 0
        __warningTotal = 0
    }

    static warn(message) {
        System.print("\x1b[33;1mWARNING:\x1b[m "+message)
        __warningTotal = __warningTotal + 1
    }

    static finish() {
        System.print("TOTAL: %(__passedTotal) passed, %(__failedTotal) failed" + 
            (__warningTotal>0 ? ", %(__warningTotal) warning"+(__warningTotal != 1 ? "s" : "") : "")
        )
    }

    static start(test) {
        System.write("    " + S.left(test+" ", 50, ".")+"... ")
    }

    static pass() { pass(0) }

    static pass(t) {
        var timeInfo = (t > 1.0) ? " (%(t) seconds)" : ""
        System.print("\x1b[32;1mpassed\x1b[m%(timeInfo)")
        __passedTotal = __passedTotal + 1
    }

    static fail(t) { fail() }

    static fail() {
        System.print("\x1b[31;1mfailed\x1b[m")
        __failedTotal = __failedTotal + 1
    }
    
    static require(name, fn) {
        start(name)
        var result = null
        var error = null
        var fiber = Fiber.new{ result = fn.call() }
        var startTime = Time.now
        if (Try) {
            error = fiber.try()
        } else {
            error = fiber.call()
        }
        var endTime = Time.now
        if (error is String) {
            fail(endTime - startTime)
        } else if (!result) {
            fail(endTime - startTime)
        } else {
            pass(endTime - startTime)
        }
    }

    static requireAbort(name, fn) {
        start(name)
        var result = null
        var error = null
        var fiber = Fiber.new{ result = fn.call() }
        if (Try) {
            error = fiber.try()
        } else {
            error = fiber.call()
        }
        if (error is String) {
            pass(endTime - startTime)
        } else {
            fail(endTime - startTime)
        }
    }
}

Test.init()

var TestDir = Fs.join(GG.scriptDir, "tests")
var TestDirContents = Fs.listDir(TestDir)
TestDirContents.sort(BytewiseLexicalOrdering)

for (filename in TestDirContents) {
    if (filename.endsWith(".wren")) {
        var testName = filename.split(".")[0]
        System.print(testName)
        Meta.eval("import \"tests/%(testName)\"")
    }
}

Test.finish()
