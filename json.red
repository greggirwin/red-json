Red [
	File:    %json.red
	Title:   "Red-JSON codec"
	Purpose: "Convert json to Red, and vice versa."
	Author:  [
		"Gregg Irwin" {
			Ported from %json.r by Romano Paolo Tenca, Douglas Crockford, 
			and Gregg Irwin.
			Further research: json libs by Chris Ross-Gill, Kaj de Vos, and
			@WiseGenius.
		}
	]
	;Date: 	 10-Jul-2016
	Version: 0.0.1
	History: {
		0.0.1 10-Sep-2016 "First release. Based on %json.r" Gregg
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
		https://github.com/rebolek/red-tools/blob/master/json.red
	]
	Notes: {
		NOT FULLY FUNCTIONAL YET!!
		
		- Ported from %json.r, by Romano Paolo Tenca, Douglas Crockford, and Gregg Irwin.
		- Further research: JSON libs by Chris Ross-Gill, Kaj de Vos, and @WiseGenius.
		
		? Do we want to have a single context or separate encode/decode contexts?
		? Do we want to use a stack with parse, or recursive load-json/decode calls?

		- Unicode support is in the works.
		- Pretty formatting from %json.r removed. Determine what formatting options we want.

		- Would like to add more detailed decode error info.
			- JSON document is empty.
			- Invalid value.
			- Missing name for object member.
			- Missing colon after name of object member.
			- Missing comma or right curly brace after object member.
			- Missing comma or ] after array element.
			- Invalid \uXXXX escape.
			- Invalid surrogate pair.
			- Invalid backslash escape.
			- Missing closing quotation mark in string.
			- Numeric overflow.
			- Missing fraction in number.
			- Missing exponent in number.
	}
]

json-ctx: object [

	;-----------------------------------------------------------
	;-- Generic support funcs

	BOM: [
		UTF-8		#{EFBBBF}
		UTF-16-BE	#{FEFF}
		UTF-16-LE	#{FFFE}
		UTF-32-BE	#{0000FEFF}
		UTF-32-LE	#{FFFE0000}
	]

	BOM-UTF-16?: func [data [string! binary!]][
		any [find/match data BOM/UTF-16-BE  find/match data BOM/UTF-16-LE]
	]

	BOM-UTF-32?: func [data [string! binary!]][
		any [find/match data BOM/UTF-32-BE  find/match data BOM/UTF-32-LE]
	]


	; MOLD adds quotes string!, but not all any-string! values.
	enquote: func [str [string!] "(modified)"][append insert str {"} {"}]

	high-surrogate?: func [codepoint [integer!]][
        all [codepoint >= D800h  codepoint <= DBFFh]
    ]
    
	low-surrogate?: func [codepoint [integer!]][
        all [codepoint >= DC00h  codepoint <= DFFFh]
    ]
    
;	map-each: function [
;		"Evaluates body for each value in a series, returning all results."
;		'word [word! block!] "Word, or words, to set on each iteration"
;		data [series!] ; map!
;		body [block!]
;	][
;		collect [foreach :word data [keep/only do body]]
;	]
	
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

	;-----------------------------------------------------------
	;-- JSON backslash escaping

	;TBD: I think this can be improved. --Gregg
		
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
	
	json-esc-ch: charset {"t\/nrbf}             ; Backslash escaped JSON chars
	json-escaped: [#"\" json-esc-ch]			; Backslash escape rule
	red-esc-ch: charset {^"^-\/^/^M^H^L}        ; Red chars requiring JSON backslash escapes

	decode-backslash-escapes: func [string [string!] "(modified)"][
		translit string json-escaped json-to-red-escape-table
	]

	encode-backslash-escapes: func [string [string!] "(modified)"][
		translit string red-esc-ch red-to-json-escape-table
	]

	;ss: copy string: {abc\"\\\/\b\f\n\r\txyz}
	;decode-backslash-escapes string
	;encode-backslash-escapes string
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
	;not-low-ascii-char: charset [not #"^(00)" - #"^(127)"]
	;not-ascii-char: charset [not #"^(00)" - #"^(255)"]

	; everything but \ and "
	; Defining it literally this way, rather than a [NOT charset] rule, takes ~70K
	; Need to see if it's faster one way or the other. 
;	unescaped-char: charset [
;		#"^(20)" - #"^(21)"					; " !"
;		#"^(23)" - #"^(5B)"					; #$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[
;		#"^(5D)" - #"^(10FFF)"				; ]^^_`abcdefghijklmnopqrstuvwxyz{|}~  ...U+
;	]

	;-----------------------------------------------------------
	;-- JSON value rules
	;-----------------------------------------------------------
	
	;-----------------------------------------------------------
	;-- Number
	sign: [#"-"]
	; Integers can't have leading zeros, but zero by itself is valid.
	int:  [[non-zero-digit any digit] | digit]
	frac: [#"." some digit]
	exp:  [[#"e" | #"E"] opt [#"+" | #"-"] some digit]
	number: [opt sign  int  opt frac  opt exp]
	numeric-literal: :number
	
	;-----------------------------------------------------------
	;-- String
	string-literal: [
		#"^"" copy _str [
			any [some chars | #"\" [#"u" 4 hex-char | json-esc-ch]]
		] #"^"" (
			if not empty? _str: any [_str copy ""] [
				;!! If we reverse the decode-backslash-escapes and replace-unicode-escapes
				;!! calls, the string gets munged (extra U+ chars). Need to investigate.
				decode-backslash-escapes _str			; _str is modified
				replace-unicode-escapes _str			; _str is modified
				;replace-unicode-escapes decode-backslash-escapes _str
			]
		)
	]

	decode-unicode-char: func [
		"Convert \uxxxx format (NOT simple JSON backslash escapes) to a Unicode char"
		ch [string!] "4 hex digits"
	][
		buf: {#"^^(0000)"}								; Don't COPY buffer, reuse it
		if not parse ch [4 hex-char] [return none]		; Validate input data
		attempt [load head change at buf 5 ch]			; Replace 0000 section in buf
	]

	replace-unicode-escapes: func [
		s [string!] "(modified)"
		/local c
	][
		parse s [
			any [
				some chars								; Pass over unescaped chars
				| json-escaped							; Pass over simple backslash escapes
				| change ["\u" copy c 4 hex-char] (decode-unicode-char c)
				;| "\u" followed by anything else is an invalid \uXXXX escape
			]
		]
		s
	]
	;str: {\/\\\"\uCAFE\uBABE\uAB98\uFCDE\ubcda\uef4A\b\f\n\r\t`1~!@#$%&*()_+-=[]{}|;:',./<>?}
	;mod-str: decode-backslash-escapes json-ctx/replace-unicode-escapes copy str
	;mod-str: json-ctx/replace-unicode-escapes decode-backslash-escapes copy str
	
	;-----------------------------------------------------------
	;-- Object		
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
	
	;-----------------------------------------------------------
	;-- List
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

	;-----------------------------------------------------------
	;-- Any JSON Value (top level JSON parse rule)
	json-value: [
		ws*
		[
			"true"    (emit true)							; Literals must be lowercase
			| "false" (emit false)
			| "null"  (emit none)
			| json-object
			| json-array
			| string-literal (emit _str)
			| copy _str numeric-literal (emit load _str)	; Number
			mark:   										; Set mark for failure location
		]
		ws*
	]

	;-----------------------------------------------------------
	;-- Decoder data structures

	; The stack is used to handle nested structures (objects and lists)
	stack: copy []
	push:  func [val][append/only stack val]
	pop:   does [take/last stack]
	

	_out: none	; Our overall output target/result                          
	_res: none	; The current output position where new values are inserted
	_str: none	; Where string value parse results go               
	mark: none	; Current parse position
	
	; Add a new value to our output target, and set the position for
	; the next emit to the tail of the insertion.
	;!! I really don't like how this updates _res as a side effect. --Gregg
	emit: func [value][_res: insert/only _res value]

	;-----------------------------------------------------------
	;-- Main decoder func

	set 'load-json func [
		[catch]
		"Convert a json string to Red data"
		input [string!] "The json string"
	][
		_out: _res: copy []		; These point to the same position to start with
		mark: input
		either parse input json-value [pick _out 1][
			make error! form reduce [
				"Invalid json string. Near:"
				either tail? mark ["<end of input>"] [mold copy/part mark 40]
			]
		]
	]


	;-------------------------------------------------------------------------------
	;-------------------------------------------------------------------------------
	;-------------------------------------------------------------------------------


	;-----------------------------------------------------------
	;-- JSON encoder
	;-----------------------------------------------------------

	; Indentation support, so we can make the JSON output look decent.
	dent: copy ""
	dent-size: 4
	indent:  does [append/dup dent #" " dent-size]
	outdent: does [remove/part dent dent-size]

	encode-char: func [
		"Convert a single char to \uxxxx format (NOT simple JSON backslash escapes)."
		char [char! string!]
	][
		if string? char [char: first char]
		;rejoin ["\u" to-hex/size to integer! char 4]
		append copy "\u" to-hex/size to integer! char 4
	]

;-------------------------------------------------------------------------------
;!! This is an optimization. The main reason it's here is that Red doesn't
;!! have a GC yet. Generating the lookup table once, and using that, prevents 
;!! repeated block allocations every time we encode a control character.
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
;-------------------------------------------------------------------------------

	encode-control-chars: func [
		"Convert all control chars in string to \uxxxx format"
		string [any-string!] "(modified)"
	][
		if find string ctrl-char [
			;translit string ctrl-char :encode-char			; Use function to encode
			translit string ctrl-char ctrl-char-esc-table	; Optimized table lookup approach
		]
		string
	]
	;encode-control-chars "^@^A^B^C^D^E^F^G^H^-^/^K^L^M^N^O^P^Q^R^S^T^U^V^W^X^Y^Z^[^\^]^(1E)^_ "


	; The reason this func does not copy the string is that a lot of
	; values will have been FORMed or MOLDed when they are passed to
	; it, so there's no sense in copying them again. The only time it's
	; a problem is for string values themselves.
	;TBD: Encode unicode chars?
	encode-red-string: func [string "(modified) Caller should copy"][
		encode-control-chars encode-backslash-escapes string
		;TBD translit string not-ascii-char :encode-char
	]

	red-to-json-name: func [val][
		append enquote encode-red-string form val ":"
	]

	; Types that map directly to a known JSON type.
	json-type!: union any-block! union any-string! make typeset! [
		none! logic! integer! float! percent! map! object! ; decimal!
	]
	
	
	red-to-json-value: func [val][
		;?? Is it worth the extra lines to make each type a separate case?
		;	The switch cases will look nicer if we do; more table like.
		switch/default type?/word :val [
			string!  [enquote encode-red-string copy val]	; COPY to prevent mutation
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
					enquote encode-red-string form val
				]
			]
		][
			either any-block? :val [block-to-json-list val] [
				; FORM forces binary! values to strings, so newlines escape properly.
				enquote encode-red-string either any-string? :val [form val] [mold :val]
			]
		]
	]

	;TBD: Eventually we should have a nice dlm string tool in Red. Is it worth
	;	  including our own for the list/object cases? 
	
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

	;-----------------------------------------------------------
	;-- Main encoder func

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

; Even if we don't do full pretty formatting of JSON, it might still be nice
; to do the single-line bit.

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

