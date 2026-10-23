# The probes, and what each one answers

Every probe in `src/device-tools/` exists because a question about the device could not be
answered from inside the engine, or could not be trusted from inside it. Each
one runs on the phone, links nothing of WebKit unless it says so, and prints a
verdict rather than a log.

They are documented here rather than in their own source, because the source of
a probe should be the experiment and nothing else.

The phone itself is reached through Revenant's device module, which reads the
`device.env` at the top of the checkout: `./xmakew device -P . run COMMAND` from a shell,
`run`, `copy` and `fetch` from Lua, and `tests/device/harness.lua` for the test pages. It
revives the `iproxy` tunnel before every command, because a dead tunnel answers
"connection refused", which reads in a log exactly like a browser that crashed.

| Tool | The question it answers |
| --- | --- |
| `revtouch.c` | Drives the interface without a finger: injects a synthetic touch through the IOKit HID digitizer. Coordinates are screen points - 320x480 on this phone - and are normalised to 0..1 for the digitizer. `revtouch tap|swipe|down|up X Y`. |
| `revmem.c` | `revmem <pid>` - dirty and resident memory of another process, summed by VM tag. A vmmap for a phone that ships no vmmap; run as root, and read it to see which framework owns the resident dirty pages. |
| `revpid.c` | `revpid [name]` - the pid of each running process, or only those whose name matches. This device has no `ps`, so this is how a process is found at all. |
| `raise-memory-limit.c` | Raises the jetsam limit for a process, for measurements that would otherwise be killed before they finish. |

## Building them

The `webkit-device-tools` package, `src/device-tools/xmake.lua`, compiles the four C probes
in `src/device-tools/` for armv7 and signs each with the entitlements in
`src/device-tools/entitlements/` it needs. Configuring for iphoneos requires it, so it is built with the
port, and `./xmakew where -P . webkit-device-tools` names its folder:

```sh
scp -P <port> "$(./xmakew where -P . webkit-device-tools)/bin/revmem" root@<phone>:/usr/bin/revmem
```

## The scripts on this side

The scripts are Lua, run as `./xmakew l -P . frameworks/WebKit/tools/<name>.lua`; each prints its usage with `--help`.

| Script | What it does |
| --- | --- |
| `carry_check.lua` | checks that the patched engine tree still holds what the port needs, against `carry-manifest.txt`; every engine build runs it first |
| `port_delta.lua` | how much the patch series changes upstream, by area and kind, and how much of it carries the `WEBKIT_IOS6` guard |
| `carry_audit.lua` | files whose port markers thinned out against a reference tree, after moving the series to a newer base |
| `symbol_check.lua` | the engine's imported symbols and exported classes against `carry-symbols.txt`, and `--pin` |
| `required_encodings.lua` | `tests/host/required-encodings.txt`, read from `TextCodecICU.cpp` |
| `check_cacert.lua` | the application's trust store against the reviewed hash, and `--upstream` |
