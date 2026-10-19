# The probes, and what each one answers

Every tool in `tools/` exists because a question about the device could not be
answered from inside the engine, or could not be trusted from inside it. Each
one runs on the phone, links nothing of WebKit unless it says so, and prints a
verdict rather than a log.

They are documented here rather than in their own source, because the source of
a probe should be the experiment and nothing else.

The phone itself is reached through Charon's device module, which reads this
port's `device.env`: `charon device run SECONDS COMMAND`, `copy LOCAL REMOTE`,
`fetch REMOTE LOCAL`, and `tests/device/harness.py` for the test pages. It
revives the `iproxy` tunnel before every command, because a dead tunnel answers
"connection refused", which reads in a log exactly like a browser that crashed.

| Tool | The question it answers |
| --- | --- |
| `revtouch.c` | Drives the interface without a finger: injects a synthetic touch through the IOKit HID digitizer. Coordinates are screen points - 320x480 on this phone - and are normalised to 0..1 for the digitizer. `revtouch tap|swipe|down|up X Y`. |
| `revmem.c` | `revmem <pid>` - dirty and resident memory of another process, summed by VM tag. A vmmap for a phone that ships no vmmap; run as root, and read it to see which framework owns the resident dirty pages. |
| `revpid.c` | `revpid [name]` - the pid of each running process, or only those whose name matches. This device has no `ps`, so this is how a process is found at all. |
| `raise-memory-limit.c` | Raises the jetsam limit for a process, for measurements that would otherwise be killed before they finish. |

## Building them

The `revenant-device-tools` recipe builds the four C tools for armv7 and signs
each with the entitlements it needs:

```sh
conan install --requires=revenant-device-tools/1.0.0@revenant/stable --lockfile="" \
  -pr:h build/system/charon/profile -pr:b default --build=missing \
  --deployer=direct_deploy --deployer-folder=dist --output-folder=dist/conan
charon device copy dist/direct_deploy/revenant-device-tools/bin/revmem /usr/bin/revmem
```
