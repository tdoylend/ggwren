import "lib:encodings:json" for JSON
import "test" for Test

Test.require("empty_list"){ JSON.decode("[]").count == 0 }
Test.require("empty_object"){ JSON.decode("{}").count == 0 }
Test.require("true"){ JSON.decode("true") == true }
Test.require("false"){ JSON.decode("false") == false }
Test.require("null"){ JSON.decode("null") == null }
Test.require("num"){ JSON.decode("-17.2e5") == -17.2e5 }
Test.require("string"){ JSON.decode("\"This\\nTest\"") == "This\nTest" }
Test.require("unicode"){ JSON.decode("\"\\u1234\"") == "\u1234" }

