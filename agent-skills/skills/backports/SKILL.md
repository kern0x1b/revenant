---
name: backports
description: Use API that later iOS releases added (UIStackView, layout anchors, UIAlertController, NSURLSession, NSURLComponents, UNUserNotificationCenter, WKWebView, Core Data's persistent container and more) in an app for an older release through Charon's `charon@apple-backports` — decide per API between a backport, the release's own older API and a version check; look the API up in the backports registry; choose the package's configs (uikit, corelocation, coredata, webkit and the rest); declare it in xmake.lua; read the build's warnings; know what the app's .deb then depends on. Use when the app's code needs an API newer than `apple_minimum`, when the build warns about weak imports or selectors the release lacks, or when `xmake deb` refuses one.
---

# Backports

The SDK the toolchain compiles against is a modern one (iOS 16), so its headers declare API the
target release does not have. What the device really exports is decided by that release's own
libraries, and Charon checks every import of the app against them. When the app needs an API
added after `apple_minimum`, there are three native answers, per API:

1. **A backport** — `charon@apple-backports` implements it for the older release, in libraries
   installed on the device by their own package. The app calls the API as if the release had it.
   A C call of the system library (`clock_gettime`, `dispatch_get_global_queue` with a class of
   service, …) comes instead from `charon@apple-compat`, linked into the app (skill `objc`).
2. **The release's own API** — the older way to do the same thing (for example `UIAlertView`
   instead of `UIAlertController` when the backport's behaviour is not what the app needs).
3. **A version check** — `respondsToSelector:`, `[Class class] != nil` in Objective-C,
   `#available` in Swift (a backport from Swift goes through the runtime's `backports` config,
   skill `swift` §5), and a path for the release that lacks it.

Never silence the check instead: no `-disable-availability-checking`, no
`charon.waive.weak-imports` to get a package through, no copying a system library into the app.
Read `PROJECT.md` first: `## Code` lists the backports and the API that needs each.

## 1. Look the API up

Every API the backports considered has an entry in their **registry**, and the build refuses a
backport without one. Once the package is required (step 3), its install holds the registry of
the pinned version:

```
xmake where apple-backports            # prints the install folder
<folder>/share/registry/<Framework>/*.json   (and <folder>/share/registry/<Framework>.json)
```

Before that, read the same files in the Charon repository at the pinned tag
(`packages/a/apple-backports/registry/` at `charon-repo-0.8.10` on GitHub, or in the project's
clone under `.xmake/<host>/<arch>/repositories/charon/` once `xmake f` has run). Search the API as
the app writes it: a class `UIStackView`, a method `+[NSLayoutConstraint activateConstraints:]`
or `-[UIView centerXAnchor]`, a property as `Class.property` (both accessors in one entry, e.g.
`UIScreen.captured`), a function `Name()`, a constant by its symbol. A property may also
appear by its getter, `-[Class property]`: search both spellings. `packages/a/apple-backports/README.md` beside it explains, release by release, what
is carried with a difference and what is refused and why.

An entry's `status` decides:

| `status` | What the app gets | What to do |
| --- | --- | --- |
| `implemented` | the real behaviour; the entry names its `facts` file when the package carries the behaviour itself, or its `source` when the release already has it | use it; read the `facts` file when the behaviour matters |
| `inert` | declared, does nothing, says so once in the device log | use only where doing nothing is acceptable to the user (a visual effect, haptics); tell them |
| `absent` | not there, and `respondsToSelector:` / `NSClassFromString` answer honestly (NO, nil); only a message a real object does not implement, or a compile-time reference to the class, crashes | the release's own API, or a version check with a fallback |
| `ignored` | the call reaches the release's own implementation, which answers `respondsToSelector:` with YES and does something else; `effect` says what | treat as absent for anything the app relies on |
| no entry | the package carries nothing of it (a value the header holds, such as an enum case, needs no entry: the compiler writes it into the app) | absent, unless it is such a header value |

`absent` is the default, not always a decision: it is required where quiet inaction would corrupt
data or mislead (security, saving, payment, permissions, the network), and elsewhere it may simply
not be written yet. `reason` says why an entry is `absent`, `effect` what the app sees instead.
Also read `minimum` (the entry is absent below that release — `UIStackView` needs 6.0) and
`maximum` (the entry becomes absent from that release on, where the system carries the class
itself). If `apple_minimum` is below `minimum`, the API is absent for the app.

An app's build does not print the registry's verdict for the APIs it calls (the `app` rule checks
the finished bundle, and that check does not read the registry): look every API newer than
`apple_minimum` up here yourself, and record each status in `PROJECT.md`.

## 2. Choose the configs

`libFoundationBackports.dylib` is always built. Every other library is a boolean config, named
after the source folder of the backport in `packages/a/apple-backports/<Folder>/` — find the file
that implements the class (`@implementation UIStackView` is in `UIKit/`), not the registry
folder, which follows the SDK's framework and can differ (`UNUserNotificationCenter` is
registered under `UserNotifications` and implemented in `UIKit/`).

At Charon 0.8.10: `uikit` (for an application; UIKit, layout anchors, stack views, alerts,
notifications), `corelocation`, `avfoundation`, `coredata`, `security`, `webkit` (WKWebView over the
release's UIWebView), `graphics`, `localauthentication`, `opengles`, `safariservices`,
`authenticationservices`, `backgroundtasks`, `photos`, `gamecontroller`, `metal`, `coretelephony`,
`accelerate`. The package's `xmake.lua` describes each (`add_configs`). Charon after 0.8.10 adds
`vision`, `metalkit`, `contacts`, `callkit`, `corespotlight`, `pushkit`, `javascriptcore`,
`scenekit`, `mediaplayer` and `avkit`, and changes what `metal` does: none of them exists at the
0.8.10 pin — if the app needs one, tell the user it needs a newer Charon and stop.

Enable only what the app calls: each library loads its framework into the process.

## 3. Declare it

In `xmake.lua`, the require with the alias **exactly** `apple-backports` (Charon finds the package
by that name; under any other alias it writes no backports package and no `Depends` on it):

```
add_requires("charon@apple-backports", {alias = "apple-backports", configs = {uikit = true}})
```

and on the app's target:

```
add_packages("apple-backports")
```

Nothing else: not `app.frameworks`, not `charon.libraries`, no `add_links`. The backports are
one copy per process and live in `/usr/lib/charon/org.charon.apple-backports/` on the device,
installed by their own package; the app's bundle carries none of them. Then configure:
`xmake f -c -y > .logs/configure.log 2>&1`.

The first configure with a new set of configs builds the package: its libraries once per band of
releases (from `apple_minimum` up to the last release an armv7 device gets), each checked against
the dyld caches of that band's first and last release, which are fetched from Apple's servers if
they are not held (skill `firmware`). Expect minutes to tens of minutes. Check: the log ends with
`install apple-backports latest .. ok`.

A changed config is a different package: `xmake f -c -y` resolves and installs it (plain `xmake f`
keeps the resolution it cached). Never `xmake require --force`,
never delete the old install; it is another path in the shared store.

## 4. Write the code

Call an `implemented` API directly, as on the release that introduced it: the link binds its weak
references to the backports library, and subclasses and categories of a backported class work. For
`inert`, `absent` and `ignored` APIs, write the version check and the older path yourself. Keep
using the release's look and behaviour where the backport's `facts` say it differs.

## 5. Read the build

Build with `xmake -y -v > .logs/build.log 2>&1` — xmake prints only the first warning without
`-v` (`add -v for getting more warnings`) and the rest are exactly the ones this step needs:

- `imports: every non-weak import of the armv7 slices of N binaries resolves against … exports` —
  the good line.
- `weakly imports N symbol(s) the armv7 release it is checked against does not export …:
  _OBJC_CLASS_$_UIStackView` — the app references a class neither the release nor the backports
  it links carry. Usually a missing config (step 2); otherwise the API is absent and needs a
  version check. `xmake deb` **refuses** this.
- `sends N selectors no class of the armv7 release it is checked against implements …:
  activateConstraints: centerXAnchor …` — methods neither the release nor the linked backports
  implement. A missing config again, or a call that must sit behind `respondsToSelector:`.
  `xmake deb` does **not** refuse this one; it crashes on the device with "unrecognized selector".
  Clear every such line before packaging.
- No line tells you an API is `inert`, `absent` or `ignored`: that is the registry's, read in step 1.

## 6. What the package then needs

`xmake deb` writes `build/org.charon.apple-backports_<release>+<digest>_iphoneos-arm.deb` beside the
app's package and adds `org.charon.apple-backports (>= <release>+<digest>)` to the app's `Depends`
(skill `package`). The backports package holds the libraries once per band under
`/usr/lib/charon/org.charon.apple-backports/bands/<first release>/` and a `bands/ranges` file; its
`postinst` reads the device's `ProductVersion` and links the band whose range holds it, and refuses
a release outside every band. The same happens in the emulator's image (skill `emulate`).

Record in `PROJECT.md` `## Progress`: the configs, the registry status of each API the app uses,
and the build log with no weak-import or selector warning left.

## Traps

- Trusting the SDK header ("it compiles, so iOS 6 has it") → the header is iOS 16's; only the
  import check against the release's own libraries says what exists.
- `alias = "backports"` or any other alias → the libraries still link, but Charon finds the package
  only as `apple-backports` and no longer counts them as provided: the build turns green with
  `weakly imports N symbols … : _OBJC_CLASS_$_UIStackView …` and the selector warning after
  `build ok`, and `xmake deb` refuses with `these imports are not exported by the device's iOS:`
  and writes no package. The alias is exactly `apple-backports`.
- A config left out → the build still succeeds (weak import, selectors); only a warning says so,
  and only the class half is refused by `xmake deb`. Read the `-v` log.
- `charon.waive.weak-imports` to get `xmake deb` through → the class is NULL on the device and the
  first use crashes; fix the config or guard the call.
- Copying a backports `.dylib` into the app bundle or the app's package → two copies of a class in
  one process are two classes; the backports come only from their own package.
- An API only on Charon main (a config missing at the pin) → not available at 0.8.10; ask the user
  before moving the pin.
- `absent` read as "call it anyway" → the release has nothing behind it: the app must take the
  older path, whether the entry is absent by decision (security, saving, permissions, the network)
  or by default.
