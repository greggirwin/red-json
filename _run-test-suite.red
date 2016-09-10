Red []

do %json.red

change-dir %tests/

pass?: func [file] [not error? set/any 'err try [load-json read file]]
fail?: func [file] [error? set/any 'err try [load-json read file]]

json-files: function [] [
	remove-each file files: read %. [%.json <> suffix? file]
	files
]
json-pass-files: function [] [
	remove-each file files: json-files [not find/match file %pass]
	files
]
json-fail-files: function [] [
	remove-each file files: json-files [not find/match file %fail]
	files
]

print "Running pass tests"
foreach file json-pass-files [
	if not pass? file [
		print [tab mold file "failed to parse as expected. Halting."]
		print mold disarm err
		halt
	]
]
print "Pass tests complete"
print ""
print "Running fail tests"
foreach file json-fail-files [
	if not fail? file [print [tab mold file "didn't fail as expected"]]
]
print "Fail tests complete"


halt
