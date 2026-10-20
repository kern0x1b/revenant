# Core ML's -init and +new that the headers declare NS_UNAVAILABLE

Five Core ML classes declare an initialiser `NS_UNAVAILABLE` in their headers, so a source file compiled against the
header cannot send it by name:

- `MLKey`, `MLMetricKey` and `MLParameterKey`: `-init` and `+new`;
- `MLModelAsset`: `-init` and `+new`;
- `MLImageConstraint`: `-init`.

The registry rows for these were `absent`. The header annotation is a compile-time rule, and what the release does at run
time is a different question, so it is answered by measurement: each class answers the selector with NSObject's own
implementation, and defines none of its own. This is the same answer the MetalKit classes give (facts/MetalKit/TextureLoader.md).

## What is measured

`tests/backports/host/coreml-unavailable-init/probe.m` asks, for each of the five classes, whether `-init` and `+new` are
NSObject's implementation (1), a different one (0), or the class does not exist (-1). Both sides answer all the same
questions:

- Apple's CoreML on the host (macOS 27.0.1): every class answers 1 for both selectors.
- The port's CoreML objects, built from `packages/frameworks/apple-backports/CoreML/` with no framework linked: 1 for every
  class, line for line the same as the host.
- Controls: a class defined in the probe that overrides `-init` answers 0 on both sides, and a name no framework has
  answers -1 on both sides. A control that answered 1 for the overrider would mean the probe could not see an override.
- A plant gives the port's `MLKey` its own `-init` in a scratch copy; the comparison must see it (the answer for `MLKey` and
  for the subclasses that inherit it changes).

`run.sh` runs all of these and fails if any line differs. The measurement is of the selector's implementation, not of a
call: what an `-init` returns when it is called is not asked by this test.

## What is not measured here

Nothing was run on a device. The device's Core ML is the same class family, and its answer is expected to be the same,
but that is not measured; the host differential is the floor the port is held to.
