Red [
	File:    %json.red
	Title:   "Red-JSON codec"
	Purpose: "Convert JSON to Red, and vice versa."
	Author:  "Gregg Irwin"
	;Date: 	 09-Sep-2016
	Version: 0.0.1
	History: {
		0.0.1 09-Sep-2016 "First release." Gregg
	}
	license: [
		http://www.apache.org/licenses/LICENSE-2.0 
		and "The Software shall be used for Good, not Evil."
	]
	References: [
		http://www.json.org/
		https://www.ietf.org/rfc/rfc4627.txt
		http://www.rfc-editor.org/rfc/rfc7159.txt
		http://www.ecma-international.org/publications/files/ECMA-ST/ECMA-404.pdf
	]
	Notes: {
		- Ported from %json.r by Romano Paolo Tenca, Douglas Crockford, and Gregg Irwin.
		- Further research: JSON libs by Chris Ross-Gill, Kaj de Vos, and @WiseGenius.
		
		? Do we want to have a single context or separate encode/decode contexts?
		? Do we want to use a stack with parse, or recursive load-json/decode calls?

		- Unicode support is in the works
		- Pretty formatting from %json.r removed
	}
]

json-ctx: object [

	translit: func [
		"Tansliterate sub-strings in a string"
		string [string!] "Input (modified)"
		rule   [block! bitset!] "What to change"
		xlat   [block! function!] "Translation table or function. MUST map a string! to a string!."
		/local val
	][
		parse string [
			some [
				change copy val rule (val either block? :xlat [xlat/:val][xlat val])
				| skip
			]
		]
		string
	]

	json-to-red-escape-table: [
	;   JSON Red
		{\"} "^""
		{\\} "\"
		{\/} "/"
		{\b} "^H"   ; #"^(back)"
		{\f} "^L"   ; #"^(page)"
		{\n} "^/"
		{\r} "^M"
		{\t} "^-"
	]
	red-to-json-escape-table: reverse copy json-to-red-escape-table
	
	json-esc-ch: charset {"t\/nrbf}             ; Backslash escaped json chars
	json-escaped: [#"\" json-esc-ch]			; Backslash escape rule
	red-esc-ch: charset {^"^-\/^/^M^H^L}        ; Red chars requiring json backslash escapes

	esc-json-to-red: func [string [string!] "(modified)"][
		translit string json-escaped json-to-red-escape-table
	]

	esc-red-to-json: func [string [string!] "(modified)"][
		translit string red-esc-ch red-to-json-escape-table
	]

	;ss: copy string: {abc\"\\\/\b\f\n\r\txyz}
	;esc-json-to-red string
	;esc-red-to-json string
	;ss = string

	;-----------------------------------------------------------
	;-- JSON decoder
	;-----------------------------------------------------------

	;# Basic rules
	ws:  charset " ^-^/^M"						; Whitespace
	ws*: [any ws]
	ws+: [some ws]
	sep: [ws* #"," ws*]							; JSON value separator
	digit: charset "0123456789"
	non-zero-digit: charset "123456789"
	hex-char:  charset "0123456789ABCDEFabcdef"
	ctrl-char: charset [#"^@" - #"^_"]			; Control chars 0-31
	chars: charset [not {\"} #"^@" - #"^_"]		; Unescaped chars (NOT creates a virtual bitset)
		
	; TBD: Unicode
	not-low-ascii-char: charset [not #"^(00)" - #"^(127)"]

	; everything but \ and "
	; Defining it literally this way, rather than a [NOT charset] rule, takes ~70K
	; Need to see if it's faster one way or the other. 
;	unescaped-char: charset [
;		#"^(20)" - #"^(21)"					; " !"
;		#"^(23)" - #"^(5B)"					; #$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[
;		#"^(5D)" - #"^(10FFF)"				; ]^^_`abcdefghijklmnopqrstuvwxyz{|}~  ...U+
;	]

	; JSON value rules
	
	;# Number
	sign: [#"-"]
	; Integers can't have leading zeros, but zero by itself is valid.
	int: [[non-zero-digit any digit] | digit]
	frac: [#"." some digit]
	exp:  [[#"e" | #"E"] opt [#"+" | #"-"] some digit]
	number: [opt sign  int  opt frac  opt exp]
	numeric-literal: :number
	
	;# String
	string-literal: [
		#"^"" copy _str [
			any [some chars | #"\" [#"u" 4 hex-char | json-esc-ch]]
		] #"^"" (
			if not empty? _str: any [_str copy ""] [
				;!! If we reverse the esc-json-to-red and replace-unicode-escapes
				;!! calls, the string gets munged (extra U+ chars). Need to investigate.
				;esc-json-to-red s
				;replace-unicode-escapes s
				replace-unicode-escapes esc-json-to-red _str
			]
		)
	]
	
	;# Object		
	json-object: [
		; Emit a new block to our output target, and push it on our
		; working stack, to handle nested structures. Emit returns
		; the insertion point for another value to go out into '_res,
		; but we want the target to be the block we just added, so
		; we reset '_res to that after 'emit is done.
		#"{" (push emit copy []  _res: last _res)
		ws* opt property-list
		; This is a little confusing. We're at the tail of our current
		; output target, which is on our stack. We pop that, then need
		; to back up one, which puts us AT the block of values we 
		; collected for this object in our output target. i.e., the 
		; values are in a sub-block at the first position now. We use
		; that (FIRST) to make a map! and replace the block of values
		; with the map! we just made. Note that a map is treated as a
		; single value, like an object. Using a block as the new value
		; requires using `change/only`.
		#"}" (
			_res: back pop
			_res: change _res make map! first _res
		)
	]
	
	property-list: [property any [sep property]]
	property: [json-name (emit _str) json-value]
	json-name: [ws* string-literal ws* #":"]
	
	;# List
	array-list: [json-value any [sep json-value]]
	json-array: [
		; Emit a new block to our output target, and push it on our
		; working stack, to handle nested structures. Emit returns
		; the insertion point for another value to go out into '_res,
		; but we want the target to be the block we just added, so
		; we reset '_res to that after 'emit is done.
		#"[" (push emit copy []  _res: last _res)
		ws* opt array-list
		#"]" (_res: pop)
	]

	;# Any JSON Value
	json-value: [
		ws*
		[
			; http://www.ietf.org/rfc/rfc7159.txt says literals must be lowercase
			"true"    (emit true)
			| "false" (emit false)
			| "null"  (emit none)
			| json-object
			| json-array
			| string-literal (emit _str)
			| copy _str numeric-literal (emit load _str)	; number
			mark:   										; set mark for failure location
		]
		ws*
	]

	;---------------------------------------------------------------------------
	
	stack: copy []
	push: func [val][append/only stack val]
	pop: does [take/last stack]
	

	_out: none	; Our output target/result                          
	_res: none	; The output position where new values are inserted
	_str: none	; Where string value parse results go               
	mark: none	; Current parse position
	
	; Add a new value to our output target, and set the position for
	; the next emit to the tail of the insertion.
	emit: func [value][_res: insert/only _res value]

	;---------------------------------------------------------------------------


	set 'load-json func [
		[catch]
		"Convert a json string to Red data"
		input [string!] "The json string"
	][
		_out: _res: copy []		; These point to the same position to start with
		mark: input
		either parse input json-value [pick _out 1][
			throw make error! form reduce [
				"Invalid json string. Near:"
				either tail? mark ["<end of input>"] [mold copy/part mark 40]
			]
		]
	]

	;-----------------------------------------------------------
	;-- JSON encoder
	;-----------------------------------------------------------

	dent: copy ""
	dent-size: 4
	indent:  does [append/dup dent #" " dent-size]
	outdent: does [remove/part dent dent-size]

	encode-char: func [
		"Convert a single char to \uxxxx format"
		char [char! string!]
	][
		;rejoin ["\u" to-hex/size to integer! char 4]
		if string? char [char: first char]
		append copy "\u" to-hex/size to integer! char 4
	]

;!! This is an optimization. The main reason it's here is that Red doesn't
;!! have a GC yet. While control chars may not be used much, they must never
;!! be allowed to create bad JSON data. RFC7159 says "Any character may be
;!! escaped.", so we need to support that. But, mainly, generating the lookup
;!! table once, and using that, prevents repeated block allocations in a func
;!! call used every time we encode a char.
	make-ctrl-char-esc-table: function [][
		collect [
			;!! FORM is used here, when building the table, because TRANSLIT
			;	requires values to be strings. Yes, that's leaking it's
			;	abstraction a bit, which has to do with it using COPY vs SET
			;	in its internal PARSE rule.
			keep reduce [form ch: make char! 0  encode-char ch]
			repeat i 31 [keep reduce [form ch: make char! i  encode-char ch]]
		]
	]
	ctrl-char-esc-table: make-ctrl-char-esc-table

	encode-control-chars: func [
		"Convert all control chars in string to \uxxxx format"
		string [any-string!] "(modified)"
	][
		if find string ctrl-char [
			;translit string ctrl-char :encode-char
			translit string ctrl-char ctrl-char-esc-table
		]
		string
	]
	;encode-control-chars "^@^A^B^C^D^E^F^G^H^-^/^K^L^M^N^O^P^Q^R^S^T^U^V^W^X^Y^Z^[^\^]^(1E)^_ "
;!!

	;TBD: Encode unicode chars
	encode-red-string: func [string "(modified)"][
		encode-control-chars esc-red-to-json string
		;TBD translit string not-low-ascii-char :encode-char
	]

	red-to-json-name: func [val][
		append add-quotes encode-red-string form val ":"
	]

	; MOLD adds quotes to string!, but not all any-string! values.
	add-quotes: func [str [string!] "(modified)"][append insert str {"} {"}]

	; Types that map directly to a known JSON type.
	json-type!: union any-block! union any-string! make typeset! [
		none! logic! integer! float! percent! map! object! ; decimal!
	]
	
	
	red-to-json-value: func [val][
		switch/default type?/word :val [
			string!  [add-quotes encode-red-string val]
			none!    ["null"]							; JSON value MUST be lowercase
			logic!   [pick ["true" "false"] val]		; JSON value MUST be lowercase
			integer! float! [form val] 					; TBD: add decimal!
			percent! [form make float! val]				; FORM percent! includes sigil
			map! object! [map-to-json-object val]		; ?? hash!
			word!    [
				either all [
					not error? try [get val]			; Error means word ref's no value. FORM and escape it.
					find json-type! type? get val		; Not a type json understands. FORM and escape it.
				][
					red-to-json-value get val
				][
					; No-value error, or non-JSON types become quoted strings.
					add-quotes encode-red-string form val
				]
			]
		][
			either any-block? :val [block-to-json-list val] [
				; FORM forces binary! values to strings, so newlines escape properly.
				add-quotes encode-red-string either any-string? :val [form val] [mold :val]
			]
		]
	]

	block-to-json-list: func [block [any-block!] /local result sep][
		indent
		result: copy "[^/"
		foreach value block [
			append result rejoin [dent red-to-json-value :value ",^/"]
		]
		outdent
		append clear any [find/last result ","  tail result] rejoin ["^/" dent "]"]
		;single-line-reformat result
		result
	]

	map-to-json-object: func [map [map!] /local result sep][
		indent
		result: copy "{^/"
		foreach word words-of map [
			append result rejoin [
				dent red-to-json-name :word " "
				red-to-json-value map/:word ",^/"
			]
		]
		outdent
		append clear any [find/last result ","  tail result] rejoin ["^/" dent "}"]
		;single-line-reformat result
		result
	]

	set 'to-json function [
		[catch]
		"Convert red data to a json string"
		data
	][
		result: make string! 4000	;!! factor this up from molded data length?
		foreach value compose/only [(data)] [
			append result red-to-json-value value
		]
		result
	]

	decode-unicode-char: func [ch [string!] "4 hex digits"][
		buf: {#"^^(0000)"}								; Don't COPY buffer, reuse it
		if not parse ch [4 hex-char] [return none]		; Validate input data
		attempt [load head change at buf 5 ch]
	]

	replace-unicode-escapes: func [s [string!] "(modified)" /local c][
		parse s [
			any [
				some chars
				| json-escaped
				| change ["\u" copy c 4 hex-char] (decode-unicode-char c)
			]
		]
		s
	]
	;str: {\/\\\"\uCAFE\uBABE\uAB98\uFCDE\ubcda\uef4A\b\f\n\r\t`1~!@#$%&*()_+-=[]{}|;:',./<>?}
	;mod-str: esc-json-to-red json-ctx/replace-unicode-escapes copy str
	;mod-str: json-ctx/replace-unicode-escapes esc-json-to-red copy str
	
;	    single-line-cleanup: function [string][
;	    	table: ["{ " "{"  "[ " "["  " }" "}"  " ]" "]"]		; From/To Old/New Dirty/Clean values
;	    	dirty:  ["{ " | "[ " | " }" | " ]"]
;	    	translit string dirty table
;	    ]
;	    ;print mold single-line-cleanup "{ a [ b { c } d ] f }"
;	    
;		single-line-reformat: function [
;			"Reformats a block/object to a single line if it's short enough."
;			val
;		][
;			either 80 >= length? join dent s: trim/lines copy val [
;				single-line-cleanup s
;			][val]
;		]
	
]

