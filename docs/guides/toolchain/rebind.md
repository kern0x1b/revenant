# Rebind a prebuilt image's imports

A prebuilt armv7 image can import a symbol the checked release does not export, while a Backports library of the build does export it. The import check refuses that image, because a weak import of the symbol is NULL on the release and a strong one stops it from loading there. `revenant.rebind` moves those imports to the Backports library, so the image binds to the copy that carries the symbol instead.

The motivating case is Classicgram's `libTGCallsEngine.dylib`, which weakly imports `_AVAudioSession…` constants from AVFoundation. The iOS 6.1.3 release leaves them NULL, and `libAVFoundationBackports.dylib` exports them.

## Declare the image

Name the image in the app target, by its path in the bundle as the bundle has it:

```lua
target("Classicgram")
    set_values("revenant.rebind", "Frameworks/libTGCallsEngine.dylib")
```

The value is a bundle-relative path, and the bundle must hold that image. A name that matches no image in the bundle is refused. The declaration is explicit so that no other image changes: the build does not rebind any image that is not named.

Only an app bundle takes `revenant.rebind`. A tweak or a daemon is refused, because its libraries are placed under its package root and nothing rebinds them there yet.

## What the rebind does

When the app is packaged, after the libraries are copied into `Frameworks/` and their install names are retargeted, the named image is rebound in place in that copy:

1. Each import the release does not export is moved to the Backports library of the build that exports it. The provider is installed at `/usr/lib/revenant/org.revenant.backports/<name>`.
2. An `LC_LOAD_DYLIB` for that provider is added to the image's load commands, unless the image already names it.
3. The two-level ordinal of each moved import is changed to the provider's ordinal. The symbol names do not change.
4. The bind stream is re-encoded with the new ordinals and placed where the old one ended, ahead of the export trie, so that `__LINKEDIT` stays contiguous. A lazy bind keeps its place, and only its ordinal is changed in place.
5. The code signature is dropped, and the app's signing step signs the image with `ldid` after the rebind.
6. The import check then runs on the rebound image against the release.

An import the release exports is left as it is. A named image with no import the release lacks is reported as a warning, and nothing is changed.

## Limits

The rebind refuses an image, and leaves the file untouched, when:

- the image is not a thin 32-bit armv7 Mach-O, or it is a flat-namespace image: a flat image names no library for an import;
- it has no `LC_DYLD_INFO`, no `__LINKEDIT` or no symbol table;
- `__LINKEDIT` does not run to the end of the file, or the code signature is not the last part of it;
- its header has no room for the new load command: the error says so, and the fix is to relink the image with `-Wl,-headerpad,0x1000` or a larger value;
- the bytes between its load commands and its first section are not padding;
- a moved import is not in the image's symbol table, or a bind to it is flat;
- a lazy bind to a moved import cannot be encoded in its place, because a lazy bind is reached by the offset its stub holds.

The rebind changes only the armv7 slice of an image, so a universal image is refused until its slices are split. The arm64 slice is not exercised.

## Classicgram

Classicgram's `libTGCallsEngine.dylib` is a prebuilt image, so its header room is set when it was linked. If the packaging step refuses it for header room, the prebuilt has to be relinked with `-Wl,-headerpad,0x1000` before it is named here. The rebind of that image has not been run against the real binary; the host tests cover a synthetic armv7 image with the same imports.

The app-side lines are:

```lua
target("Classicgram")
    set_values("revenant.rebind", "Frameworks/libTGCallsEngine.dylib")
```

Keep the `weak-imports` check on. The rebind removes the NULL weak import, so the check passes on the rebound image without a waiver. See [Checks and waivers](checks.md).
