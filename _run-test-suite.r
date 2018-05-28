rebol []

do %json.r

pass?: func [file] [not error? set/any 'err try [load-json read file]]
fail?: func [file] [error? set/any 'err try [load-json read file]]

change-dir %tests/

print "Running pass tests"
files: read %.
remove-each file files [not find/match file %pass]
foreach file files [
	if not pass? file [
		print [tab mold file "didn't pass"]
		print mold disarm err
		;halt
	]
]
print "Pass tests complete"
print ""
print "Running fail tests"
files: read %.
remove-each file files [not find/match file %fail]
foreach file files [
	if not fail? file [
	    print [tab mold file "didn't fail as expected"]
	]
]
print "Fail tests complete"


halt
