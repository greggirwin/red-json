Red []

do %json.red

change-dir %tests/

pass?: func [file] [not error? set/any 'err try [load-json read file]]
fail?: func [file] [error? set/any 'err try [load-json read file]]

file: request-file %*.json
if file [
	res: load-json read file
	print mold res
]

halt
