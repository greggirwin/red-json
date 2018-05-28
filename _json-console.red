Red []

do %json.red

print mold load-json "null"
print mold load-json "true"
print mold load-json "false"
print mold load-json "1"
print mold load-json "-1.2e3"
print mold load-json {"abc"}
print mold load-json {"\u0000\u001f"}
print mold load-json "[]"
print mold load-json {["A", 1]}
print mold load-json {{}}
print mold load-json {{"a": {"b": {"c": 3}}}}
print mold load-json {{"a": { "b": {"c": 3, "d": 4}}}}
print mold load-json {{"A": 1, "a": {"b": { "c": 3, "d": [ "x", "y", [3, 4 ], "z"] }}, "B": 2}}

;print mold to-json "^@^A^B^C^D^E^F^G^H^-^/^K^L^M^N^O^P^Q^R^S^T^U^V^W^X^Y^Z^[^\^]^(1E)^_ "


halt

