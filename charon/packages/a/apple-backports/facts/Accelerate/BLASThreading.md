# The threading model of BLAS and LAPACK, iOS 18.0

`BLASSetThreading` and `BLASGetThreading`, with the enumeration `BLAS_THREADING_MULTI_THREADED`, `BLAS_THREADING_SINGLE_THREADED` and
`BLAS_THREADING_MAX_OPTIONS`, arrived in iOS 18.0: the host's 18.0 cache names both functions, and no cache the port holds below it
does. The values are 0, 1 and 2, and they are read from the host's own `<vecLib/thread_api.h>` - `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks/vecLib.framework/Headers/thread_api.h` -
where `BLAS_THREADING_MULTI_THREADED = 0` is the only enumerator with a value written and the two that follow count on from it, so
`BLAS_THREADING_SINGLE_THREADED` is 1 and `BLAS_THREADING_MAX_OPTIONS` is 2. That header is not in the SDK the port builds against,
which is why the numbers cannot be read out of the SDK either.

The setting is per thread, held in thread-local storage, and a thread that has set none answers `BLAS_THREADING_MULTI_THREADED`,
which is the value a thread starts with: Accelerate decides how many threads to use. Measured on the host, from a thread that has set
nothing: `BLASGetThreading()` answers 0, `BLASSetThreading(BLAS_THREADING_SINGLE_THREADED)` answers 0 and `BLASGetThreading()` then
answers 1, `BLASSetThreading(BLAS_THREADING_MULTI_THREADED)` answers 0 and `BLASGetThreading()` answers 0 again, and
`BLASSetThreading(99)` answers -1 with `BLASGetThreading()` still answering 0 afterwards: a value the library does not have is refused
and the setting is left as it was.

## What the model does, and what it does not do

The two functions are a value kept per thread, and that is all they are - here and on the host. The header describes more than that
("Set the threading model to use for the subsequent calls into BLAS and LAPACK"), so the difference is stated here rather than left
for a reader of the registry to conclude otherwise.

Nothing reads the value. Measured on the host, with four threads inside `cblas_sgemm` and the thread count of the process sampled
while they are: `BLAS_THREADING_MULTI_THREADED` gives 17 threads and `BLAS_THREADING_SINGLE_THREADED` gives 17. The count moves by
one or two between runs of `tests/backports/host/blasthreading` with the load on the machine - 11 against 12, and 12 against 13 on
two further runs - so what the measurement shows is that the single-threaded model does not bring the count down, which is the whole
question. The host's setting is therefore as free of an effect on its own library as this port's is, and the port's answer is the
host's answer in every case the differential can pose.

Measured on the release, there is no model there for the call to set: `BLASSetThreading` and `BLASGetThreading` are in the 18.0 cache
and in none of 7.1.2, 8.0 and 16.0, and no other entry point in those three names a BLAS threading model. What they do export is
`SetvImageThreadCount`, which is vImage's own and says nothing about the BLAS - all three caches name it - and the API the port
carries arrived in 18.0 along with the setting.

The header's own words for a failure are worth holding on to: `BLASSetThreading` returns -1 for "Option is not supported on this
platform". The port answers 0 and keeps the value for every model the enumeration has, which is what the host does on a platform that
has them; that the release below 18.0 is given a 0 rather than that -1 is a consequence of the model being stored and read back
faithfully rather than refused, and it is the same answer the host gives.

## The three enumerators are a header, not a symbol

`BLAS_THREADING_MULTI_THREADED`, `BLAS_THREADING_SINGLE_THREADED` and `BLAS_THREADING_MAX_OPTIONS` are cases of
`enum BLAS_THREADING`, so nothing at run time carries them: they are a declaration in a header, and no release of any
kind exports a symbol for them. They are therefore not in the registry as implemented - the gate weighs an implemented
constant against a symbol the built library exports, and a gate run names an enumerator listed as implemented and not
built, which is the correct answer for a name that has no code behind it on any release. They are counted as
header-only rows, in the bucket the week's plan gives them: an Objective-C constant that is an enum case or a macro
exists once the generator's rule lowers its availability and has no code of its own. The two functions are the other matter and
are carried.

## The header the build SDK does not have

These five names come from `vecLib/thread_api.h`, which arrived with the API. The SDK the port builds against is 16.4, which has no
such header - `vecLib.framework/Headers` there holds blas_new.h, cblas.h, cblas_new.h, clapack.h, fortran_blas.h, lapack.h,
lapack_types.h, lapack_version.h, vBasicOps.h, vBigNum.h, vDSP.h, vDSP_translate.h, vForce.h, vecLib.h, vecLibTypes.h, vectorOps.h and
vfp.h, and no thread_api.h. So the enumeration and the two prototypes are declared in `Accelerate/BLASThreading18.m` as the header
declares them, and the two entry points are real: they are in the library, and the registry carries all five names as implemented.

What is missing is only the *declaration* on the client side: a program compiled against the port's 16.4 headers cannot name
`BLASSetThreading` or `BLASGetThreading`, because nothing includes a header that declares them. Adding `thread_api.h` to the port's headers
(`tools/gen/cmd_headers.lua`, which renders the SDK's own headers with the availability lowered by
`tools/gen/target_availability.lua`, and has no way to add one the SDK does not carry) is what closes that, and it is a change to a module every band shares. Until it is there these two functions are reachable
through a declaration of their own and are not reachable by including `<Accelerate/Accelerate.h>`, which is a gap in the header and
not in the code; the measurements above are of the code.
