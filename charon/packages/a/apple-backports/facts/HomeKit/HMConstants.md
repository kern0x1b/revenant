# HomeKit's string constants

Every `NSString *const` the HomeKit headers declare is a value the release holds, not a name the
header invents: the accessory category a light bulb belongs to is the HAP UUID
`57D56F4D-3302-41F7-AB34-5365AA180E81`, the service type of a light bulb is
`00000043-0000-1000-8000-0026BB765291`, and the metadata format of a boolean characteristic is the
string `bool`. None of that is derivable from the name, and a porter who writes it from the name gets
a value that looks right and pairs with nothing. So all 255 of them are read out of a real
HomeKit.framework, one value per symbol, and written down here.

## How each value is measured, and how to re-measure it

**The tool is in the tree: `tools/corpus/host-probe.c`.** It opens a framework with `dlopen`, looks a
name up with `dlsym`, and decodes the `NSString *const` it finds through `CFStringGetCString` as
UTF-8, sized by the string's own `CFStringGetLength`. Run it over the 255 names against the host's own
HomeKit:

```
$ xcrun clang -framework CoreFoundation -o host-probe tools/corpus/host-probe.c
$ host-probe /System/Library/PrivateFrameworks/HomeKit.framework/Versions/A/HomeKit names.txt
asked 255, 0 not exported, 0 not a CFString
```

**255 asked, 255 exported, 255 agreeing with the values the port carries, 0 differing, 0 unreadable.**
The output is `coordination/corpus/ledger/constant-values-HomeKit.tsv`, in the same seven columns as
the other bands' `constant-values-*.tsv`, so it diffs against them.

Two things about the walk are worth stating, because both were wrong at first and both were found by
running it:

- **Sizing is `CFStringGetLength`, not a two-call `CFStringGetCString`.** Asked with a null buffer,
  `CFStringGetCString` does not answer a length — it fails — and an early version of the tool read
  that as "not a CFString" for all 255 while the same walk in Objective-C read every one of them.
- **There is deliberately no `CFGetTypeID` test before the conversion.** The `isa` pointer inside a
  constant string in a dyld shared cache is stored with the cache's own fixups, so that test answers
  "not a CFString" for every value in a shared-cache framework. The conversion reads the same object
  correctly, and the length it reports is the check that stays: a wrong address is a failed
  conversion, not a plausible wrong answer.

**The release half is a different measurement by a different tool**, and this document used to blur
the two. Which iOS release first exports a symbol is measured by `tools/release-split.lua`, which is
in the tree and walks the real cache ladder; the band machinery places an object by that measurement,
which is why the constant files are named for it. The values themselves are Apple's, and the host's
copy is the one this delivery checks them against.

## The two releases that changed a value

`HMServiceTypeMicrophone` and `HMServiceTypeSpeaker` are the two, and both are a real change of
Apple's rather than a difference of reading:

| constant | 8.4.1 armv7s | 10.3.4 armv7s | 12.0 arm64 | 16.0 / 18.0 |
| --- | --- | --- | --- | --- |
| `HMServiceTypeMicrophone` | `00000046-0000-1000-8000-0026BB765291` | `00000112-0000-1000-8000-0026BB765291` | `00000112-…` | `00000112-…` |
| `HMServiceTypeSpeaker` | `00000048-0000-1000-8000-0026BB765291` | `00000113-0000-1000-8000-0026BB765291` | `00000113-…` | `00000113-…` |

The later value is what the port carries, for the same reason the rest of the surface carries SDK
26.2's value: an application built against 26.2 compares against what 26.2 exports. The 8.4.1 value is
recorded here rather than dropped, because it is what a release this port runs on would have paired
against, and the difference is a fact about the protocol rather than about the reader.

## Where the header's availability is later than the release that exports it

The files are named for the release `tools/release-split.lua` **measures** as the first that exports
each symbol, because that is what the band machinery places an object by, and not for the release the
26.2 header annotates. For 63 of the 255 the two differ, and in every case the header is the later of
the two: a release already exported the symbol before the SDK says it arrived. The measurement is what
the band needs, so the port follows the measurement and records the difference here, which is what
COORDINATION.md's "the header can be wrong" is about. What is carried is the value every one of these
releases agrees on, so the choice of file changes which release carries the symbol, never its value.

| the header says | the release first exporting it | how many |
| --- | --- | --- |
| 10.0 | 8.0 | 2 |
| 8.0 | 9.0 | 2 |
| 10.0 | 10.0.1 | 21 |
| 18.0 | 10.0.1 | 1 |
| 11.0 | 10.3.4 | 1 |
| 18.0 | 11.0 | 2 |
| 11.2 | 12.0 | 12 |
| 18.0 | 12.0 | 1 |
| 18.0 | 13.4 | 19 |
| 18.0 | 16.0 | 2 |

The full list, one name per row, is in the delivery report; the two that change a band boundary by
more than a patch release are `HMServiceTypeMicrophone` and `HMServiceTypeSpeaker`, whose values also
changed, above.

## Where the release itself holds a placeholder

Eleven of the values are the symbol's own name, and that is Apple's, measured in all three caches:

    HMActionSetTypeHomeArrival  = HMActionSetTypeHomeArrival
    HMActionSetTypeSleep        = HMActionSetTypeSleep
    HMCharacteristicPropertyWritable = HMCharacteristicPropertyWritable
    HMErrorDomain              = HMErrorDomain

This is not the port filling in a name. HomeKit's action set types, its characteristic property names
and its error domain are opaque identifiers to every implementation, including Apple's: the release
stores the name as the string, and comparisons in the framework use pointer identity or the same
literal. The port stores what the release stores, and the length field agreeing with the bytes is the
check that this is a real value and not a misread.

## The three iOS 26.2 constants of AuthenticationServices

`ASGeneratedPasswordKindStrong`, `ASGeneratedPasswordKindAlphanumeric` and
`ASGeneratedPasswordKindPassphrase` arrived in iOS 26.2, which no firmware this machine holds — and no
dyld cache on it — ships. The host's own **macOS 27.0** does carry them, though, and they were read
out of its `AuthenticationServices.framework` with `dlsym`: the symbol's own pointer, then the
`__CFConstantString`'s `char *` at +16 and its length at +24, with the bytes at that address agreeing
with the length in all three (`STRONG`, 6 of 6; `ALPHANUMERIC`, 12 of 12; `PASSPHRASE`, 10 of 10).

So the earlier answer here — that there was nothing to read them from and the port would not invent
them — was right about not inventing them and wrong about there being nothing to read. The three are
carried, with the value the host's own framework gives, in
`facts/AuthenticationServices/ASConstants.md`.

## What this does not cover

The 324 `header-ok` rows of HomeKit's constant surface are enum cases, which need no symbol by
construction, and the 63 enum types likewise; the ledger's own `header-ok` says so and this file adds
nothing to it.

The model — `HMHome`, `HMRoom`, `HMAccessory` and the rest — is a separate family and is not in this
delivery. `CharonHomeKitStore.m` and `CharonHAPBignum.m` are here because they are what the model and
the HAP transport are written on, and both are the port's own symbols, so no band drops them.
