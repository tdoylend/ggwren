import "test" for Test
import "lib:string" for StringUtil as S

Test.require("upper"){ S.asciiUpper("TyRannOsAurUS RezZ.2") == "TYRANNOSAURUS REZZ.2" }
Test.require("lower"){ S.asciiLower("AzAzaZaZ pqRQ 324!") == "azazazaz pqrq 324!" }
Test.require("upper_empty"){ S.asciiUpper("") == "" }
Test.require("lower_empty"){ S.asciiLower("") == "" }
Test.require("is_alpha") { S.isAlpha("THISisAstringOFallalphabeticalcharactERS") }
Test.require("is_non_alpha") { !S.isAlpha("THISisAstringOF~allalphabeticalcharactERS") }
Test.require("empty_is_not_alpha") { !S.isAlpha("") }
Test.require("join") { S.join(["a","beta","theta","GAMMA"],",_,") == "a,_,beta,_,theta,_,GAMMA" }
Test.require("empty_join") { S.join([],",_,") == "" }
Test.require("join_empties") { S.join(["","",""],",_,") == ",_,,_," }
Test.require("join_matches_builtin"){ S.join(1..100,":") == (1..100).join(":") }
