# How this is put together

Every armv7 / iOS 6 port - this engine, Telegram, VK ID, whatever comes next -
shares a target, a linker and a set of libraries, and differs in what it
actually builds. The split below keeps the shared half in one place without
forcing the ports to look alike.

For anyone arriving from the JVM world, the mapping is close to exact:

| Maven / Gradle | here |
|---|---|
| `gradle build`, `gradle clean`, `gradle test` | `charon build`, `charon clean`, `charon test` - `config/extensions/charon/` |
| `gradlew` | `charon`, installed once per machine from this configuration |
| `build.gradle` per module | `charon.toml` in each port |
| `task myTask { ... }` and `gradle myTask` | `[tasks.myTask]` with `script`, `shell` or `python`, and `charon task myTask` |
| convention plugin / parent POM | `charon-base` and the platform's `charon-apple`, consumed with `python_requires` |
| Gradle plugin applied to a build | `[platform] use = "apple-ios"`, a file of facts under `config/extensions/charon/platforms/` |
| `~/.gradle/init.gradle`, toolchain config | the shared profiles `charon profiles` writes from the platform files |
| Maven Central / company Artifactory | this repository, registered as a `local-recipes-index` remote |
| `gradle.lockfile`, `dependencyManagement` | `conan.lock` in each port |
| `~/.m2/repository` | `~/.conan2` |

## Charon and its platforms - the direction, being built in steps

iOS 6 is the first platform Charon builds for, not what Charon is. The driver
is to be as usable for an application on an old macOS, a current iOS, or
Android 2.x as it is here, and a repository says which platform it targets the
way a Gradle build applies a plugin. Two things make it worth having: one way to
drive any of these builds, where Apple platforms have none short of Bazel; and
compatibility out of the box - the SDK, the linker, the runtime and the shims an
old system needs arrive from a declaration, so nobody hunts for an archived SDK
or rebuilds a C++ runtime by hand.

**The core** knows nothing about any operating system: the declaration and its
variants, generated Conan recipes and CMake projects, tasks, pipelines and test
tiers, the verbs, `[conf]` values, the recipe index check, and the framework
that runs invariants inside the step that produces a binary and lets a port
waive one only with a reason.

**A platform** is a package the declaration names, and supplies everything the
core must not know:

    [platform]
    use = "apple-ios"
    os-version = { min = "6.0", max = "6.1.6" }
    architectures = ["armv7"]
    distribution = "jailbreak"

- settings and profiles for each architecture and version range, and the
  deployment-target environment its tools read;
- where its SDK comes from - never redistributed by this project, fetched from
  the vendor's source or the user's own installation, checksummed;
- its tools as build-context packages: ld64 and ldid for Apple, the NDK for
  Android;
- the binary format and the invariants that belong to it: Mach-O rebases and
  Thumb bits, `__PAGEZERO`, minimum versions of link inputs, imports the
  deployment runtime does not export; ELF and API levels for Android;
- target kinds and packaging: an application bundle, a tweak and a daemon,
  written as a `.deb` for `jailbreak`, a `.tipa` for `trollstore`, an `.ipa`
  for `sideload`, an `.apk` for Android;
- the transport to a device for deploy, run and test: SSH to a jailbroken
  phone, `adb` for Android;
- compatibility packs: the C++ runtime, emulated TLS, and the shims the old
  system lacks.

**Distribution.** Everything this project builds from open source - the linker,
the signer, libc++, compatibility shims - is published as prebuilt Conan
packages with their licenses, so a user downloads rather than compiles them.
Vendor SDKs and system images are never published; a platform only knows how
to obtain and verify them.

**Steps**, each proven on Revenant and iTgLegacy before the next:

1. Take port-specific knowledge out of the base: the exports check names
   WebKitLegacy, repointing strips a `librev-` prefix and the runtime rename
   assumes `.1.0.`; a declaration states each.
2. Done: `[platform]` in the declaration; the profile is generated from the
   platform's facts.
3. Done: the base is split into `charon-base` and `charon-apple`, whose hooks
   answer what a binary is and how it is verified, signed, bundled and
   packaged; the platform file names the module, the cross toolchain, the tools
   each architecture requires and what a bundle leaves out, and every name that
   said ios6 belongs to the core or to the platform.
4. Publish the prebuilt packages and fetch them with `conan cache restore`.
5. A second platform - macOS on an old deployment target is the cheapest - to
   prove the core holds nothing Apple-mobile.
6. The repository becomes `charon`, with platforms beside the core.

## Newest upstream, and compatibility where it is missing

Everything a port builds or builds with follows the newest upstream release, or
the newest commit where a project no longer releases: libraries, the C++
runtime, the SDK, the linker and signer, the build tools. An old system is not a
reason to stay behind; it is what this project exists to carry forward. When a
newer release stops supporting an old system or 32-bit code, the answer is a
compatibility layer the platform supplies once, not a pin every port repeats.

`apple-compat` is the first: a static library of what current code calls and an
old Apple system lacks, each entry keyed by the release that introduced it, so
a build for a newer release links none of it. `aligned_alloc`, which iOS has
from 13.0 and libc++ calls unconditionally from 22.1, is its first entry: a
hidden `charon_aligned_alloc` over `posix_memalign` keeping C11's contract. A
header force-included into the runtime's compile names calls to
`aligned_alloc` after it, so the SDK's declaration keeps its availability and
LLVM's `-Werror=unguarded-availability-new` stays on; the library is linked
with `-hidden-l`, so the runtime binds its own calls and exports nothing. The
libc++ recipe refuses a runtime that still imports a provided symbol. `clock_gettime` (iOS 10) over the Mach clock services and `fdopendir`
(iOS 8) over `F_GETPATH` are the next two: any library written for POSIX.1-2008
calls them, and a weak import is null on the older release. Each entry is a
component - `apple-compat::clock_gettime` - whose flags force-include its header
and whose library is the shim, so a recipe requires the component and writes no
flags; on a release that has the call, the component is empty. One gap stays
visible: iOS 6 has no clock that counts across sleep, so the shim's
`CLOCK_MONOTONIC` is uptime. The same shape serves a platform that dropped 32-bit: the newest SDK
that theos patched still carries armv7 stubs, and where none does, the stubs
are the compatibility layer.

A version that cannot be carried forward is recorded with the reason, and the
reason is the work item, not the pin.

## The three layers

**Shared configuration** - `config/`. Two profiles pin the target:
`apple-ios-armv7` - armv7, iOS 6.0, the `iphoneos-sdk` package and `ld64` as build
tools - and `apple-ios-armv8` - arm64 from iOS 7.0, the `iphoneos-sdk` package - both
written by `charon profiles` from the platform file. They carry nothing a port
chooses for itself: a C++ standard, CPU tuning or a later deployment target goes
in the port's own profile, which includes one of these.
`settings_user.yml` adds the iOS versions Conan does not ship. A machine picks
all of it up with one command, and there is exactly one copy of these facts.

**The toolchain** - `recipes/ld64`. The one artifact that is the same for
every port, because it is what makes building possible at all. Libraries are
deliberately not here: the ports disagree on versions, and a shared set would
make one port override another's. Each port carries its own recipes, names a
git URL and a commit, and builds them itself.

**Shared conventions** - `recipes/charon-base` and `recipes/charon-apple`. The base classes the recipe Charon
writes for a port extends: the generators, the layout, and the check that refuses an operating
system or architecture this toolchain does not build for. This is the piece that stops ten ports from
drifting into ten different spellings of the same build.

## What stays with the port

Its `charon.toml`, its own recipes for the libraries it builds, and its own
`conan.lock`. Duplication here is deliberate and cheap: two ports that both need
OpenSSL both say so, and both get the same package out of the cache. What is not
duplicated is the toolchain, the generated build files, or the knowledge of how
this target is built.

A port's declaration should be readable in one screen - what it requires, what it
builds, which tasks run in which order - and nothing in the port repeats what
Charon can write from it.

## Adding a port

1. Write the port's `charon.toml`: `[port]`, `[target]`, `[requires]`, its
   targets and its `[pipeline]`.
2. `charon setup <this repo>` - installs this configuration and registers both
   recipe indexes ahead of the general remotes, because `conan remote add` appends
   after ConanCenter, which would otherwise answer first.
3. `charon build`
4. Commit the resulting `conan.lock`.

## Adding a library

Put it under `recipes/<name>/` in the conan-center layout, pin the source by
tag or commit, and keep any patch inside the recipe rather than in a script.
A patch must fail loudly when the text it looks for is gone: `replace_in_file`
raises by default, and that is the behaviour to keep. A silently skipped patch
produces a build that fails somewhere unrelated, months later.

## Versions, and why patches are version-shaped

Recipe versions track upstream, and a port pins the version it needs. The first
two consumers already disagree: this engine builds against OpenSSL 3.0.15, the
Telegram port against 1.1.1w. That is not a case for one recipe carrying both -
the arm-xlate patch is shaped by the version it patches. 3.5.0 moved the block
out from under the patch we use, and 1.1.1's is different again from 3.0's. A
recipe version carries the patch that matches it; ports choose.

## What the checks cover, and what they do not

Every push builds the linker and the libraries on a runner neither of us has
touched, and then looks at what came out rather than at the exit code: the
slice is armv7, the deployment target is iOS 6.0, libcrypto still contains its
ARM assembly, and `OPENSSL_armcap_P` resolves through a plain `__data` word
rather than the non-lazy pointer the linker rejects. It also feeds the build a
missing SDK to confirm that failure is still refused, so the guard rails cannot
rot unnoticed.

None of that proves the result runs. This target is one where a build can
succeed and still be wrong - the failure that started all of this was a linker
that exited 0 and produced a binary that could not have run. A device is the
only thing that settles it, and the device suite stays manual, on real hardware.
Treat green CI as "the toolchain reproduces", not as "the code is good".

Some ways a binary can be wrong are facts about the platform, and those are
checked on every build rather than left to a device: the invariants in the base
class run inside the step that produces a binary, before it is stripped, so a
pipeline cannot leave them out. Every defect they cover was found shipping with
a green build: pointers to ARM-mode functions given the Thumb bit by a post-link
fix-up, an arm64 executable with a 16 KB `__PAGEZERO`, and entitlements missing
after signing, and an archive member of libvpx's that its assembler stamped for
iOS 5.0. The minimum OS version is read from every object a project built and
every archive member of the packages the graph built, and anything other than
the target is refused. A port waives one only with a reason. Still to come here:
inputs from outside the graph, such as a vendored archive, reported when older;
and undefined symbols the deployment target's runtime does not export, which a
newer SDK's stubs let the linker accept.

## Binaries

Recipes only, for now: each machine builds a package once and caches it in
`~/.conan2`. If sharing built binaries between machines becomes worth it, that
is a real Conan remote - Artifactory or any server - added alongside, with no
change to the recipes or the ports.

## Libraries and workspaces - designed, not built

Nothing in this section exists yet. It is the agreed shape for the part of a port
that is still Conan Python and YAML - each library's `conanfile.py`,
`conandata.yml` and `config.yml` - so that a repository carries declarations
only and Conan stays Charon's engine underneath, the way Gradle uses Maven
repositories without anyone writing a POM. It is not Bazel: a declaration is
compiled to Conan recipes and CMake, and content keying comes from Conan
revisions once the text Charon writes is deterministic.

### The workspace

A root `charon.toml` with a `[workspace]` lists its modules by folder. A folder
that is not listed is not a module, whatever it contains. Each listed folder has
its own `charon.toml` declaring one module. A root with no `[workspace]` is a
workspace of one module, which is the shape every port has today.

    [workspace]
    modules = ["app", "tweak", "daemon", "libs/ogg", "libs/tdlib"]

A label names a module or something it produces: `//libs/ogg` is the module,
`//libs/ogg:ogg` its library, `//libs/tdlib:res/td_api.tl` one of its files.
Labels resolve through the workspace list before any remote, and Charon writes
the local recipe index from the declarations; nobody writes it.

Module kinds: `application` (a workspace may hold several), `library`,
`device-library`, `executable`, and `tool` - built for the host, such as a
code generator.

### Where a library's tree comes from

A library's fields are the ones a target already has - `sources`, `exclude`,
`include`, `options-for`, `definitions-for`, `produces` - resolved against the
library's tree. The tree is the module's own folder unless `source` says
otherwise, and then patches and an overlay apply to it, in that order:

    source = { git = "https://github.com/openssl/openssl.git", commit = "c523121f902fde2929909dc7f76b13ceb4961efe" }
    source = { url = "https://.../compiler-rt.tar.xz", sha256 = "..." }
    patches = ["patches/arm-xlate-armcap-data-word.patch"]
    overlay = "port/"

Two placeholders name two different trees and must not be confused: `{port}` is
always the folder holding the module's declaration, and `{source}` is the tree
the module builds from - its own folder, the engine, or the fetched upstream. A
task that compiles or reads a file the port wrote names it through `{port}`, and
every task runs from `{port}`. A patch that no longer applies stops the build. A text table of replacements is
not a way to edit a source: today's `replace_in_file` tables become patch files.

### How it is built

`build` names the strategy, and each strategy owns its keys; a key that belongs
to another strategy is refused rather than ignored.

- `build = "sources"` - Charon compiles the listed sources, the way it builds a
  port's own static library today.
- `build = "cmake"` - the tree's own CMake, with `cache = { ... }`.
- `build = "configure"` - `command`, `environment` and `make-target`.

A step that has to run on the host before the cross build - tdlib's
`prepare_cross_compiling` - is a task on the host toolchain, declared before the
build step, not a fourth strategy.

brotli, as it is built for revenant-webkit today:

    [library]
    name = "brotli"
    version = "1.1.0"
    source = { git = "https://github.com/google/brotli.git", commit = "ed738e842d2fbdf2d6459e39267a633c4a9b2f5d" }
    patches = ["patches/no-app-bundle.patch"]
    build = "cmake"
    cache = { BROTLI_DISABLE_TESTS = "ON", BROTLI_BUNDLED_MODE = "ON", BUILD_SHARED_LIBS = "OFF", CMAKE_MACOSX_BUNDLE = "OFF" }
    produces = ["brotlicommon", "brotlidec", "brotlienc"]
    headers = [{ from = "c/include/" }]
    licenses = ["LICENSE"]

openssl, as it is built for revenant-webkit today:

    [library]
    name = "openssl"
    version = "3.0.15"
    source = { git = "https://github.com/openssl/openssl.git", commit = "c523121f902fde2929909dc7f76b13ceb4961efe" }
    patches = ["patches/arm-xlate-armcap-data-word.patch"]
    uses = ["apple-cross"]
    build = "configure"
    command = "./Configure ios-cross no-shared no-tests no-ui-console no-engine no-async"
    environment = { CFLAGS = "-O2 -DBROKEN_CLANG_ATOMICS" }
    make-target = "build_libs"
    produces = ["ssl", "crypto"]
    headers = [{ from = "include/openssl/", into = "openssl" }]
    licenses = ["LICENSE.txt"]

ogg and tdlib, for iTgLegacy to fill in against its recipes during review:

    [library]
    name = "ogg"
    source = { git = "<url>", commit = "<commit>" }
    build = "sources"
    sources = ["<source list>"]
    produces = ["ogg"]

    [library]
    name = "tdlib"
    source = { git = "<url>", commit = "<commit>" }
    patches = ["patches/voip-hook.patch"]
    requires = ["//libs/openssl", "libcxx:runtime"]
    uses = ["apple-cross", "emutls"]
    build = "cmake"
    before-build = ["task:prepare-cross-compiling"]
    cache = { "<option>" = "<value>" }
    produces = ["<libraries>"]
    resources = [{ from = "td/generate/scheme/td_api.tl" }]

Architecture-specific strings stay in one library through the same variant
tables an application already has, merged over the library's own keys:

    [library]
    name = "libvpx"
    build = "configure"
    command = "./configure --target={vpx-target} --disable-examples"

    [variants.armv7.library]
    vpx-target = "armv7-darwin-gcc"

    [variants.arm64.library]
    vpx-target = "arm64-darwin-gcc"

openssl's `ios-cross` with `-DBROKEN_CLANG_ATOMICS` against `ios64-cross`, and
opus's `CMAKE_SYSTEM_PROCESSOR`, are the same shape. `-mthumb` is not: the
`armv7-apple-ios` triple already compiles Thumb, so no convention adds it.

A fetch may name several files, each with its own checksum, placed into one
folder - emutls is `emutls.c` and four `int_*.h` from compiler-rt:

    source = { files = [{ url = "...", sha256 = "...", into = "lib/builtins" }, ...] }

An extra translation unit beside the tree's own build - tdlib's
`compat/weak_import_shims.c` on the dylib's link line - is `extra-sources`, which
every strategy accepts; the files are the module's own and are named through
`{port}`. Under `build = "sources"`, `sources` may name the module's files and
the fetched tree's in one list, each through its placeholder.

### What a library produces, and who may reach it

`produces` names the archives or dylibs; a dylib also declares its install name.
An entry is a path relative to the build tree, or `{ find = "libopus.a" }`,
which searches it and is refused when it matches no file or more than one,
symlinks not counted; `as` renames the result, as tdlib's dylib becomes
`libtdjson.dylib`. `headers` copies header folders: `{ from = "c/include/" }`
flattens the folder's contents into `include/`, `into = "opusenc"` puts them
under that prefix, and `{ from = "vpx/", keep = true }` keeps the folder's own
name, so libvpx's headers land in `include/vpx/` and never in `include/vpx/vpx/`.
`resources` are files a module ships beside its libraries, each with `from`
naming its place in the tree, never a bare name to be searched for. Any of them can be
found from outside a build with `charon where //libs/tdlib:res/td_api.tl`, which
prints the path or fails; a tool never reads the cache layout itself.

### Dependencies expose headers and archives, and nothing else

`requires = ["//libs/opus"]` makes a module's headers and archives visible to the
consumer. It does not add anything to the consumer's link line. Frameworks and
system libraries a library needs are information about it, never propagated:
iTgLegacy's application must not link VideoToolbox or AVFoundation, which it
reaches through dlopen because a hard link to either stops it starting on iOS 6.
The consumer declares what it links and in what order - static archive order
matters - and may mark a framework weak.

### Variants as dimensions

A workspace declares dimensions - architecture, flavour, build type - and a
module inherits them unless it narrows them: a daemon narrows architecture to
armv7. An application merges its architecture slices as `merge:application`
already does.

### Conventions

A convention is a declaration fragment defined once in the toolchain and applied
by name, `uses = ["emutls"]`. It is data, not code: flags, `include-system-for`,
a dependency on a toolchain module, a step to insert. The module's own keys win
over a convention's; two conventions that set the same key in ways that cannot
be ordered are refused.

A convention may carry a condition that asks the compiler, never a name, with
the polarity in the key rather than in a boolean:

    [convention.emutls]
    unless-compiles = "static __thread int x;"
    requires = ["//toolchain/emutls"]
    cache = { CMAKE_OSX_DEPLOYMENT_TARGET = "{emutls-compile-at}" }
    extra-objects = ["{lib://toolchain/emutls:emutls.o}"]
    link-options = ["-miphoneos-version-min={os-version}"]

`when-compiles` merges the fragment when the snippet compiles, and
`unless-compiles` when it does not, both with the module's target, deployment
version and flags. A convention is not limited to flags: emutls needs a cache
value for the compile, an object on the link line and a link option carrying the
real deployment version, from one condition.

Whether a module needs emulated TLS depends on the target and its deployment
version - armv7 below 9.0, arm64 at 7.0 but not from 8.0 - and a toolchain can
move either number, so the condition is evaluated with the module's own settings
and the fragment merges only when it holds. A condition that cannot be evaluated
is refused, never read as false. emutls becomes a toolchain module that the
convention references, so no port carries its C. The Mach-O fix-up does not: with
ld64 the Thumb bits, the entry point and `__PAGEZERO` are already right, the
fix-up only corrupted pointers to ARM-mode functions, and the invariants now
prove the linker's output instead.

Per-language lists do not inherit from each other. `objcxx` does not take
`cxx`'s flags and `objc` does not take `c`'s; a flag both need, such as
`-fno-threadsafe-statics`, is listed under both, because the generated
expressions are independent per language.

The C++ runtime is a dependency, not a convention. Headers must match the
runtime an image binds to: libc++ 21's headers call `std::__hash_memory`, which
iOS 6's libc++ does not export, and the SDK's stubs let the link succeed. A
module that compiles C++ requires `libcxx:runtime`, which carries the headers
and the availability define together, and the application bundles that runtime.

### Determinism

Charon writes a library's recipe from its declaration alone: no absolute path, no
time, no host name, keys in declaration order. The same declaration generated in
two different folders gives the same text, and therefore the same recipe
revision, so moving a repository never rebuilds a package. The generated port
recipe already finds its port from the folder it lies in, and a test generates
one declaration in two folders and requires the same text.

### Proving a migration changed nothing

Each library moves from its recipe to a declaration only with a comparison of the
two builds that covers the archive's members, the defined and undefined symbols,
the minimum OS version recorded in every object or slice, and, for a dylib, its
install name and load commands. The minimum version is not optional: iTgLegacy's
libvpx had the same members and symbols while 110 of its 111 armv7 objects
targeted iOS 7.0. The comparison is a Charon verb, not a script each port
rewrites.

### Order

1. Done: generated recipes no longer bake the checkout path.
2. Done: a verified baseline, today's recipes building each port end to end
   through Charon.
3. The comparison verb, and `charon where`.
4. Library modules by strategy - sources, then cmake, then configure - each
   library proven unchanged before its recipe is deleted, simplest first: ogg
   and brotli before tdlib and openssl.
5. The workspace with labels and dimensions, once there is more than one module
   to hold.
