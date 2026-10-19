# The default orthography of a language, iOS 11.0

`+[NSOrthography defaultOrthographyForLanguage:]` answers an orthography: a dominant script and the map
of the languages that share it. For a bare language code, the "default" is the script CLDR's
likely-subtags data names for that language, which is how `de` becomes Latin and `zh` becomes Han.

## The release already has that data and already computes with it

`uloc_addLikelySubtags` is exported by `/usr/lib/libicucore.A.dylib` in the 6.1.3 armv7 cache, measured
with `tools/corpus/cache-value.lua` (whose controls in the same run are `uloc_getDefault` and
`uloc_canonicalize`, also there). So the port asks the release's own ICU and parses its answer --
`de` gives `de_Latn_DE`, so the script is the field `uloc_getName(locale, "script")` names -- rather
than carrying a table of language-to-script pairs of its own. There is no generated data file here,
and none is needed: the mapping *is* the release's ICU data, which is where Apple's answer comes from
too.

The last step is the release's own `+[NSOrthography orthographyWithDominantScript:languageMap:]`,
which has been there since iOS 4.0 (its selector is in the 6.1.3 selector table), so the object the
caller gets is the system's.

A language the release's ICU has no likely subtags for answers a null error code, and then the
language's own name stands for its script -- an unknown language is its own script, which is what
`-dominantScript` says of a language no data names.

The device call is in `tests/backports/device/foundation15batch.m`; the host's own Foundation no longer
has `NSOrthography` (macOS 27 answers `+orthographyWithLanguage:` with an unrecognized selector), so
there is no host oracle for this row and the release's ICU is the oracle.
