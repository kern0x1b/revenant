---
name: xmake-objc
description: Reference for how xmake builds Objective-C, Objective-C++, C and C++ files in an old-iOS target with the Charon addon — which flag API reaches which file kind (add_mflags, add_mxxflags, add_mxflags, add_cxflags), which link flag API a target kind reads (add_ldflags for app and daemon, add_shflags for tweak and library), per-file flags on add_files, add_frameworks and weak-linked frameworks, the C++ runtime an Objective-C++ target needs, and what Charon's rule and toolchain add to every compile and link or refuse (target, minimum, emulated TLS, weak runtime below 5.0, file prefix map, the minimum every input must record). Use when writing the flag, framework and file lines of an Objective-C target, when a flag seems not to arrive, when a tweak or library needs ARC, or when a .mm file needs C++.
---

Derived from the `xmake-objc` skill of xmake-io/xmake-skills at `ef67caa` (Apache-2.0), rewritten and modified for Charon.

# Objective-C in xmake, with Charon

This skill is the build side of Objective-C: which xmake line puts a flag, a framework or a
library where it takes effect, and what Charon adds on its own. How to write the code (ARC, `weak`
below 5.0, which API a release has, guards) is the skill `objc`; the app target's lines as a whole
are the skill `project`; the compiler and architectures are the skill `xmake-toolchains`; reading a
failed build is the skill `build`. Read `PROJECT.md` first: the target kind, the languages and
`apple_minimum` decide which lines below apply.

## 1. File kinds and the flags each reads

xmake picks the compiler and the flag lists by the file's extension (xmake 3.1.1,
`languages/objc++/xmake.lua`, `languages/c/xmake.lua`, `languages/c++/xmake.lua`):

| Files | Flag lists that reach them |
| --- | --- |
| `.m` | `mflags`, `mxflags` |
| `.mm` | `mxxflags`, `mxflags` |
| `.c` | `cflags`, `cxflags` |
| `.cpp`, `.cc`, `.cxx` | `cxxflags`, `cxflags` |
| `.s`, `.S` | `asflags` |

- `add_cxflags` does **not** reach `.m` or `.mm`. Charon's own `apple-ios` rule adds its flags to
  `cxflags` and `mxflags` separately for that reason.
- `add_mxflags` reaches both `.m` and `.mm` in one line. `add_mflags` plus `add_mxxflags` does
  the same thing. Pick one form per project and keep it.
- `set_languages("c99", "c++17")` sets the standard for `.c`, `.cpp` and `.mm` alike.
- Every `.m` and `.mm` of a target is compiled by the `llvm` package's clang through the
  `apple-ios` toolchain. There is no separate Objective-C compiler to choose.

How to know it worked: `xmake show -t <Name>` lists the target's `mflags`/`mxflags`/`mxxflags`,
and in `xmake -y -v > .logs/build.log 2>&1` each compile line of a `.m` file carries the flag.

## 2. Link flags follow the target kind

The linker of a target reads exactly one flag list, chosen by the kind (xmake 3.1.1,
`core/tool/linker.lua:198`, `languages/objc++/xmake.lua:34`):

| Charon rule | Kind it sets | Link flags API |
| --- | --- | --- |
| `app`, `daemon` | `binary` | `add_ldflags` |
| `tweak`, `library` | `shared` | `add_shflags` |

So the ARC link flag of a tweak or a Charon library is `add_shflags("-fobjc-arc")`. An
`add_ldflags("-fobjc-arc")` on such a target is never passed to the link, and clang does not
force-load arclite (the skill `objc` says why that matters). Measured at the pin on a tweak: with
`add_ldflags` the `.dylib` link line had no `-fobjc-arc`, with `add_shflags` it had. Check it in
the `-v` log: the link line of the `.dylib` must carry `-fobjc-arc`.

## 3. One file compiled differently

A file config on `add_files` is applied after the target's flags (xmake 3.1.1,
`core/tool/compiler.lua:350-363`), so it wins where clang takes the last flag:

```
add_files("src/legacy/*.m", {mflags = "-fno-objc-arc"})
```

That file's compile line then carries `-fobjc-arc -fno-objc-arc` in that order (measured at the
pin). That is how a manual-retain-release file lives in an ARC target. Never turn off a warning this way to
make a build pass.

## 4. Frameworks

- `add_frameworks("UIKit", "Foundation", "CoreGraphics")` gives `-framework` to the compile and
  to the link of binaries and shared libraries alike (`languages/objc++/xmake.lua`, the
  `target.frameworks` entries). The frameworks come from the SDK package (iOS 16.4).
- The SDK has frameworks that the lowest release does not. The link succeeds against the SDK's
  stubs, and then Charon's import check refuses a framework the release lacks:
  `(loads <library>, which neither the device nor this build provides)`. At the pin that refusal
  is raised only for a **strong** load command (`v0.8.10:modules/apple/dyld.lua:649-653`).
- A framework that only newer releases have, used behind a version check: link it weakly with
  `add_ldflags("-weak_framework", "<Name>", {force = true})` (`add_shflags` on a tweak). Without
  `{force = true}` xmake tests each word as a flag and drops both (`checking for flags
  (-weak_framework) ... no` and `checking for flags (<Name>) ... no` in the `-v` log, then
  `add_ldflags("-weak_framework") is ignored, please pass {force = true} …`), and the link fails. A weak
  load command is not refused as a missing library. Whatever the app imports from it is then held to the weak-import
  rules of the skill `build`: read the `-v` log for the `weakly imports` warning naming those
  symbols, and expect `xmake deb` to refuse them unless every use is guarded and waived as that
  skill says. Write the guard itself as the skill `objc` says.
- `add_frameworkdirs` and a prebuilt third-party `.framework` or `.dylib`: do not. A prebuilt
  binary was not built by this toolchain for this minimum. Build it as a target or as a package
  (skill `xmake-packages`).

## 5. Objective-C++ and C++

libc++ as an application bundles it is `charon@libcxx`. It is libc++ 23 linked with the shims the
minimum release lacks, and its package flags carry `-nostdinc++` and `-nostdlib++`
(`charon-repo-0.8.10:packages/l/libcxx/xmake.lua:30-36`). A target with `.mm` or `.cpp` takes it
like any package:

- `add_requires("charon@libcxx", {alias = "libcxx"})` and `add_packages("libcxx")` on the target;
- an app bundles it with `add_values("app.frameworks", "libcxx")`. A daemon or tweak carries it with
  `add_values("charon.libraries", "libcxx")` and names its package with `charon.control` (skill
  `xmake-rules`). Charon's own `swift` rule does exactly this for the runtime it links
  (`v0.8.10:rules/swift/xmake.lua:47-53`).

Its libc++abi exports the emulated thread-locals and the wide-atomic library calls once per
process. The toolchain emulates thread-locals below 9.0 (8.0 on arm64) and emits the atomic calls
below 7.0 (`v0.8.10:toolchains/apple-ios/xmake.lua:72-76`).

## 6. What Charon adds to every compile and link

Nothing in this list is written by hand. `xmake -v` shows it
(`v0.8.10:toolchains/apple-ios/xmake.lua:56-90`, `v0.8.10:rules/apple-ios/xmake.lua:24-38`):

- `-target <arch>-apple-ios -miphoneos-version-min=<minimum> -isysroot <SDK>`, and
  `-mlinker-version=956.6` where ld64 links. These go to `cxflags`, `mxflags`, `asflags` and the
  link.
- `-femulated-tls` below 9.0 on 32-bit ARM and below 8.0 on arm64.
- `-Xclang -fobjc-runtime-has-weak` on Objective-C below 5.0.
- `-lBlocksRuntime -lobjc` on the link below 3.2.
- `-ffile-prefix-map=<project>=/port` on every compile, and no ccache.
- `add_values("apple.compat", "<call>")` force-includes the shim headers of `charon@apple-compat`
  for the named calls. The target must also `add_packages("apple-compat")`, or it is refused.
- Packages get `-O3`; the project's own files get what the mode rules give (skill `xmake-basics`).

What Charon checks at every link (`v0.8.10:modules/apple/platform.lua:52-100`): every object of the
target and every member of its packages' static archives must record the target's minimum release.
Otherwise it stops with `a link input of <Name> was not built for this target: …`. An object
compiled outside the target, or a flag such as `-miphoneos-version-min=` added by hand, shows up
here. `charon.waive.input-minimum.<package>` exists for a package that cannot record a minimum. It
is never a fix for your own objects.

## Traps

- `add_cxflags("-fobjc-arc")` → `add_mxflags` (or `add_mflags` and `add_mxxflags`). Reason:
  `cxflags` reaches only `.c` and `.cpp` files, so the Objective-C is compiled without ARC.
- `add_ldflags("-fobjc-arc")` on a tweak or a `library` target → `add_shflags`. Reason: a
  shared target's link reads only `shflags`, so arclite is never force-loaded.
- `-fobjc-arc` on `.m` but a new `.mm` file added later → cover `.mm` too (`add_mxflags`). Reason:
  `mflags` does not reach `.mm`.
- `add_rules("xcode.application")`, `--xcode_sdkver`, `--target_minver`, `-p iphonesimulator` from
  generic xmake advice → Charon's `app` rule and `apple_minimum`. Reason: those are xmake's
  Xcode-based platform, which needs Xcode and runs none of Charon's checks.
- A storyboard, `.xib` or `.xcassets` in `add_files` → code and PNGs (skill `project`). Reason:
  nothing in this toolchain compiles them.
- `-w` or `-Wno-…` over a real warning to quiet a build → fix the call. Reason: those warnings
  are how the build tells you what the release lacks. The skill `self-review` refuses them.
- `-miphoneos-version-min=` or `-target` added by hand → leave them to the toolchain. Reason: two
  minimums in one link; the input check refuses objects that record the wrong one.
