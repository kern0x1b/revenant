# Checks and waivers

The checks a port runs over its own files, the waivers a port states when a check cannot be met, and the release's libraries the import check reads. The port is built as the [tutorial](../../tutorials/toolchain/port.md) shows.
## Checks

A check is a target of its own. It runs a script or a program over the files it names, when those are staged or changed:

    target("lint-strings")
        add_rules("@addon/revenant/check")
        set_values("check.script", "scripts/lint-strings.sh")
        add_values("check.files", "src/**.m", "src/**.h")
        set_values("check.pass-files", true)

`xmake check` runs them; `xmake check --staged` and `xmake check --changed` run only those whose files are staged or changed. `xmake check --install-hook` makes the git pre-commit hook run the staged ones. A script that calls xmake again passes the task first: `xmake where -P DIR tdlib`, not `xmake -P DIR where`.

`xmake compile-commands [-o FILE] [TARGETS]` writes `compile_commands.json` for the named targets, for example the iOS ones without the host tests.

## Waivers

A check that the port cannot meet is waived by name, with the reason, and the reason is kept in the build:

    set_values("revenant.waive.pagezero", "why the executable's first segment is not at its place")

- `revenant.waive.weak-imports`: a weak import of a symbol the checked release lacks, which is refused when the image is released. Say why every call is guarded.
- `revenant.waive.input-minimum.<package>`: a package whose objects do not record the port's minimum release.
- `revenant.waive.<check>`: any other named check.

## Selectors the release lacks

The import check also reports the selectors a binary sends that no class of the release implements, and no other binary of the bundle or its provided libraries implements. Each is a call that fails at run time on the release unless it runs only behind `respondsToSelector:` or a version check. The report names them. Two fixes exist:

- A selector the release should have is backported in `frameworks/Backports`, so that the library implements it and the report drops it.
- A selector the app sends only on purpose behind `respondsToSelector:` or a version check is declared on the target that sends it:

      set_values("revenant.guarded_selectors", "isLowPowerModeEnabled", "setConfiguration:active:error:disableRecording:")

  A declared selector is silent in that binary. Any other selector still reports. The declaration is the app's statement that the guard is in its code; the check does not read the guard itself.

## Import checks need the release's libraries

The import check reads the system libraries of a release from `.cache/dyld/<release>/`. When they are not held, the check offers to fetch them, and `-y` accepts:

    xmake firmware fetch 6.1.3                # the shared cache for the release, by hand
    xmake firmware list                       # what is held

`xmake firmware --device=iPhone3,1 rootfs 6.0` unpacks a device's root filesystem for the emulator. See [the emulator guide](emulate.md).
