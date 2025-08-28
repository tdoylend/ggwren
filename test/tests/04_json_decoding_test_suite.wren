import "test" for Test
import "lib:encodings:json" for JSON
import "lib:io:fs" for Fs
import "gg" for GG

var TestSuiteDir = Fs.join(GG.scriptDir, "tests/JSONTestSuite/test_parsing")

if (Fs.isDir(TestSuiteDir)) {
    for (filename in Fs.listDir(TestSuiteDir)) {
        if (filename.endsWith(".json")) {
            var text = Fs.readEntireFile(Fs.join(TestSuiteDir, filename))
            if (filename.startsWith("y_")) {
                Test.require(filename){
                    JSON.decode(text)
                    return true
                }
            } else if (filename.startsWith("n_")) {
                Test.require(filename){
                    var result = Fiber.new{JSON.decode(text)}.try()
                    if (result is String) {
                        if (result.startsWith("[JSON")) return true
                        return false
                    } else {
                        return false
                    }
                }
            } else if (filename.startsWith("i_")) {
                Test.require(filename){
                    var result = Fiber.new{JSON.decode(text)}.try()
                    if (result is String) {
                        if (result.startsWith("[JSON")) return true
                        return false
                    } else {
                        return true
                    }
                }
            } else {
                Fiber.abort("JSONTestSuite tests must specify y_*, n_*, or i_*.")
            }
        }
    }
} else {
    Test.warn("Skipping JSONTestSuite because it is not available.")
}
