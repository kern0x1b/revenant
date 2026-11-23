# Stubs: the Backports members an app can reach that abort

A stub is the body that the skeleton gives an SDK member that nothing implements: it prints `not implemented: <member>` and
calls `abort()`. The abort stays, and no stub returns a quiet value, because a quiet value hides the gap. A stub that an
application calls therefore ends the application, and on a phone that is a crash of the owner's app.
`frameworks/Backports/tools/stubs.lua` finds those stubs on a Mac, with no phone, and a checked-in snapshot keeps a new one
from passing unnoticed.

## What a dangerous stub is

A stub is dangerous when all four hold:

1. The skeleton holds it (`build/generated/backports/skeleton/<Framework>.m`, the table `revenant_methods`).
2. iOS 6.1.3 does not answer it. The answer is read from the dyld cache inventory (`.cache/dyld/6.1.3/classes_armv7.json`):
   the class or a superclass lists the selector; a class the device lacks answers what `NSObject` answers; and a class that
   replaces `+alloc` (a class cluster: `UILocalNotification`, `NSString`) also answers what its concrete subclasses answer,
   because the instance the app holds is one of them.
3. No Backports source lowers it (`frameworks/Backports/tools/lowered-members.txt`). The setter of a lowered property
   counts as lowered, because the list names a property by its getter. The skeleton still holds a stub for a member that a
   source implements, and the registrar skips it when the class answers at load, so the skeleton alone cannot say.
4. The application names it: its class is imported by one of the application's images and its selector is in that image's
   `__objc_selrefs`. Swift emits a selref for every Objective-C call, property access included.

The fourth condition is the narrow one, and the tool says what it cannot see:

- A class that the application gets from another call's return value is not imported, so a stub on it is not named.
- A selector that the application builds at run time (`NSSelectorFromString`, `performSelector:`) is not in a selref.
- A name found is a call that the application may make, not one it makes. Whether a path is reached on a given start is
  not known from the binary.
- A name that the application's source guards with `#available(iOS N, *)` is only a runtime check once the application is
  built for iOS 6, so the guarded call is skipped there. The SDK's introduction version separates the two groups: an API
  newer than the application's own minimum cannot be unguarded in its source (`minimum` in the snapshot, 15 for
  Telegram 13). The check enforces only an API introduced at or below the minimum, or one whose version the facts do not
  know.

## The snapshot, the allowed list and the check

`frameworks/Backports/tools/app-stubs/<App>.snapshot` holds, for one application, every stub of conditions 1, 2 and 4, with
the SDK introduction version of each (`7000` is iOS 7.0), whether or not a source now lowers it. Telegram13's holds the
union of Postbox, SwiftSignalKit, MtProtoKit, TelegramCore and TelegramUI. Conditions 1, 2 and 4 do not change until the
application or the iOS 6.1.3 inventory does, so the snapshot is a fixed input, and the check applies the one condition that
does change, number 3, to it.

`frameworks/Backports/tools/app-stubs/allowed.txt` lists the dangerous stubs that are known and not yet implemented, one
per line, `<sign><Class>\t<selector>\t<reason>`:

- `backlog`: nothing implements it yet. It is a gap, listed so that the check passes while it is closed.
- `device`: iOS 6.1.3 answers it in a way the inventory cannot see (a method resolved at run time). Use it only for a
  member measured on the emulator.

The check, `./xmakew l -P . frameworks/Backports/tools/stubs.lua check`, fails on:

- a dangerous stub that no source lowers and the list does not allow: a new gap. It appears when a source is deleted, when
  a lowered member leaves `lowered-members.txt`, or when a new snapshot names a member the earlier one did not;
- a stale entry: a listed member that a source now lowers, or that no snapshot names any more. The list only shrinks, so
  the entry is deleted when the work lands.

`frameworks/Backports/tests/stubs_test.lua` runs the check on the checked-in data, and runs the rules on a synthetic
skeleton, inventory, facts folder and lowered list. It is in the `backports` test group, and it is the prepush step
`stubs check` (`tools/prepush.lua`), keyed by the tool, the snapshots, the lowered list and the test, so inputs that did
not change do not run it twice. It also removes `secondaryAudioShouldBeSilencedHint`, the member that aborted Telegram13 on the 4S, from the lowered list
and requires the check to name it, so that the check is shown to catch the case it was written for.

## Close a gap

Implement the member natively in `frameworks/Backports/src/<Framework>/`, where the framework is the one whose skeleton
holds the stub (a stub of `AVAudioSession` is in `AVFAudio.m`, so its source is in `src/AVFAudio`, the library that carries
the stub). Regenerate `frameworks/Backports/tools/lowered-members.txt` (`./xmakew l -P . frameworks/Backports/tools/lowered_members.lua`)
and the recipe digests (`./xmakew l -P . toolchain/tools/recipe_digests.lua`), delete the line from `allowed.txt`, and run
the check. Do not close a gap by editing the snapshot: it is a measurement, and an edit makes the next check lie.

## Refresh a snapshot

Run it when a new application build is the one to protect, or when the iOS 6.1.3 inventory changes:

```sh
./xmakew l -P . frameworks/Backports/tools/generate.lua
./xmakew l -P . frameworks/Backports/tools/stubs.lua snapshot --app Telegram13 \
    --out frameworks/Backports/tools/app-stubs/Telegram13.snapshot \
    --binary PostboxFramework --binary SwiftSignalKitFramework --binary MtProtoKitFramework \
    --binary TelegramCoreFramework --binary TelegramUIFramework --minimum 15
```

Each `--binary` is a Mach-O image of the application (armv7). The skeleton defaults to `build/generated/backports/skeleton`,
the inventory to `.cache/dyld/6.1.3/classes_armv7.json`, and the SDK facts to the shared Backports cache of the SDK in use;
`--skeleton`, `--inventory` and `--facts` name others. The command reads each image's selrefs through
`toolchain/modules/apple/objc.lua` and its imported classes with `grep -a -o` over the image's `_OBJC_CLASS_$_` symbols:
`nm -u` takes ten minutes of CPU on the 135 MB TelegramUI image, and `grep` takes under three seconds.

New entries in the refreshed snapshot appear as violations in the next check. Read each one, implement it or list it with
its reason, and say in the commit what the new application build added.

## Cost

The check reads the lowered list (about 38 thousand lines, 25 thousand of them `member` lines, the only ones it uses) and a snapshot (about two thousand), and takes about a second. A
refresh takes the skeleton generation (about three minutes on a cold facts cache) and, for TelegramUI, under ten seconds of
reading.
