---
name: objc
description: Write the app's Objective-C for old iOS (iPhone OS 3 to iOS 9, armv7) with Charon — ARC on the compile and the link, weak references below iOS 5 and the objects they abort on, which API each release really has (read from the release's own libraries with xmake firmware classes, not from the modern SDK's availability marks), reaching newer API through a backport, the release's older API or a guard (NSClassFromString, respondsToSelector:, @available and what each costs at xmake deb), and an interface built from the release's own UIKit controls. Use at the code step when PROJECT.md says Objective-C, when a build warns about weak imports or selectors a release does not implement, or when the user asks which API an old release has.
---

# Objective-C for old iOS

You write the app's Objective-C yourself, from the decisions in `PROJECT.md`, against the releases
it names. The compiler is clang with the iOS 16.4 SDK: it knows every API up to iOS 16 and does not
stop you from calling one the lowest release lacks. What the app may call is decided by the
release's own libraries, which Charon checks at every build (skill `build`). This skill is how to
write code that passes those checks honestly and runs on the oldest release in `PROJECT.md`.

Read `PROJECT.md` first: `apple_minimum`, the releases to check, the devices, the frameworks, the
backports. When the code is written, follow the skill `build`.

## 1. ARC: on the compile and on the link

Every Objective-C target of the project takes both lines (`add_mxflags` too if it has `.mm` files):

```lua
add_mflags("-fobjc-arc")
add_ldflags("-fobjc-arc")
```

A tweak or a `library` target is linked as a shared library, whose link reads `add_shflags`, not
`add_ldflags`: give it `add_shflags("-fobjc-arc")` (skill `xmake-objc`).

The link flag is what makes clang force-load arclite into the image. Charon's arclite carries the
ARC entry points (`objc_retain`, `objc_storeWeak`, …) below iOS 5, where the system has none, and
the collection subscripting methods (`objectAtIndexedSubscript:`, `objectForKeyedSubscript:`, …)
below iOS 6; from 5.0 on each entry point calls the system's own.

How to know it worked: `xmake -r -y -v > .logs/build.log 2>&1`, then `grep -n 'build ok\|^imports: \|warning: ' .logs/build.log`.
With both lines the build ends with `imports: every non-weak import of the armv7 slices of 1
binaries resolves against <n> exports` and `build ok` at every `apple_minimum` from 3.0 on. With
the link flag missing:

- below 5.0 the build is refused, one line per ARC entry point:
  `_objc_release (weakly imported from /usr/lib/libobjc.A.dylib, which this release does not export;
  the compiler emits this, so no version check stands in front of it and it reaches NULL; the image
  should carry it from arclite, which clang force-loads when -fobjc-arc is on the link and not only
  on the compile)`;
- at 5.x it builds, and the only sign is a selector warning for the subscripts:
  `warning: <Name> sends 1 selector no class of the armv7 release it is checked against implements,
  which must run only behind respondsToSelector: or a version check: objectAtIndexedSubscript:` —
  `array[0]` would raise "unrecognized selector" there;
- from 6.0 on it builds green: the system has every entry point and the subscripts. Keep the flag
  anyway: lowering `apple_minimum` later must not silently break the app.

## 2. `weak` below iOS 5

`__weak` and `@property (weak)` compile for every release. From 5.0 on the system keeps weak
references. Below 5.0 arclite keeps them: it clears an object's weak references from `NSObject`'s
own `-release` and `-dealloc`. An object whose class replaces `-release` cannot be tracked that way,
and storing it into a weak reference aborts the process at that line with:

```
cannot form weak reference to instance (0x…) of class <Class>: it manages its own retain count, so this iOS release cannot learn when it is deallocated
```

Nothing at build time sees this. Which classes it hits you read from the release's classes file
(§3): walk `superclass` from the object's real class until a class lists `release` among its
`instance` methods; weak is safe only if that class is `NSObject`. On iOS 4.3 that holds for
`UIView`, `UIViewController`, `UIWindow`, `UILabel`, `UITableView`, `UIApplication` and your own
`NSObject` subclasses — the usual delegate and parent links. It does not hold for every toll-free
bridged object (the concrete classes behind `NSString`, `NSArray`, `NSDictionary`, `NSNumber`,
`NSData`, `NSDate`, `NSURL` are CoreFoundation's, e.g. `__NSCFString`, and replace `-release`),
nor for `NSOperation`, `UIColor`'s and `UIFont`'s concrete classes. Below 5.0 hold those `strong` or
`copy`, never `weak`.

## 3. Which API each release has

The SDK's `API_AVAILABLE(ios(N))` is not the release a symbol appeared in, and the SDK no longer
declares some API old releases have. The release's own libraries are the truth, and you read them
on this machine, inside the project:

```
xmake firmware -y --arch=armv7 classes 6.0
```

It fetches the libraries of the earliest armv7 release not older than the one named, if they are
not held yet (skill `firmware`), and writes `classes_armv7.json` beside them, under
`~/.charon/dyld/<release>/` (`$CHARON_HOME/dyld/<release>/` if `CHARON_HOME` is set; `-o FILE`
writes it elsewhere). It prints `<path>: the Objective-C classes of iOS <release> for armv7`. The
file maps every Objective-C class of the release to its `superclass`, `image`, `instance` and
`class` method names and `protocols`. Methods are inherited: walk `superclass` until you find the
selector or run out. Do it for `apple_minimum` and every release to check, before you write the code
that needs an API, and note the answer in `PROJECT.md` beside the API.

Read from those files (armv7), as a first orientation — check your own releases anyway:

| Arrived in | API |
| --- | --- |
| 4.0 | `NSRegularExpression` |
| 5.0 | `NSJSONSerialization`, `+appearance`, `presentViewController:animated:completion:`, `+[NSURLConnection sendAsynchronousRequest:queue:completionHandler:]` |
| 6.0 | `NSLayoutConstraint` (Auto Layout), `UICollectionView`, `UIRefreshControl`, `NSUUID`, the collection subscripts, `supportedInterfaceOrientations`, `shouldAutorotate`, `dequeueReusableCellWithIdentifier:forIndexPath:` |
| 7.0 | `NSURLSession`, `NSURLComponents`, `-[UIView tintColor]`, `topLayoutGuide`, `+[UIFont preferredFontForTextStyle:]`, `base64EncodedStringWithOptions:` |
| not in 7.0 | `UIAlertController`, `UIStackView` |

Two readings of the file need care:

- A class or method present **below** the release the SDK marks it for is a private predecessor
  there: `UIGestureRecognizer` is in 3.0 and marked 3.2, `UIStepper` is in 4.3 and marked 5.0. Call
  an API only from the release where both the file has it and the SDK makes it public.
- An API the file has and the SDK no longer declares (`-[UIDevice uniqueIdentifier]` is in 6.0 and
  7.0 and in no iOS 16.4 header) cannot be reached through the SDK's headers. Take the release's
  public alternative; if the app truly needs the old API, that is the user's decision, and it goes
  under `## Limits`.

The file holds Objective-C classes only. C functions and constants (GCD, CoreGraphics, …) are
checked by the import check of every build (skill `build`).

Charon's `charon@apple-compat` carries shims for C calls of the system library that a later
release added or changed: `arc4random_buf` (4.3), `openat`, `fchmodat`, `unlinkat`, `fdopendir`
(8.0), `clock_gettime`, `clock_getres` (10.0), `aligned_alloc` (13.0), and
`dispatch_get_global_queue` given a class of service (8.0) — one header each under
`include/charon/` of the package at the pinned repository tag. A target names the calls it takes,
and the shim replaces that call in every file of the target:

```lua
add_requires("charon@apple-compat", {alias = "apple-compat"})
-- in the target:
add_packages("apple-compat")
add_values("apple.compat", "dispatch_get_global_queue", "clock_gettime")
```

How to know it worked: in the `-v` build log each compile line carries
`-include<…>/include/charon/<call>.h` (no space after `-include`) for every call named.

## 4. Calling what the lowest release lacks

For each API newer than `apple_minimum`, choose in this order, and record the choice in `PROJECT.md`:

1. **A backport**, if `charon@apple-backports` implements it: the app calls the modern API and the
   backport supplies it on the old release (skill `backports`). For a C call of the system library,
   `charon@apple-compat` carries shims (§3).
2. **The release's own older API**: `UIAlertView` for `UIAlertController`, `NSURLConnection` for
   `NSURLSession`, frames and `autoresizingMask` for Auto Layout below 6.0.
3. **A guard, and the newer API only where it exists:**
   - a class: `Class type = NSClassFromString(@"NSURLSession"); if (type) { … }` — the class
     symbol is not linked, so nothing is weakly imported and `xmake deb` passes without a waiver;
   - a method: `if ([object respondsToSelector:@selector(setTintColor:)]) { … }`, asked of the
     object you will send it to;
   - `if (@available(iOS 7.0, *))` compiles, but it links a weak import of
     `__availability_version_check` besides the class it guards, and `xmake deb` refuses both
     unless the target waives the check (below). The compiler's own runtime tests that symbol for
     `NULL` before calling it (compiler-rt, `os_version_check.c`), and on iOS 6.1.3 in the
     emulator `@available(iOS 7.0, *)` answered NO and `@available(iOS 6.1, *)` YES. The class
     inside the block is guarded by your `@available`;
   - a C function or constant of a later release is weakly imported: compare it with `NULL`
     before use.

A weak import the checked release does not export is a warning in `xmake` and a refusal under
`xmake deb` (skill `build` has both messages). Waive it only when every use of every symbol is
behind a check, the user agreed, and it is written under `## Limits` (skill `self-review`); the
value says why:

```lua
set_values("charon.waive.weak-imports", "NSURLSession is reached only inside @available(iOS 7.0, *)")
```

The waiver covers the whole target, including weak imports added after it was written: from
then on `xmake deb -y -v` prints `<binary>: weak-imports not checked: <the reason>` and the
`weakly imports` warning with every symbol, and packages. A new symbol is never refused again. On
every build, read that warning's symbols against the guards; when a new one appears, guard it,
then update the reason and `## Limits` and ask the user again.

The selector check works by name: it warns about a selector that **no** class of the release
implements. A selector some other class has passes: `setTintColor:` passes at 6.0 because
`UINavigationBar` has it, while `-[UIView setTintColor:]` arrives in 7.0 and a plain view on iOS 6
answers `respondsToSelector:` with NO. Only your `respondsToSelector:` on the object itself protects
that call. A selector sent to a class you found with `NSClassFromString` is still reported when no
class of the release has it (`sharedSession` below 6.0): check that the send is inside the guard,
and record it.

To find unguarded calls while writing, `add_mflags("-Wunguarded-availability")` makes clang warn
at every use of an API the SDK marks above `apple_minimum`. It is a finder, not a gate: it reads the
SDK's marks (§3), and it also warns inside `respondsToSelector:` guards, which it does not
understand.

How to know it worked: the build log (`-v`) has no `weakly imports` line and no `sends … selector`
line, or only ones you checked are guarded; `xmake deb -y -v` writes the package.

## 5. An interface from the release's own UIKit

The app looks like the release it runs on (`PROJECT.md`). That comes from using the release's own
controls, drawn by its own UIKit, not from imitating them:

- Structure with `UINavigationController`, `UITabBarController`, `UITableView` (plain for lists,
  grouped for settings and forms), `UIToolbar` and system `UIBarButtonItem`s.
- Controls are the system's: `UISwitch`, `UISlider`, `UISegmentedControl`, `UIStepper` (from 5.0),
  `UIActivityIndicatorView`, `UIAlertView`, `UIActionSheet`. Colour bars through their `tintColor`
  or `+appearance` (5.0); do not redraw them.
- Build the interface in code. Charon's app rule compiles no nib or storyboard: `app.resources`
  folders are copied into the bundle as they are (skill `project`).
- Size views from what the device reports (`[UIScreen mainScreen].bounds`, the view's own bounds)
  with frames and `autoresizingMask`; Auto Layout only from 6.0.
- Rotation: 6.0 asks `supportedInterfaceOrientations` and `shouldAutorotate`; below 6.0 only
  `shouldAutorotateToInterfaceOrientation:` exists. Below 6.0 implement both.
- `viewDidUnload` is deprecated from 6.0 (the SDK: called when a memory warning purges the view);
  below 6.0 release there what the view held.

## Traps

- `-fobjc-arc` only in `add_mflags` → refused below 5.0, subscripts missing at 5.x; arclite is
  loaded only by the link flag.
- `weak` to a string, a collection or another CoreFoundation-backed object below 5.0 → aborts at
  the store; hold it `strong` or `copy`.
- Believing the SDK's availability mark → read the release's classes file; the header is not the
  release a symbol appeared in.
- A build without `-v` taken as "no warnings" → xmake prints only the first warning and
  `add -v for getting more warnings ..`.
- `respondsToSelector:` asked of the wrong object (the class instead of the instance, a bar instead
  of the view) → it answers for that object only.
- `dispatch_get_global_queue(QOS_CLASS_…, 0)` → a class of service is iOS 8; iOS 6 answers `NULL`.
  Take `charon@apple-compat` with `add_values("apple.compat", "dispatch_get_global_queue")` (§3):
  it maps each class to the priority `queue.h` gives for it (on iOS 6.1.3 in the emulator,
  `QOS_CLASS_USER_INITIATED` then gave the `_HIGH` queue). Otherwise pass the release's own
  `DISPATCH_QUEUE_PRIORITY_DEFAULT` (or `_HIGH`, `_LOW`, `_BACKGROUND`).
- `add_requires("charon@apple-compat")` without `alias = "apple-compat"` → `xmake f` stops with
  `target(<Name>) names apple.compat symbols without add_packages("apple-compat")`: the project
  knows the package only by its alias.
- `dispatch_sync` to the main queue from the main thread → deadlock, on every release ("Calls to
  dispatch_sync() targeting the current queue will result in dead-lock", the SDK's `queue.h`).
  Wait off the main thread, with a semaphore rather than a run-loop spin.
- A private class or method from the classes file used because it is "there" → public API only; if
  the release has no public way, take a backport or the older API, or tell the user it cannot be
  done on that release and write it under `## Limits`.
- `charon.waive.weak-imports` without guards, or `-Wno-…` over a real warning, to get green → the
  call crashes on the device instead; guard it or backport it.
