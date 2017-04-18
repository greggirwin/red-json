Red []

do %json.red

print "# load-json"
foreach val [
	"null"
	"true"
	"false"
	"1"
	"-1.2e3"
	{"abc"}
	{"\t\n\\"}
	{"\u0000\u001f"}
	{"\u4EC1\u4EBA"}
	"[]"
	"[ ]"
	{["A", 1]}
	{{}}
	{{"array":[ ]}}
	;{{"array":[.]}}
	{{"a": {"b": {"c": 3}}}}
	{{"a": { "b": {"c": 3, "d": 4}}}}
	{{"A": 1, "a": {"b": { "c": 3, "d": [ "x", "y", [3, 4 ], "z"] }}, "B": 2}}
][print mold load-json val]

;print mold to-json "^@^A^B^C^D^E^F^G^H^-^/^K^L^M^N^O^P^Q^R^S^T^U^V^W^X^Y^Z^[^\^]^(1E)^_ "

print '-------------------

print "# to-json"
foreach val [
	none
	true
	false
	1
	-1200.0
	"abc"
	"^@^_"
	"仁人"
	[]
	["A" 1]
	#()
	#("a" #("b" #("c" 3)))
	#("a" #("b" #("c" 3 "d" 4)))
	#("A" 1 "a" #("b" #("c" 3 "d" ["x" "y" [3 4] "z"])) "B" 2)
][print mold to-json val]


halt

