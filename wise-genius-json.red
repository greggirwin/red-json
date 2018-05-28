Red [
	Title:		"JSON Codec"
	Author:		"WiseGenius"
	Purpose:	"Convert between JSON strings and Red datatypes."
	File:		%json.red
	Version:	0.0.1
	Date:		"2016-08-05"
	Tabs:		4
	Rights:		"© 2016 WiseGenius."
	License:	{
					Distributed under the Boost Software License, Version 1.0.
						(See accompanying file LICENSE_1_0.txt or copy at
							http://www.boost.org/LICENSE_1_0.txt)
				}
	Notes:		{
					This file should be temporary until Red has a built-in JSON codec.
						See https://trello.com/c/hI62d8n0/55-codecs
					JSON References:
						http://rfc7159.net/rfc7159
						http://www.json.org/
						https://en.wikipedia.org/wiki/JSON
				}
]
Rebol []

if require [
	#include %../x/map-each.red		;;????TEMPORARY MEZZANINE
	#include %../x/to-map.red		;;????TEMPORARY MEZZANINE
][]

;;	“Insignificant whitespace is allowed before or after any of the six structural characters.” - http://rfc7159.net/rfc7159#rfc.section.2
whitespace: charset " ^-^/^M"
ws: [any whitespace]

digit: charset "0123456789"
digit1-9: charset "123456789"
hex-digit: charset "0123456789ABCDEFabcdef"

;;	Almost directly from:	http://www.json.org/
j-object: ["{" ws opt [j-pair any [ws "," ws j-pair]] ws "}"]
j-pair: [j-string ws ":" ws j-value]
j-array: ["[" ws opt [j-value any [ws "," ws j-value]] ws "]"]
j-value: [j-string | j-number | j-object | j-array | "true" | "false" | "null"]
j-unescaped-char: make bitset! [not {"\}]
j-string: [{"} any [
	j-unescaped-char
	| {\"}
	| {\\}
	| {\/}
	| {\b}
	| {\f}
	| {\n}
	| {\r}
	| {\t}
	| {\u} 4 hex-digit
] {"}]
j-number: [j-int opt j-frac opt j-exp]
j-int: [[digit1-9 some digit] | digit]
j-frac: ["." some digit]
j-exp: [j-e some digit]
j-e: [["e" | "E"] opt ["+" | "-"]]




load-json: function [json [string!]][
	key: copy ""
	val: copy ""
	txt: copy ""
	obj: copy #()		;;<- ????This line only works in Red
	;obj: make map! []	;;<- ????This line only works in Red and Rebol 3
	ary: copy []
	x-j-pair: [copy key j-string ws ":" ws copy val j-value (set/case 'obj/(load-json key) load-json val)]
	x-j-element: [copy val j-value (append ary load-json val)]
	if not parse/case json [ws [
		 [{"} any [
			  copy val j-unescaped-char	(append txt val)
			| copy val [{\"} | {\\} | {\/} | {\b} | {\f} | {\n} | {\r} | {\t}] (
				append txt select #(	;;????This map! syntax only works in Red:
					{\"} #"^""
					"\\" #"\"
					"\/" #"/"
					"\b" #"^H"
					"\f" #"^L"
					"\n" #"^/"
					"\r" #"^M"
					"\t" #"^-"
				) val
			)
			| {\u} copy val [4 hex-digit]	(append txt load rejoin [{#"^^(} val {)"}])
			;;????!!!!TODO: Correctly parse surrogate pairs.
		] {"}] 	(return txt)
		| copy val j-number	(return load val)
		| ["{" ws opt [x-j-pair any [ws "," ws x-j-pair]] ws "}"] (return obj)
		| ["[" ws opt [x-j-element any [ws "," ws x-j-element]] ws "]"]	(return ary)
		| "true"	(return true)
		| "false"	(return false)
		| "null"	(return none)
	] ws] [complain ["Invalid json: " json]]
]


to-json: function [
	"Converts a Red value to a JSON string."
	obj [map! object! string! word! integer! block! logic! none! number!]
][
	switch/default type?/word obj [
		string! [
			result: copy {"}
			foreach chr obj [
				;;	“All Unicode characters may be placed within the quotation marks, except for the characters that must be escaped: quotation mark, reverse solidus, and the control characters (U+0000 through U+001F).”	-	http://rfc7159.net/rfc7159#rfc.section.7
				;????TODO: Try replacing the following `switch` with a `map!` and test the speed difference:
				append result switch/default chr [
					#"^""	[{\"}]
					#"\"	["\\"]
					#"/"	["\/"]
					#"^H"	["\b"]
					#"^L"	["\f"]
					#"^/"	["\n"]
					#"^M"	["\r"]
					#"^-"	["\t"]
				][
					either chr < 32 [				;;<- ????This line only works in Red and Rebol 2.
					;either 32 > to integer! chr [	;;<- ????This line works in Red, Rebol 3 and Rebol 2
						rejoin ["\u" copy/part skip mold append copy #{00} chr 2 4]
					][
						chr
					]
				]
			]
			rejoin [result {"}]
		]
		map! [rejoin [
			"{"
				combine/with map-each key keys-of obj [
					either any [string! = type? key word! = type? key][
						rejoin [to-json key ":" to-json obj/:key]
						;;????TODO:	Avoid the situation where `#(key 1 "key" 2)` becomes `{{"key":1,"key":2}}`.
					][
						complain [mold/all key " is of type " type? key "!. JSON keys can only be string!s or word!s."]
						exit
					]
				] ","
			"}"
		]]
		block! [rejoin [
			"["
				combine/with map-each item obj [
					to-json item
				] ","
			"]"
		]]
		object! [to-json to-map obj]
		logic! [mold obj]
		none! ["null"]
		integer! [mold obj]
		float! [mold obj]
	][
		to-json mold/all obj
	]
]