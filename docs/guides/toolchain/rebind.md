# Rebind a prebuilt image's imports

A prebuilt armv7 image can import a symbol the checked release does not export, while a Backports library of the build does export it. The import check refuses that image, because a weak import of the symbol is NULL on the release and a strong one stops it from loading there. `revenant.rebind` moves those imports to the Backports library, so the image binds to the copy that carries the symbol instead.

The motivating case is Classicgram's `libTGCallsEngine.dylib`, which weakly imports `_AVAudioSession…` constants from AVFoundation, and the libSystem function `___darwin_check_fd_set_overflow`. The iOS 6.1.3 release leaves them NULL. `libAVFoundationBackports.dylib` exports the constants, and `libSystemBackports.dylib` exports the function.

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
4. The bind stream is re-encoded with the new ordinals and placed where the old one ended, ahead of the export trie, so that `__LINKEDIT` stays contiguous.
5. A lazy bind keeps its place when its new ordinal fits the one-byte form, which is ordinals 1 to 15. Otherwise it cannot keep its length, because the stub holds the offset of its entry. Its bind then moves to the bind stream, which dyld applies at load, and its lazy entry is zeroed. A stub whose entry is zeroed is never reached, because its pointer is bound before the image runs.
6. The code signature is dropped, and the app's signing step signs the image with `ldid` after the rebind.
7. The import check then runs on the rebound image against the release.

An import the release exports is left as it is. A named image with no import the release lacks is reported as a warning, and nothing is changed.

## The Backports libraries it uses

`libSystemBackports.dylib` is the Darwin-level library of the package. Its one symbol, `__darwin_check_fd_set_overflow`, is the bounds check that the SDK's `FD_SET`, `FD_CLR` and `FD_ISSET` call. The SDK declares it for iOS 14 and later, and calls it only when its address is not NULL. On iOS 6 that address is NULL, so `FD_SET` runs unchecked.

The library defines the symbol, and it forwards to the system's definition when libSystem has one, looked up with `dlsym` on the libSystem handle. Otherwise it returns nonzero for a descriptor in `[0, FD_SETSIZE)` and zero outside it, so an out-of-range descriptor makes `FD_SET` a no-op rather than a write past the set. The SDK header does not document its third argument, so the library accepts it and ignores it.

`FoundationBackports` names `SystemBackports` as a dependency, so a target that depends on FoundationBackports, directly or through a library that does, has the library in its provided set. A target with no such dependency needs one for the rebind to see the library.

## Limits

The rebind refuses an image, and leaves the file untouched, when:

- the image is not a thin 32-bit armv7 Mach-O, or it is a flat-namespace image: a flat image names no library for an import;
- it has no `LC_DYLD_INFO`, no `__LINKEDIT` or no symbol table;
- `__LINKEDIT` does not run to the end of the file, or the code signature is not the last part of it;
- its header has no room for the new load command: the error says so, and the fix is to relink the image with `-Wl,-headerpad,0x1000` or a larger value;
- the bytes between its load commands and its first section are not padding;
- a moved import is not in the image's symbol table, or a bind to it is flat;
- a lazy bind's stream does not end in DONE, so its entry cannot be found.

The rebind changes only the armv7 slice of an image, so a universal image is refused until its slices are split. The arm64 slice is not exercised.

## Classicgram

Classicgram's `libTGCallsEngine.dylib` is a prebuilt image. Measured on a copy of a Classicgram armv7 build of `Telegram.app`, against the iOS 6.1.3 cache and the libraries this worktree builds: the image has 1,776 bytes of header room, and the new load command needs 100 bytes. The rebind moves four imports the release does not export: the three weak AVFoundation imports (`_AVAudioSessionMediaServicesWereLostNotification`, `_AVAudioSessionSilenceSecondaryAudioHintNotification` and `_AVAudioSessionSilenceSecondaryAudioHintTypeKey`) to `libAVFoundationBackports.dylib`, and the weak libSystem import `___darwin_check_fd_set_overflow` to `libSystemBackports.dylib`. After the rebind and signing, the import check passes for the app's images and the provided libraries together, with no waiver.

The image also has `__availability_version_check`, a weak libSystem import. The import check reports it as a warning, not a refusal. The toolchain's guarded table explains it: compiler-rt's `__isPlatformVersionAtLeast` tests the pointer before it calls it, and below the release that has the function it reads the version from SystemVersion.plist. That guard was not confirmed in this binary, because the helper is stripped and the tools used here do not show its callers. So the warning stands as explained, and it is not carried.

The app-side lines are:

```lua
target("Classicgram")
    set_values("revenant.rebind", "Frameworks/libTGCallsEngine.dylib")
```

No waiver is set. The rebind of this image has been measured on a copy, not on a device.
