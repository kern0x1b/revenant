# Tests

Run before every deploy, from the top of revenant:

    ./xmakew f -P . --webkit_host_tests=y && ./xmakew test -P .   ICU data checks on this Mac
    ./xmakew l frameworks/WebKit/tests/device/run-batteries.lua    JavaScript batteries under jsc on the iPhone

## host

`icu-sanity` opens the resource bundles, the time zone enumeration and every
character encoding the engine hands to ICU, against the same trimmed data the
phone ships. With `webkit_host_tests` on, configuring for this Mac requires the
`icu` package, built for this Mac by the same recipe and data filter as the phone's,
and `icu-sanity` and `icu-locales` are targets whose `add_tests` run them; the first
run builds ICU once and every later run reuses it.

The encoding list is not maintained by hand. `tools/required-encodings.lua` reads
it out of `TextCodecICU.cpp`, so it tracks the engine: everything else is
decoded by WebKit itself (`TextCodecCJK`, `TextCodecSingleByte`,
`TextCodecLatin1`, `TextCodecUTF8`) and needs nothing from ICU. Re-run it
after updating WebKit.

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

`tests/device/js/*.js` run under `jsc` on the phone with the freshly built engine:
`run-batteries.lua` takes the `batteries/` folder the `webkit-engine` package installs
(`jsc`, its `JavaScriptCore` and the C++ runtime it was built against), or the one
`--batteries` names. It compares each file with the phone's copy by content and pushes
the ones that differ, so the batteries never run against a stale engine. The phone is the
one `device.env` at the top of revenant names; with `DEVICE_UDID` set the device module
pins the USB tunnel to that phone, so a connected iPad cannot answer instead.

Each battery prints its own verdict line. A battery that produces no verdict is
a failure — it died partway through.

The batteries cover what the 32-bit JIT work touched: `correct.js` arithmetic,
strings, arrays and the modulo and double paths that the softfp ABI fix broke;
`poly.js` polymorphic inline caches; `coverage.js` Map/Set/iterator builtins;
`mapdfg.js` the Map and Set DFG intrinsics written by hand for 32-bit.

## TLS, on the phone

With the shim installed, Safari must refuse both of these. A page that loads means the shim is not verifying:

    https://self-signed.badssl.com    must show a certificate error
    https://expired.badssl.com        must show a certificate error

`https://badssl.com` has a valid certificate and must load, so a refusal above means the shim
and not a dead network.

## In a browser, by hand

Three pages measure the engine under a feed, which is the shape of page this
device is asked to render and the shape that used to be measured against a live
site - where the content changes between runs and every comparison is therefore
worthless.

    tests/device/enginebench.html            four timings: building a feed, megamorphic property
                                            access, allocation churn, forced relayout
    tests/device/membench.html              a long session's feed, built in batches, printing
                                            posts and document height as it grows
    tests/device/scrollbench.html           scrolling: the gap distribution between animation
                                            frames, not a mean
    tests/device/scrollbench-fixed-bars.html
                                            the same measurement under two position:fixed bars
                                            whose height changes while a feed grows during the
                                            run - the shape the fixed-bar flush race needs
    tests/device/fullscreentest.html        element.requestFullscreen() on a div, with a canvas
                                            that keeps drawing while fullscreen

`scrollbench.html` has two knobs, because the regime is part of what is
measured: `?posts=1400` puts the collector in the band a content-bearing feed
puts it in, and `?heap=40` retains forty megabytes of live objects in the shape
a component tree has. Its own DOM is 2.2 MB of heap even at 1400 posts, so
without them the collector never leaves its cheap band and the emergency policy
under test never engages.

