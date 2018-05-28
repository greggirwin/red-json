Old things are included here for reference. The wallet code has a minimal JSON
parser, which is the most modern version. The most value here may come from
the test files.

Red should get a basic GC before too long, so I don't think it's worth the
effort to avoid allocations on those grounds.

Once the core works, the big difference from Rebol is that we have `load/as`
and `save/as` that work with `system/codecs` (see %red/environment/codecs/)
rather than just creating `to-json/load-json` global funcs.

# Testing

- %_json-console.red      Interactive testing for small JSON strings
- %_parse-test-file.red   Select one JSON file to test
- %_run-test-suite.red    Run Red tests against all test files
- %_run-test-suite.r      Run R2 tests against all test files

# Other versions

- https://github.com/red/wallet/blob/master/libs/JSON.red

- %json.r                 Official R2 JSON library
- %json.red               Beginning of %json.r port to Red
- %chris-rg-json.r3       Chris Ross-Gill's R3 version
- %kaj-json.red           Kaj de Vos
- %wise-genius-json.red   WiseGenius's Red version

- https://github.com/rgchris/Scripts/blob/master/red/altjson.red
