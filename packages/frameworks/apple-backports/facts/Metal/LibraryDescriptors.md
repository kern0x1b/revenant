# The library's type, install name and function descriptors, iOS 14.0 and later

A library on this port is the translated form of a metallib file: `RevenantMetalDevice` loads
`<name>.metallib.es2`, a folder of C and ES that the build made from the AIR, and it refuses a library built
from source or from bytes in memory. A `RevenantMetalLibrary` holds one `RevenantMetalFunction` per kernel or
shader, each a name, a stage, its translated source and its reflection.

## Measured on the host

`tests/backports/device/library-probe/library.m` builds a library from source on the host, so these answers are
for a library of that kind. The host has no Metal compiler on this machine, so it cannot build a `.metallib`
file to ask the same questions of a file-loaded library. Recorded in
`tests/backports/device/library-probe/host-expectations.txt`:

* **The type is executable** (`library.type=0`, which is `MTLLibraryTypeExecutable`). A library built from source
  holds functions a pipeline dispatches; a dynamic library is the other type, and this port carries none.
* **The install name is `default.metallib`** for a library built from source. This is not nil, which is why the
  install name cannot come from the source: the port reads it from the metallib file instead (below).
* **A descriptor's specialized name is the function's name.** A descriptor that names `fill`, specializes it with
  an int constant at index 0, and gives the specialized name `fill_scale3` returns a function whose `name` is
  `fill_scale3`, of kernel type, with options `0` (none).
* **A descriptor with only a name** returns the library's function of that name, under that name.
* **A descriptor that names no function** returns nil with an error.
* **The completion-handler form** answers the same function and the same error, once, on the handler.
* **The descriptor's options default to `0`**, which is `MTLFunctionOptionNone`.

## What the port does

* **`type`** is `MTLLibraryTypeExecutable`, because the library is the translated form of an executable metallib.
* **`newFunctionWithDescriptor:error:` and its completion-handler form** make the function the library holds
  under the descriptor's name, specialized with the descriptor's constant values. The function is named by the
  specialized name when the descriptor has one, and it answers the descriptor's options from `-options`. A name
  the library does not hold is refused with an error (code 13), as the name form already is.
* **The intersection-function forms** return nil with an error (code 22). An intersection function is for ray
  tracing, and the SGX 543 has no ray tracing, so a library of this device holds none. The host has ray tracing
  (`features-expectations.txt`: `supportsRaytracing` is 1, and it returns a function for a descriptor naming a
  kernel), so its answer on a device without the feature is not measured here. The nil is a crutch, recorded in
  `coordination/crutches.md`.

## Measured on the host: a library loaded from a file

`tests/backports/device/library-probe/fileload.m` loads a metallib file with `newLibraryWithURL:`. The file is Apple's
own `default.metallib` from `MTLReplayer.app`, which the host ships, and a copy of it under another name. Recorded in
`tests/backports/device/library-probe/fileload-expectations.txt` (the run output):

* **The install name is `default.metallib` for both files**, the one under its own name and the renamed copy. So the
  install name is not the file's name. The string is inside the metallib: it occurs once in the file's bytes.
* **The type is executable** (`library.type=0`), as for a library built from source.
* **The function names** of this library are `composite` and `blur1D`.

## The install name on the port

The install name is carried by the metallib. Its records are a tag, a 16-bit length and the payload. The library
holds one `NAME` record that no function has: a function's `NAME` is followed by its `TYPE` record, and the
library's own by `ENDT`. Its payload is the install name. `tools/air2es/metallib2es.lua` reads that record and writes
`"installName"` into `library.json`; a library with no such record gets no key.

What the translator writes, against what the host answers for the same file (`fileload.m`):

| File | Host (`installName`) | Translator (`library.json`) |
| --- | --- | --- |
| Apple's `default.metallib` | `default.metallib` | `default.metallib` |
| the same, renamed `renamed-copy.metallib` | `default.metallib` | `default.metallib` |
| the record edited to `renamedlib.metal` (`record-edited.metallib`) | `renamedlib.metal` | `renamedlib.metal` |

The third row is the one that tells the record from the file name: the host reads the record, and so does the
translator. Its run output is `tests/backports/device/library-probe/fileload-expectations.txt`.

The port answers the value it reads back: `RevenantMetalLibrary` keeps `installName` from `library.json`, and
`-[MTLLibrary installName]` (`Metal/MTLLibrary14.m`) returns it, or nil when the translator wrote none. The member is
iOS 14.0 (`API_AVAILABLE(macos(11.0), ios(14.0))` in the 16.4 SDK, which a compile against the 6.1.3 target warns
about), so it sits in the 14.0 category with `type`.

Measured limit: the translator writes `"functions": []` for Apple's `default.metallib`, because it translates
only vertex and fragment functions, and this library's functions are compute kernels (`composite`, `blur1D`). The
install name does not depend on that, but a port run of this library has no functions to call.

## Not measured, and where the port side stands

* The port side has not been run. The probe builds its library from source, which the port refuses, so a port run
  of this probe needs a library from a file, which the device run has to supply.
* Non-zero options: the probe asks only `MTLFunctionOptionNone`. The port keeps the options it was given and
  compiles nothing differently for them, so a non-zero value is recorded but its Metal answer is not checked.
* The intersection forms are not asked on the host, because they need a ray-tracing device and a source with
  intersection functions, and the port's device has neither.
