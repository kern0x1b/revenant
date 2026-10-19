# The six geometry UT types ModelIO's header declares

## What they are and where they come from

`MDLTypes.h` of the SDK 16.4 this package compiles against declares six exported data symbols, one per
geometry file type ModelIO reads:

| symbol | line | `API_AVAILABLE` |
| --- | --- | --- |
| `kUTTypeAlembic` | MDLTypes.h:17 | ios(9.0) |
| `kUTType3dObject` | MDLTypes.h:20 | ios(9.0) |
| `kUTTypePolygon` | MDLTypes.h:23 | ios(9.0) |
| `kUTTypeStereolithography` | MDLTypes.h:26 | ios(9.0) |
| `kUTTypeUniversalSceneDescription` | MDLTypes.h:29 | ios(10.0) |
| `kUTTypeUniversalSceneDescriptionMobile` | MDLTypes.h:32 | ios(14.0) |

They arrive at four different releases, so they are four objects in this package and not one:
`ModelIO/MDLTypes9.m` (the four at 9.0), `ModelIO/MDLTypes10.m` (the scene description at 10.0) and
`ModelIO/MDLTypes14.m` (the mobile scene description at 14.0). An object carries the API of one
release, which is the rule `release-split.lua` reads off the held caches, and a band at or above a
name's own release already exports it and drops ours.

## The values, measured off the host's own symbols

There is nothing to guess here and nothing was: each value is the text the host's own
`ModelIO.framework` holds at that symbol, read through `dlsym` off the loaded image and printed with
`CFStringGetCString`. The harness is `tests/backports/host/modelio/uttypes.c`, and it is runnable:

```
$ cc -o /tmp/uttypes uttypes.c -framework CoreFoundation && /tmp/uttypes
kUTTypeAlembic                                 public.alembic
kUTType3dObject                                public.geometry-definition-format
kUTTypePolygon                                 public.polygon-file-format
kUTTypeStereolithography                       public.standard-tesselated-geometry-format
kUTTypeUniversalSceneDescription               com.pixar.universal-scene-description
kUTTypeUniversalSceneDescriptionMobile         com.pixar.universal-scene-description-mobile
```

Two of these are worth naming, because the obvious spelling is the wrong one and only the
measurement settles it:

- `kUTType3dObject` is **`public.geometry-definition-format`**, not `public.3d-object`. The
  `public.3d-content` identifier is a different symbol entirely - `kUTType3DContent`, which
  `CoreServices/CoreServicesNames80.m` already carries for the 8.0 band.
- `kUTTypeStereolithography` is **`public.standard-tesselated-geometry-format`** (one `l` in
  "tesselated"), which is the IANA name Apple registered and the one its own symbol holds.

## Why the release cannot answer these

The 6.1.3 armv7 cache exports none of the six, and neither does any other release below 9.0, so an
application that names one is killed by dyld before its `main`. The 9.0 band is the first that has
`kUTType3dObject`, `kUTTypeAlembic`, `kUTTypePolygon` and `kUTTypeStereolithography` from the
release, the 10.0 band the first with `kUTTypeUniversalSceneDescription`, and the 14.0 band the first
with `kUTTypeUniversalSceneDescriptionMobile`; below each of those the port's own object carries it.
That is the `minimum`/`introduced` pair each registry row states.

## The host differential this does NOT rest on

`tests/backports/host/modelio/uttypes.c` is a **measurement**, not a differential: it prints what the
host holds and the port's values are read off that output by eye and written into the three objects.
The harness exists so the reading can be repeated, not so the port's answers are compared with the
host's in one process - the two symbol sets collide by name, so a process holding both would answer
one for the other. That is the same reason `tests/backports/host/gameplaykit-noise` splits into
`measure.m` and `differential.m`, and the comment in its `run.sh` says why.
