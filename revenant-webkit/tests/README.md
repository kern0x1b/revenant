# Tests

Run before every deploy: `charon test`

    charon test --tier host       ICU data checks on this Mac, seconds once ICU is built
    charon test --tier batteries  JavaScript batteries under jsc on the iPhone
    charon test                   every tier the declaration names

Charon installs what a tier declares it needs and hands it over, so the tiers
are run through it. The one direct call is the batteries against a tree Charon
does not manage: `ENGINE_BUILD=/path/to/build tests/run-tests.py`.

## host

`icu-sanity` opens the resource bundles, the time zone enumeration and every
character encoding the engine hands to ICU, against the same trimmed data the
phone ships. The `host` tier declares the `icu` package it needs in
`charon.toml`; Charon writes the recipe that asks for the version `conan.lock`
pins, builds it for this Mac with the recipe's own data filter, and tells the
tier where it landed, so the first run builds ICU once and every later run
reuses it.

The encoding list is not maintained by hand. `gen-required-encodings.py` reads
it out of `TextCodecICU.cpp`, so it tracks the engine: everything else is
decoded by WebKit itself (`TextCodecCJK`, `TextCodecSingleByte`,
`TextCodecLatin1`, `TextCodecUTF8`) and needs nothing from ICU. Re-run the
generator after updating WebKit.

`known-missing-encodings.txt` lists encodings ICU 74 genuinely does not ship, so
a real gap stays visible without failing the build.

`icu-locales` formats a relative time and a grouped number in 37 languages and
fails if any of them comes back in English, which is what a locale trimmed too
far looks like.

This half exists because a damaged ICU package still loads and then fails far
away from the cause: the last one surfaced on device as a SIGTRAP inside
`CommonIdentifiers::appendExternalName`, and took a full deploy cycle to trace.
The same fault takes two seconds to find here.

## device

`tests/js/*.js` run under `jsc` on the phone with the freshly built engine.
The engine comes from `ENGINE_BUILD`, or from the engine build Charon names:
the one tree directly under `build/` that is configured and has its frameworks
laid out under `stage/`. The port keeps no rule of its own for this. The runner
compares `jsc`, the C++ runtime and each framework with the phone's copy by
content and syncs the ones that differ, so the batteries never run against a
stale engine, and it pins the connection to the iPhone's UDID through iproxy so
a connected iPad cannot answer instead.

Requires `iproxy 2225:22 -u <iphone-udid> &`.

Each battery prints its own verdict line. A battery that produces no verdict is
a failure — it died partway through.

The batteries cover what the 32-bit JIT work touched: `correct.js` arithmetic,
strings, arrays and the modulo and double paths that the softfp ABI fix broke;
`poly.js` polymorphic inline caches; `coverage.js` Map/Set/iterator builtins;
`mapdfg.js` the Map and Set DFG intrinsics written by hand for 32-bit.

## In a browser, by hand

Three pages measure the engine under a feed, which is the shape of page this
device is asked to render and the shape that used to be measured against a live
site - where the content changes between runs and every comparison is therefore
worthless.

    tests/enginebench.html    four timings: building a feed, megamorphic property
                              access, allocation churn, forced relayout
    tests/membench.html       a long session's feed, built in batches, printing
                              posts and document height as it grows
    tests/scrollbench.html    scrolling: the gap distribution between animation
                              frames, not a mean
    tests/scrollbench-fixed-bars.html
                              the same measurement under two position:fixed bars
                              whose height changes while a feed grows during the
                              run - the shape the fixed-bar flush race needs
    tests/fullscreentest.html element.requestFullscreen() on a div, with a canvas
                              that keeps drawing while fullscreen

`scrollbench.html` has two knobs, because the regime is part of what is
measured: `?posts=1400` puts the collector in the band a content-bearing feed
puts it in, and `?heap=40` retains forty megabytes of live objects in the shape
a component tree has. Its own DOM is 2.2 MB of heap even at 1400 posts, so
without them the collector never leaves its cheap band and the emergency policy
under test never engages.

