import "test" for Test
import "lib/encodings/json" for JSON
import "lib/mustache" for Mustache
import "lib/io/fs" for Fs
import "gg" for GG

var TestSuiteDir = Fs.join(GG.scriptDir, "tests/mustache-spec/specs")

if (Fs.isDir(TestSuiteDir)) {
    for (filename in Fs.listDir(TestSuiteDir)) {
        if (!filename.startsWith("~") && filename.endsWith(".json")) {
            var text = Fs.readEntireFile(Fs.join(TestSuiteDir, filename))
            // System.print(text)
            var suite = JSON.decode(text)
            for (test in suite["tests"]) {
                Test.require("[%(filename.split(".")[0])] %(test["name"])"){
                    return Mustache.render(test["template"], test["data"], 
                            test["partials"]) == test["expected"]
                }
            }
        }
    }
} else {
    Test.warn("Skipping mustache spec compliance test suite because it is not available.")
}
