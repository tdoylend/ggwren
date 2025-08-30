import "test" for Test
import "lib/encodings/json" for JSON
import "lib/io/fs" for Fs
import "lib/string" for BytewiseLexicalOrdering
import "gg" for GG

var TestSuiteDir = Fs.join(GG.scriptDir, "tests/JSONTestSuite/test_parsing")

class Structure {
    static compare(a, b) {
        if (!Object.same(a.type, b.type)) {
            return false
        }
        if (a is List) {
            if (a.count != b.count) return false
            return (0...a.count).all{|index| Structure.compare(a[index], b[index])}
        } else if (a is Map) {
            if (a.count != b.count) return false
            var aKeys = a.keys.toList
            var bKeys = b.keys.toList
            aKeys.sort(BytewiseLexicalOrdering)
            bKeys.sort(BytewiseLexicalOrdering)
            if (!Structure.compare(aKeys, bKeys)) return false
            return aKeys.all{|key| Structure.compare(a[key], b[key])}
        } else {
            return a == b
        }
    }
}

if (Fs.isDir(TestSuiteDir)) {
    for (filename in Fs.listDir(TestSuiteDir)) {
        if (filename.endsWith(".json") && filename.startsWith("y_")) {
            var text = Fs.readEntireFile(Fs.join(TestSuiteDir, filename))
            Test.require(filename) {
                // System.print(filename)
                var json = JSON.decode(text)

                var reText = JSON.encode(json)
                var reJSON = JSON.decode(reText)

                var result = Structure.compare(json, reJSON)
                if (!result) System.print(reJSON)
                return result
            }
        }
    }
} else {
    Test.warn("Skipping JSONTestSuite encoding because it is not available.")
}
